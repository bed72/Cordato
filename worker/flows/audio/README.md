# Áudio → Despesa

Fluxo assíncrono em memória com nós nativos e JavaScript próprio, sem SDKs ou bibliotecas npm
adicionais. Recebe **uma despesa por áudio**, valida a sessão, envia o arquivo
à IA por Chat Completions e cadastra a despesa na API nativa do PocketBase.

```text
POST multipart → validar upload → PocketBase auth-refresh → HTTP 202
    → IA (áudio + schema JSON) → validar despesa → PocketBase create → log seguro
```

`flows.json` contém a aba completa e toda a lógica nos próprios nós **Function**.
Não há módulo de processamento na imagem, `require`, biblioteca externa ou chamada
a `global.get('cordatoAudio')`. Os testes compilam e executam o código desse JSON.
Alterar timeout, payload, validação ou diagnóstico exige somente **Deploy no editor**.

A infraestrutura continua separada: autenticação do editor, raiz `/api`, proteção
de upload antes do parser e limite de concorrência pertencem à imagem. O middleware
`middleware/audio_upload_gate.js` fornece `req.cordatoAudio` com correlação e liberação
idempotente da vaga. Um Node-RED genérico sem essa admissão não é equivalente.
Rebuild é necessário somente para mudar infraestrutura ou dependências.

### Migrar a instância atual sem rebuild

1. Preserve uma exportação privada dos flows ativos, sem versioná-la.
2. Importe este `flows.json` e substitua explicitamente a aba/nós de mesmos IDs,
   sem duplicar o endpoint ou apagar outras funcionalidades.
3. Confira e clique em **Deploy**. A imagem Cordato atual já fornece o mesmo contrato
   de admissão; o flow novo não usa mais seu helper global antigo.
4. Para futuras alterações, edite os nós Function, use Deploy e depois exporte/revise
   o JSON no Git. Aguarde operações pendentes antes de publicar: não há fila durável.

Se atualizar a imagem para esta organização limpa, **importe o flow autônomo antes**:
a imagem nova não expõe mais `functionGlobalContext.cordatoAudio`, e flows antigos
que ainda chamem esse helper não funcionarão nela. Não há necessidade de atualizar
a imagem apenas para aplicar este flow à instância atual.

## Configurar no Dokploy

1. Preserve as variáveis administrativas e `NODE_RED_CREDENTIAL_SECRET` existentes.
2. Acrescente em **Environment**, sem enviar os valores privados ao chat/Git:

   ```env
   POCKETBASE_URL=https://pocketbase.cordato.cloud
    AI_BASE_URL=https://openrouter.ai/api/v1
    AI_MODEL=google/gemini-3.8-flash
    AI_API_KEY=COLE_A_CHAVE_SOMENTE_NO_DOKPLOY
   ```

3. Na instalação inicial ou em mudanças de infraestrutura, construa a imagem Cordato,
   que habilita `/api`, separado de `/admin`, e a admissão de upload. Uma instância
   atual já preparada para áudio pode receber o flow por importação e Deploy, sem rebuild.
4. No editor, exclua a aba antiga **Hello World** se ainda existir. Sua exclusão
   do repositório não remove o exemplo do volume remoto.
5. Importe `worker/flows/audio/flows.json`, confira os nós e use **Deploy** no editor.
6. Preserve o domínio HTTPS apontando ao serviço `node-red`, porta interna 1880,
   caminho `/`, sem remover prefixos. Configure timeout do proxy maior que 30 segundos
   e limite de upload coerente com os valores abaixo.

Nenhum desses passos foi executado remotamente nesta mudança. Rebuild não importa
flows automaticamente nem substitui `/data/flows.json`. A chave de IA é
opcional para inicializar o painel, mas necessária para processar áudio: ausência
ou configuração inválida retorna `503 unavailable` sem chamar serviços externos.

### Variáveis genéricas e protocolo

`AI_BASE_URL` é a base HTTPS de um endpoint confiável, sem credenciais, query,
fragmento ou o sufixo `/chat/completions`. O flow acrescenta esse sufixo e usa
`Authorization: Bearer <AI_API_KEY>`. `AI_MODEL` é enviado exatamente como configurado;
não há fallback para `GEMINI_MODEL` ou `GEMINI_API_KEY`. Substitua as variáveis antigas.
Modelo padrão: `google/gemini-3.8-flash`, via OpenRouter, não API nativa Google.
Nesse endereço, `AI_API_KEY` deve ser uma chave do OpenRouter, não a antiga chave Google.

O Compose foi atualizado para encaminhar `AI_*`. Após configurar as variáveis privadas,
recrie o container com esse Compose para que elas cheguem ao processo; adicionar valores
somente à interpolação do Dokploy não os injeta no container antigo. Preserve `/data`.
Isso não exige rebuild da imagem. Importe/publice o flow novo separadamente; um flow
antigo que ainda leia `GEMINI_*` não usa as novas variáveis.

Disponibilidade, créditos, permissões e elegibilidade precisam ser conferidos na
conta do endpoint. Variáveis genéricas não tornam protocolos equivalentes: o flow
usa Chat Completions, com mensagens system/user, áudio `input_audio` e
`response_format: json_schema` estrito. Trocar para API nativa Interactions exigiria
outra adaptação, não apenas mudar a base. O modelo/provedor deve suportar M4A,
schema JSON e `reasoning_effort: low`. A documentação de áudio do OpenRouter permite
M4A em Chat Completions dependendo do provedor; não confundir com Responses API,
que aceita somente WAV/MP3 nesse campo. Não há transcodificação automática.

Esses parâmetros e o timeout `msg.requestTimeout = 300000` pertencem ao nó
**2. Aceitar e preparar IA**: editar/importar e usar Deploy basta para alterar lógica,
sem mudança no app ou rebuild. Os testes locais não comprovam aceitação remota do áudio.

## Endpoint

**POST `https://worker.cordato.cloud/api/collections/audio/process`**

| Entrada | Contrato |
| --- | --- |
| `Authorization` | JWT da sessão de usuário PocketBase, preferencialmente `Bearer <token>`. Não usar token administrativo do Node-RED ou superusuário. |
| `Content-Type` | `multipart/form-data` com boundary, normalmente preenchido pelo cliente. |
| `Content-Length` | Obrigatório; envio chunked sem tamanho conhecido é recusado com 411. |
| `file` | Exatamente um arquivo `.m4a` com MIME `audio/mp4`, não vazio e de até 2 MiB. |
| `reference_date` | Campo opcional `AAAA-MM-DD`, data civil do dispositivo para resolver hoje/ontem. Sem ele, usa o dia atual em `America/Sao_Paulo`. |

Não envie `owner`, IDs, URLs, prompts ou outros campos. O proprietário vem
exclusivamente do record retornado por `users/auth-refresh`; o fluxo exige coleção
`users` e e-mail verificado. O token renovado é descartado; a criação usa o token
original e as regras nativas do PocketBase, sem conta técnica/superusuário.

O corpo multipart inteiro tem limite de **2 MiB + 64 KiB**, verificado antes do
parser. São admitidas no máximo **quatro requisições simultâneas por processo**.
O `202` não libera a vaga: ela permanece ocupada até concluir ou falhar o processamento.
Antes do aceite, uma desconexão encerra na próxima etapa ou timeout; após o aceite,
o processamento continua independente da conexão. Isso não substitui rate limiting no proxy nem
cotas por usuário para proteger o custo da IA.

A verificação `ftyp` identifica um container ISO-BMFF, mas **não comprova codec,
integridade ou duração**. O limite de 30 segundos continua pertencendo à captura
do Flutter; o worker não mede a duração. O provedor pode recusar arquivos inválidos.

O áudio segue em base64 em `messages[].content[].input_audio`, com `format: m4a`,
sem converter bytes nem fazer upload/transcrição separados. É uma chamada de IA por
tentativa autenticada. No host exato `openrouter.ai`, o flow envia
`provider: { require_parameters: true, data_collection: "deny", allow_fallbacks: false }`:
exige os parâmetros, filtra coleta e não troca automaticamente de provedor/modelo.
Em outros hosts compatíveis, não envia o objeto específico `provider`; suas políticas
precisam ser verificadas separadamente. Não é um adapter universal de provedores.

Configure também privacidade/logs da conta OpenRouter e confira a política de quem
processa o áudio. Esses filtros **não garantem retenção zero** nem equivalem a
`store: false` da antiga Interactions API. Não persistimos áudio no worker e liberamos
as referências ao upload após preparar a chamada. Nenhuma chave vai ao Git ou aos logs.

## Validação e resposta

A IA recebe schema restrito, categorias nativas e data de referência. Áudio é
tratado no prompt como conteúdo não confiável; não há ferramentas ou URLs escolhidas
pelo modelo. Isso reduz a superfície, mas não elimina alucinações/prompt injection.
A saída passa por validação própria antes de qualquer escrita:

- Uma única escolha, `finish_reason: stop`, mensagem assistant com conteúdo JSON textual.
- Saída truncada, recusa, tool/function call, envelope de erro ou conteúdo inválido não cadastram.

- Exatamente uma despesa, com descrição de 1–256 caracteres e sem controles.
- Centavos inteiros positivos, representáveis exatamente por um inteiro seguro JS.
  Não há conversão de reais por multiplicação em ponto flutuante.
- Categoria pertencente ao schema atual; `other` quando não couber uma específica.
- Data civil válida, persistida como meia-noite UTC sem conversão de fuso.
- Apenas `owner`, `description`, `amount`, `category` e `occurred_on` no POST.

O modelo não pode indicar outro proprietário nem substituir o endpoint de escrita.
Datas por voz e descrição/categoria inferidas ainda podem estar semanticamente
erradas: nesta versão o cadastro é direto, sem confirmação humana.

Após validar upload, configuração e sessão verificada, retorna **202**, com
`{ "request_id": "…", "status": "processing" }`, sem despesa nem credenciais.
Esse aceite **não confirma cadastro**. O ramo de IA/PocketBase continua em memória,
sem reter a conexão HTTP nem emitir uma segunda resposta.

Não há fila persistente: reinício, rebuild, deploy ou encerramento do processo pode
perder áudios já aceitos. Não há endpoint de status, polling ou notificação ao app.
O usuário recarrega suas despesas posteriormente. Falhas de interpretação/cadastro
após `202` aparecem somente nos logs seguros; não são comunicadas ao usuário.

Falhas **anteriores ao aceite** devolvem `request_id` e `error: { code, message }`, com mensagem local segura:

| HTTP | Situação |
| --- | --- |
| 400 | Upload/campos/data de referência inválidos. |
| 401 | Token ausente/inválido ou sessão recusada. |
| 411 | Upload sem `Content-Length`. |
| 413 | Limite de tamanho excedido. |
| 415 | MIME/container incompatível. |
| 429 | Capacidade local ocupada. |
| 500 | Falha interna inesperada antes das chamadas externas. |
| 502 | Resposta de autenticação inválida. |
| 503 | Configuração ausente ou validação de sessão indisponível. |

Após o aceite, códigos como `multiple_expenses`, `unclear_audio`, `not_expense`,
`invalid_interpretation`, `persistence_rejected` e `persistence_unknown` ficam nos
logs, sem resposta HTTP adicional. O cadastro só é registrado como concluído
quando a resposta do PocketBase confirma os campos persistidos.

Timeouts: **10 s** para autenticação, **300 s (5 minutos)** para IA e **10 s** para cadastro.
O aceite `202` continua anterior à interpretação; o app não aguarda esses 5 minutos.
A operação mantém sua vaga de concorrência durante essa espera, sem retry automático.
Redirecionamentos e retries dos requests estão desabilitados. Cada header externo
é reconstruído: o token PocketBase não é enviado à IA, e a chave de IA não
é enviada ao PocketBase. Respostas remotas/credenciais não são repassadas em erros.

**Não há idempotência durável nesta versão.** Reenviar um áudio pode criar outra
despesa. Se o POST chegar ao PocketBase mas a resposta se perder, retorna
`persistence_unknown` nos logs, sem repetir a escrita. Confira as despesas antes de reenviar.
Desconectar o cliente depois de iniciar o POST não desfaz um cadastro confirmado.

## Logs

Os nós de etapas geram eventos estruturados encaminhados exclusivamente ao nó
**Logs: metadados e diagnóstico seguro**, que aplica uma allowlist, escreve no console do
Node-RED e entrega o objeto sanitizado ao Debug **Áudio: logs seguros**.

Eventos: upload aceito; início/conclusão de autenticação; aceite HTTP 202; início/conclusão de
interpretação; despesa validada; início/conclusão de persistência; conclusão,
falha ou abandono da requisição. Incluem ID de correlação, duração total/da etapa,
status HTTP, etapa/código local de erro e tamanho do áudio quando aplicável.
Rejeições anteriores ao parser vão ao console, com ID/status/código seguros.

**Nunca conecte Debug à mensagem completa dos nós HTTP/Function.** Ela carrega
credenciais e dados pessoais enquanto a operação está em andamento. Os logs
configurados não incluem áudio/base64, transcrição, nomes de arquivo, JWT,
chave de IA, proprietário, descrição, categoria, datas ou valores financeiros.
O Catch não replica a mensagem remota do erro; somente gera código/etapa local.

### Diagnóstico de recusas da IA

Falhas HTTP/transporte na interpretação preservam `code: interpretation_unavailable`
e acrescentam `diagnostic`, escolhido exclusivamente de uma allowlist de códigos
locais. Isso vale tanto para a saída HTTP normal quanto para o Catch, sem segunda
resposta após o aceite e sem retry/cadastro. O corpo remoto é descartado na limpeza.

O classificador reconhece códigos textuais/numéricos de Chat Completions/OpenRouter,
razões estruturadas `google.rpc.ErrorInfo`, campos `google.rpc.BadRequest` quando
encaminhados pelo provedor e status canônicos. Em erros de argumento, pode reconhecer
nomes técnicos fixos na mensagem somente em memória; não copia mensagem, campo,
descrição, status textual remoto, metadata, chave, áudio ou valores para os logs.
Menções a campos são pistas de área, não prova da causa exata. Se não houver detalhe
reconhecido, usa o status HTTP ou um fallback; não inventa uma causa específica.

| `diagnostic` | O que conferir |
| --- | --- |
| `ai_api_key_invalid` | Validade/expiração da chave no ambiente privado. |
| `ai_api_key_restricted` | Restrições de API, origem ou IP da chave. |
| `ai_service_disabled` | Serviço habilitado no projeto do provedor. |
| `ai_billing_required` / `ai_payment_required` | Faturamento/créditos, incluindo HTTP 402. |
| `ai_schema_request` | `response_format`/schema JSON mencionado na recusa. |
| `ai_generation_config` | Reasoning/configuração de geração ou limite de saída mencionado. |
| `ai_audio_request` | Campo de áudio/MIME mencionado; conferir container e compatibilidade. |
| `ai_model_request` | Campo de modelo mencionado na recusa. |
| `ai_invalid_request` | Argumento inválido genérico, sem campo reconhecido. |
| `ai_precondition_failed` | Pré-condição da API; verificar requisitos de conta, região e faturamento. |
| `ai_authentication_failed` / `ai_permission_denied` | Autenticação/permissões da IA, não sessão PocketBase. |
| `ai_model_not_found` / `ai_provider_unavailable` | Modelo ou rota de provedor indisponível. |
| `ai_quota_exceeded` | Limite/cota do provedor. |
| `ai_upstream_unavailable` / `ai_upstream_timeout` | Serviço remoto indisponível/timeout. |
| `ai_transport_failure` / `ai_error_unclassified` | Sem resposta HTTP reconhecida ou erro não classificado. |

O diagnóstico também pertence aos nós Function: para atualizá-lo, importe/edite
o flow e use Deploy. A topologia do flow e o contrato do app não mudam.
Na nova tentativa, consulte apenas **Áudio: logs seguros** e compartilhe `code`,
`diagnostic`, `stage`, `status` e `upstream_status`, nunca a mensagem completa.

## Verificação e limites

Os testes unitários sem rede em `worker/test/audio.test.js` executam as funções do JSON,
cobrindo payloads, limites, validação, limpeza, erros, cancelamento, concorrência
de admissão, export e sanitização. `audio_flow.test.js` também executa o pipeline em
sandbox sem helper global, testa alteração de timeout somente no JSON e verifica
que a imagem não contém lógica do flow. Não montam o editor nem iniciam containers.
Testes locais não comprovam chamadas OpenRouter/PocketBase ou deploy.
A homologação deve ocorrer no Dokploy, com áudio de teste e conta própria.

Verificação local desta revisão (11/11/2026): `node --check settings.js`,
`node --check middleware/audio_upload_gate.js`, `node --test test/*.test.js` (192 aprovados),
`sh -n docker/entrypoint.sh`, `shellcheck docker/entrypoint.sh` e `git diff --check`
concluídos sem falhas. Docker não está disponível neste ambiente; os dois pares
Compose não foram revalidados. Sem build, container, deploy ou chamada remota.

O Flutter envia multipart com JWT atual, MIME `audio/mp4` e data civil local.
Após `202` válido, mostra “Áudio recebido para processamento”, sem polling,
retry ou atualização automática da Dashboard/widget. Timeout ou perda de resposta
orienta conferir despesas antes de reenviar. `WORKER_URL` é separado de `BASE_URL`.
Este endpoint não pertence ao PocketBase; a integração ainda exige homologação remota.

Referências: [áudio no OpenRouter](https://openrouter.ai/docs/guides/overview/multimodal/audio),
[parâmetros](https://openrouter.ai/docs/api/reference/parameters),
[roteamento e privacidade](https://openrouter.ai/docs/features/provider-routing) e
[Gemini 3.8 Flash](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash).
