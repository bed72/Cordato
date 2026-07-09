## Why

Uma pessoa já corrige o próprio nome (`PATCH /persons/me`), mas o e-mail — o identificador de login e o
canal de recuperação — fica preso ao valor do cadastro. Um endereço digitado errado, ou um e-mail que a
pessoa perdeu acesso, não tem hoje como ser corrigido. Diferente do nome, o e-mail é **sensível** (o README
de `identity` chama o nome de "o único campo mutável e **não-sensível**"): trocá-lo é uma operação de
step-up que exige confirmação de senha, precisa manter a unicidade global do e-mail e não pode virar um
oráculo de descoberta de contas alheias.

## What Changes

- Nova operação de aplicação em `identity`: dado o `personId` do ator autenticado, um novo e-mail e a
  **senha atual** para confirmação, resolve a pessoa **ativa**, confere a senha, valida o novo
  `EmailValueObject`, garante a unicidade global do e-mail e persiste **apenas** o e-mail — nome, senha
  (hash) e status permanecem intocados. Retorna um resultado `sealed` exaustivo: sucesso com a visão
  pública atualizada, ou uma falha de domínio.
- Nova rota HTTP protegida **`PATCH /persons/me/email`** (`@Authenticated`), corpo JSON
  `{ "email": "...", "password": "..." }`, que delega ao novo use case usando o `personId` do ator. Sucesso
  responde `200 OK` com a **mesma** `PersonResponse` reutilizada por cadastro, `GET /persons/me` e a edição
  de nome.
- **BREAKING** (rota ainda não liberada): a edição de nome muda de `PATCH /persons/me` para
  **`PATCH /persons/me/name`**, para que as duas edições sejam sub-recursos simétricos de campo único
  (`/me/name`, `/me/email`) em vez de um `PATCH /me` ambíguo. `GET /persons/me` permanece.
- Validação de borda do novo request espelha as regras de domínio referenciando as **constantes do próprio
  value object** (`@NotBlank` + `@Pattern(regexp = EmailValueObject.PATTERN)` no e-mail; `@NotBlank` na
  senha), nunca literais duplicados; os value objects seguem sendo a autoridade única das invariantes.
- Mapeamento de erro de domínio, por **kind**: e-mail malformado → `422`; e-mail já em uso → `422` **neutro
  e genérico** (mesma postura de não-vazamento do cadastro, nunca um `FieldError(field="email")` nem status
  distinto); senha de confirmação incorreta **e** sessão órfã (pessoa não mais ativa) → o **mesmo `401`
  neutro** que o guard de borda emite — indistinguíveis entre si e de um token ausente/inválido.
- `PersonControllerDoc` ganha a documentação OpenAPI da nova rota e reflete o novo path do nome; o README de
  `identity` passa a documentar, em linguagem de negócio, a regra "trocar o próprio e-mail (com senha)".

## Capabilities

### New Capabilities
<!-- Nenhuma capability nova: a troca de e-mail estende capabilities existentes. -->

### Modified Capabilities
- `person-profile`: ganha a operação de aplicação que troca o e-mail da própria pessoa ativa — confirma a
  senha atual, valida o novo `EmailValueObject`, exige unicidade global e devolve a visão pública atualizada
  — como resultado `sealed` exaustivo (`InvalidEmail`, `EmailAlreadyInUse`, `InvalidCredentials`,
  `PersonNotFound`), sem exceções. Trocar para o **próprio** e-mail atual é um no-op bem-sucedido, não um
  conflito.
- `identity-http-api`: ganha a rota protegida `PATCH /persons/me/email` (validação de borda de presença e
  formato do e-mail e de presença da senha, mapeamento por kind: malformado/em-uso → `422`,
  senha-incorreta/sessão-órfã → `401` neutro compartilhado), reutilizando a `PersonResponse` no sucesso; e
  **move** a edição de nome de `PATCH /persons/me` para `PATCH /persons/me/name` (mesmo comportamento, novo
  path).

## Impact

- **Código novo (`identity`)**: `UpdateEmailCommand`, `UpdateEmailResult`, `UpdateEmailUseCase`,
  `UpdateEmailError` (domínio); `UpdateEmailRequest` (DTO `@Serdeable`), seu request-mapper e o
  `UpdateEmailErrorResponseMapper` (borda); método `PATCH /me/email` em `PersonController` + entrada em
  `PersonControllerDoc`.
- **Código modificado**: `PersonRepository` ganha uma operação estreita de troca de e-mail da pessoa
  **ativa** que retorna um resultado de **três desfechos** (atualizado / e-mail já em uso / pessoa
  não-ativa), implementada no `PersistencePersonRepository` como um `UPDATE` só da coluna do e-mail sob a
  restrição de unicidade; `PersonController`/`PersonControllerDoc` movem o path do nome para `/me/name`;
  `IdentityFactory` fia o novo use case (recebendo `PasswordHasherPort` + `PersonRepository`);
  `messages.properties` ganha as chaves i18n do novo request/erro.
- **APIs**: novo endpoint `PATCH /v1/persons/me/email`; a edição de nome passa a
  `PATCH /v1/persons/me/name` (era `PATCH /v1/persons/me`). `GET /v1/persons/me` intacto.
- **Docs**: `features/identity/README.md` documenta a nova regra de negócio.
- Sem novas dependências.
