# Áudio → Despesa

Fluxo síncrono com nós nativos e JavaScript próprio, sem SDKs ou bibliotecas npm
adicionais. Recebe **uma despesa por áudio**, valida a sessão, envia o arquivo
diretamente ao Gemini e cadastra a despesa na API nativa do PocketBase.

```text
POST multipart → validar upload → PocketBase auth-refresh
    → Gemini (áudio + schema JSON) → validar despesa → PocketBase create
    → HTTP 201 somente após confirmação do cadastro
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
   caminho `/`, sem remover prefixos. Configure timeout do proxy maior que 75 segundos
   e limite de upload coerente com os valores abaixo.

Nenhum desses passos foi executado remotamente nesta mudança. Rebuild não importa
flows automaticamente nem substitui `/data/flows.json`. A nova chave Gemini é
opcional para inicializar o painel, mas necessária para processar áudio: ausência
ou configuração inválida retorna `503 unavailable` sem chamar serviços externos.

O modelo foi escolhido com base na documentação oficial de áudio em 10/11/2026.
Disponibilidade, cotas, faturamento e permissões da chave precisam ser conferidos
na sua conta Google. Trocar `GEMINI_MODEL` não garante compatibilidade: o modelo
precisa aceitar áudio, Interactions API, saída estruturada e thinking minimal.

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
Uma desconexão não libera uma operação externa ainda em andamento: ela encerra
na próxima etapa ou no timeout. Isso não substitui rate limiting no proxy nem
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

Sucesso retorna **201**, com `request_id` e `expense` contendo os campos confirmados
e o ID do PocketBase. Não retorna `202`, pois não existe fila ou aceite assíncrono.
Falhas devolvem `request_id` e `error: { code, message }`, com mensagem local segura:

| HTTP | Situação |
| --- | --- |
| 400 | Upload/campos/data de referência inválidos ou criação recusada por validação nativa. |
| 401 | Token ausente/inválido ou sessão recusada. |
| 403 | PocketBase recusou autorização para cadastrar. |
| 411 | Upload sem `Content-Length`. |
| 413 | Limite de tamanho excedido. |
| 415 | MIME/container incompatível. |
| 422 | Mais de uma despesa, áudio ambíguo ou conteúdo que não descreve um gasto realizado. |
| 429 | Capacidade local ocupada ou limitação do PocketBase ao cadastrar. |
| 500 | Falha interna inesperada antes das chamadas externas. |
| 502 | Falha externa/interpretação inválida ou persistência sem confirmação. |
| 503 | Configuração ausente ou validação de sessão indisponível. |

Timeouts: **10 s** para autenticação, **45 s** para Gemini e **10 s** para cadastro.
Redirecionamentos e retries dos requests estão desabilitados. Cada header externo
é reconstruído: o token PocketBase não é enviado ao Google, e a chave Gemini não
é enviada ao PocketBase. Respostas remotas/credenciais não são repassadas em erros.

**Não há idempotência durável nesta versão.** Reenviar um áudio pode criar outra
despesa. Se o POST chegar ao PocketBase mas a resposta se perder, retorna
`persistence_unknown`, sem repetir a escrita. Confira as despesas antes de reenviar.
Desconectar o cliente depois de iniciar o POST não desfaz um cadastro confirmado.

## Logs

Os nós de etapas geram eventos estruturados encaminhados exclusivamente ao nó
**Logs: somente metadados**, que aplica uma allowlist, escreve no console do
Node-RED e entrega o objeto sanitizado ao Debug **Áudio: logs seguros**.

Eventos: upload aceito; início/conclusão de autenticação; início/conclusão de
interpretação; despesa validada; início/conclusão de persistência; conclusão,
falha ou abandono da requisição. Incluem ID de correlação, duração total/da etapa,
status HTTP, etapa/código local de erro e tamanho do áudio quando aplicável.
Rejeições anteriores ao parser vão ao console, com ID/status/código seguros.

**Nunca conecte Debug à mensagem completa dos nós HTTP/Function.** Ela carrega
credenciais e dados pessoais enquanto a operação está em andamento. Os logs
configurados não incluem áudio/base64, transcrição, nomes de arquivo, JWT,
chave Gemini, proprietário, descrição, categoria, datas ou valores financeiros.
O Catch não replica a mensagem remota do erro; somente gera código/etapa local.

## Verificação e limites

Foram adicionados testes unitários sem rede em `worker/test/audio.test.js`,
cobrindo payloads, limites, validação, limpeza, erros, cancelamento, concorrência
de admissão, export e sanitização. Não montam o editor e não iniciam containers.
Nesta tarefa não foram executados testes locais, builds, chamadas Gemini/PocketBase
ou deploy. A homologação deve ocorrer no Dokploy, com áudio de teste e conta própria.

O Flutter não foi alterado: a seta ainda retorna envio indisponível. Este endpoint
do worker não é um endpoint implantado no PocketBase nem comprova integração do app.
O cliente futuro precisará tratar a resposta síncrona, recarregar despesas/métricas
e solicitar atualização do widget após cadastro confirmado, em tarefa separada.

Referências: [áudio Gemini](https://ai.google.dev/gemini-api/docs/audio),
[saída estruturada](https://ai.google.dev/gemini-api/docs/structured-output) e
[Interactions API](https://ai.google.dev/api/interactions-api).
