# Bruno — login e upload locais

Somente duas requests:

1. `authentication/01-login.bru`: login nativo de `users`, captura o token em memória.
2. `audio/02-upload-file.bru`: envia o arquivo binário com o token do login.

Não há refresh, cadastro, CRUD, produção, permissões adicionais ou login oculto.
O script da coleção aceita somente `http://127.0.0.1:<porta>`.

## Interface

1. Abra `backend/bruno/` e selecione o ambiente **development** já preparado nesta
   máquina com a conta fictícia local. Ele é privado e ignorado pelo Git.
2. Envie **Login local**. Esperado: `200`.
3. Em **Upload de áudio local → Body**, selecione uma gravação M4A sua, não vazia,
   de até 2 MiB. Alternativamente configure `audioFile` no ambiente.
4. Envie o upload. Esperado: `202` com `{"status":"accepted"}`.

Se o desktop ainda mostrar requests antigas, feche a coleção e abra novamente a
pasta. O servidor Go local precisa estar ativo (`make run` em `backend/`).

Para outra máquina, use o ambiente versionado **example** e preencha os
Secrets `email`, `password` e, opcionalmente, `audioFile`. Use conta `users`
verificada no banco local, nunca as credenciais de administrador. Não há criação
ou verificação automática de contas. Não desabilite a regra de autenticação.

O ambiente privado `environments/development.bru` contém dados locais em texto simples por solicitação
explícita; não compartilhe nem versione esse arquivo. O ambiente versionado contém
somente URL e nomes de Secrets. O token não é salvo em nenhum ambiente.

## CLI

Requer CLI Bruno 4+ e Node.js. O uso normal pela interface não precisa de arquivos
`.env` do Bruno. Para execução opcional pela CLI, forneça no processo
`CORDATO_DEVELOPMENT_EMAIL`, `CORDATO_DEVELOPMENT_PASSWORD` e
`CORDATO_DEVELOPMENT_AUDIO_FILE` (caminho absoluto da gravação):

```sh
make bruno
make bruno-upload
```

O upload executa login e envio na mesma sessão. A CLI 4.0.0 não interpola paths de
`body:file` antes da leitura; o helper monta uma cópia temporária das duas requests
com o caminho resolvido, sem copiar bytes ou credenciais, e remove seu workspace.
Não use logs ou reports com bodies/headers de autenticação.

## Verificações

```sh
make bruno-check
make test-bruno
```

Offline: parser, duas requests exatas, origem local, montagem de login, token em
memória e upload sem login bloqueado. E2E: banco e usuário temporários, login e
upload de bytes sintéticos por HTTP em loopback. Nenhuma conta existente ou SMTP
externo é usado pelo E2E. Isso não comprova automação visual do desktop.

O endpoint apenas aceita e descarta os bytes: não processa áudio nem cria despesa.
