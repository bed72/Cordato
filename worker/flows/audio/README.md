# Áudio → Despesa

Fluxo assíncrono em memória com nós nativos e JavaScript próprio, sem SDKs ou bibliotecas npm
adicionais. Recebe **uma despesa por áudio**, valida a sessão, envia o arquivo
diretamente ao Gemini e cadastra a despesa na API nativa do PocketBase.

```text
POST multipart → validar upload → PocketBase auth-refresh → HTTP 202
    → Gemini (áudio + schema JSON) → validar despesa → PocketBase create → log seguro
```

`flows.json` contém a aba completa para importação. As funções chamam
`global.get('cordatoAudio')`, disponibilizado pelo `settings.js` da nossa imagem.
A implementação está em `audio.js`, testável separadamente dos nós visuais.
**Importar esse JSON em uma imagem antiga ou em outro Node-RED não basta**:
o módulo e as configurações de upload também precisam estar instalados.

## Configurar no Dokploy

1. Preserve as variáveis administrativas e `NODE_RED_CREDENTIAL_SECRET` existentes.
2. Acrescente em **Environment**, sem enviar os valores privados ao chat/Git:

   ```env
   POCKETBASE_URL=https://pocketbase.cordato.cloud
   GEMINI_API_KEY=COLE_A_CHAVE_SOMENTE_NO_DOKPLOY
   GEMINI_MODEL=gemini-3.8-flash
   ```

3. Faça **Rebuild** com esta versão do repositório. Isso inclui `audio.js` e habilita
   a raiz HTTP `/api`, separada do editor autenticado `/admin`.
4. No editor, exclua a aba antiga **Hello World** se ainda existir. Sua exclusão
   do repositório não remove o exemplo do volume remoto.
5. Importe `worker/flows/audio/flows.json`, confira os nós e use **Deploy** no editor.
6. Preserve o domínio HTTPS apontando ao serviço `node-red`, porta interna 1880,
   caminho `/`, sem remover prefixos. Configure timeout do proxy maior que 30 segundos
   e limite de upload coerente com os valores abaixo.

Nenhum desses passos foi executado remotamente nesta mudança. Rebuild não importa
flows automaticamente nem substitui `/data/flows.json`. A nova chave Gemini é
opcional para inicializar o painel, mas necessária para processar áudio: ausência
ou configuração inválida retorna `503 unavailable` sem chamar serviços externos.

O modelo foi escolhido com base na documentação oficial de áudio em 10/11/2026.
Disponibilidade, cotas, faturamento e permissões da chave precisam ser conferidos
na sua conta Google. Trocar `GEMINI_MODEL` não garante compatibilidade: o modelo
precisa aceitar áudio, Interactions API, saída estruturada e thinking `low`.
O worker usa `generation_config.thinking_level: low`: a documentação específica
do Gemini 3.8 Flash permite `low`, `medium` e `high`, mas informa que `minimal`
não é suportado e retorna erro. A configuração anterior com `minimal` era
incompatível com o modelo padrão; sua correção exige rebuild da imagem, não
mudança no app nem nova importação do flow, cujas funções delegadas permanecem iguais.
Isso corrige uma incompatibilidade documentada, sem comprovar sucesso remoto.

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
cotas por usuário para proteger o custo do Gemini.

A verificação `ftyp` identifica um container ISO-BMFF, mas **não comprova codec,
integridade ou duração**. O limite de 30 segundos continua pertencendo à captura
do Flutter; o worker não mede a duração. Gemini pode recusar arquivos inválidos.

O áudio segue inline em base64 como `audio/m4a`, sem conversão dos bytes e sem
Files API/transcrição separada. É uma chamada Gemini por tentativa autenticada.
`store: false` solicita que a Interactions API não armazene a interação para
recuperação, mas **não constitui garantia de retenção zero pelo Google**;
aplicam-se as condições e políticas da conta/provedor. Não persistimos o áudio
no worker e liberamos as referências ao upload após preparar a chamada.

## Validação e resposta

O Gemini recebe schema restrito, categorias nativas e data de referência. Áudio é
tratado no prompt como conteúdo não confiável; não há ferramentas ou URLs escolhidas
pelo modelo. Isso reduz a superfície, mas não elimina alucinações/prompt injection.
A saída passa por validação própria antes de qualquer escrita:

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
Esse aceite **não confirma cadastro**. O ramo de Gemini/PocketBase continua em memória,
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

Timeouts: **10 s** para autenticação, **45 s** para Gemini e **10 s** para cadastro.
Redirecionamentos e retries dos requests estão desabilitados. Cada header externo
é reconstruído: o token PocketBase não é enviado ao Google, e a chave Gemini não
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
chave Gemini, proprietário, descrição, categoria, datas ou valores financeiros.
O Catch não replica a mensagem remota do erro; somente gera código/etapa local.

### Diagnóstico de recusas do Gemini

Falhas HTTP/transporte na interpretação preservam `code: interpretation_unavailable`
e acrescentam `diagnostic`, escolhido exclusivamente de uma allowlist de códigos
locais. Isso vale tanto para a saída HTTP normal quanto para o Catch, sem segunda
resposta após o aceite e sem retry/cadastro. O corpo remoto é descartado na limpeza.

O classificador prioriza razões estruturadas `google.rpc.ErrorInfo`, depois campos
de `google.rpc.BadRequest` e status canônicos. Em erros de argumento, pode reconhecer
nomes técnicos fixos na mensagem somente em memória; não copia mensagem, campo,
descrição, status textual remoto, metadata, chave, áudio ou valores para os logs.
Menções a campos são pistas de área, não prova da causa exata. Se não houver detalhe
reconhecido, usa o status HTTP ou um fallback; não inventa uma causa específica.

| `diagnostic` | O que conferir |
| --- | --- |
| `gemini_api_key_invalid` | Validade/expiração da chave no ambiente privado. |
| `gemini_api_key_restricted` | Restrições de API, origem ou IP da chave. |
| `gemini_service_disabled` | Serviço Google habilitado no projeto. |
| `gemini_billing_required` | Faturamento do projeto; sinalizado por razão estruturada. |
| `gemini_schema_request` | `response_format`/schema JSON mencionado na recusa. |
| `gemini_generation_config` | `generation_config`, `thinking_level` ou limite de saída mencionado. |
| `gemini_audio_request` | Campo de áudio/MIME mencionado; conferir container e compatibilidade. |
| `gemini_model_request` | Campo de modelo mencionado na recusa. |
| `gemini_invalid_request` | Argumento inválido genérico, sem campo reconhecido. |
| `gemini_precondition_failed` | Pré-condição da API; verificar requisitos de conta, região e faturamento. |
| `gemini_authentication_failed` / `gemini_permission_denied` | Autenticação/permissões do projeto Google, não sessão PocketBase. |
| `gemini_model_not_found` | Recurso/modelo não encontrado no endpoint fixo de interpretação. |
| `gemini_quota_exceeded` | Limite/cota do provedor. |
| `gemini_upstream_unavailable` / `gemini_upstream_timeout` | Serviço remoto indisponível/timeout. |
| `gemini_transport_failure` / `gemini_error_unclassified` | Sem resposta HTTP reconhecida ou erro não classificado. |

Para instalar esse diagnóstico, faça rebuild autorizado da imagem: somente importar
o JSON não atualiza `audio.js`. A topologia do flow e o contrato do app não mudam.
Na nova tentativa, consulte apenas **Áudio: logs seguros** e compartilhe `code`,
`diagnostic`, `stage`, `status` e `upstream_status`, nunca a mensagem completa.

## Verificação e limites

Foram adicionados testes unitários sem rede em `worker/test/audio.test.js`,
cobrindo payloads, limites, validação, limpeza, erros, cancelamento, concorrência
de admissão, export e sanitização. Não montam o editor e não iniciam containers.
Testes locais não comprovam chamadas Gemini/PocketBase ou deploy.
A homologação deve ocorrer no Dokploy, com áudio de teste e conta própria.

Verificação local desta revisão (10/11/2026): `node --check settings.js`,
`node --check flows/audio/audio.js`, `node --test test/*.test.js` (141 aprovados),
`sh -n docker/entrypoint.sh`, `shellcheck docker/entrypoint.sh` e `git diff --check`
concluídos sem falhas. Docker não está disponível neste ambiente; os dois pares
Compose não foram revalidados. Sem build, container, deploy ou chamada remota.

O Flutter envia multipart com JWT atual, MIME `audio/mp4` e data civil local.
Após `202` válido, mostra “Áudio recebido para processamento”, sem polling,
retry ou atualização automática da Dashboard/widget. Timeout ou perda de resposta
orienta conferir despesas antes de reenviar. `WORKER_URL` é separado de `BASE_URL`.
Este endpoint não pertence ao PocketBase; a integração ainda exige homologação remota.

Referências: [Gemini 3.8 Flash e níveis de thinking](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash),
[áudio Gemini](https://ai.google.dev/gemini-api/docs/audio),
[saída estruturada](https://ai.google.dev/gemini-api/docs/structured-output) e
[Interactions API](https://ai.google.dev/api/interactions-api).
