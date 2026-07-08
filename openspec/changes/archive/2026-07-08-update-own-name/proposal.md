## Why

Uma pessoa pode se cadastrar e recuperar a própria visão pública (`GET /persons/me`), mas hoje não há
nenhuma forma de corrigir o próprio nome depois do cadastro — o único campo mutável e não-sensível do
perfil. Faltando isso, um erro de digitação no cadastro fica preso para sempre. Esta mudança adiciona a
edição do próprio nome, mantendo `identity` sem vazar existência de conta e sem tocar dados sensíveis.

## What Changes

- Nova operação de aplicação em `identity`: dado o `personId` do ator autenticado e um novo nome,
  resolve a pessoa **ativa**, aplica o novo `NameValueObject` e persiste **apenas** o nome — e-mail,
  senha (hash) e status permanecem intocados. Retorna um resultado `sealed` exaustivo: sucesso com a
  visão pública atualizada, ou uma falha de domínio.
- Nova rota HTTP protegida **`PATCH /persons/me`** (`@Authenticated`), corpo JSON `{ "name": "..." }`,
  que delega ao novo use case usando o `personId` do ator autenticado. Sucesso responde `200 OK` com a
  **mesma** representação pública de pessoa (`PersonResponse`) reutilizada por cadastro e `GET /persons/me`.
- Validação de borda do novo request espelha a regra de domínio do nome referenciando as **constantes do
  próprio `NameValueObject`** (`@NotBlank` + `@Size(max = NameValueObject.MAX_LENGTH)`), nunca um literal
  duplicado; o value object segue sendo a autoridade única da invariante.
- Mapeamento de erro de domínio: nome inválido → `422 Unprocessable Entity` no corpo de erro
  compartilhado; sessão órfã (pessoa não mais ativa) → o **mesmo `401` neutro** que o guard de borda e o
  `GET /persons/me` já emitem — indistinguível de token ausente/inválido.
- `PersonControllerDoc` ganha a documentação OpenAPI da nova rota; o README de `identity` passa a
  documentar, em linguagem de negócio, a regra "editar o próprio nome".

## Capabilities

### New Capabilities
<!-- Nenhuma capability nova: a edição do nome estende capabilities existentes. -->

### Modified Capabilities
- `person-profile`: deixa de ser estritamente read-only — ganha a operação de aplicação que atualiza o
  nome da própria pessoa ativa e devolve a visão pública atualizada (ou a falha `PersonNotFound` para a
  sessão órfã), como resultado `sealed` exaustivo e sem exceções. A nova falha de nome inválido é do
  domínio (o `NameValueObject`), não da operação.
- `identity-http-api`: ganha a rota protegida `PATCH /persons/me`, sua validação de borda de presença e
  tamanho do nome (referenciando o value object), o mapeamento do nome inválido para `422` e da sessão
  órfã para o `401` neutro compartilhado, reutilizando a representação pública de pessoa na resposta de
  sucesso.

## Impact

- **Código novo (`identity`)**: `UpdateNameCommand`, `UpdateNameResult`, `UpdateNameUseCase`,
  `UpdateNameError` (domínio); `UpdateNameRequest` (DTO `@Serdeable`), o mapeamento de request e o
  `UpdateNameErrorResponseMapper` (borda); método `PATCH` em `PersonController` + entrada em
  `PersonControllerDoc`.
- **Código modificado**: `PersonRepository` ganha a capacidade de persistir a alteração de nome de uma
  pessoa; `IdentityFactory` fia o novo use case; `messages.properties` ganha as chaves i18n do novo
  request/erro.
- **APIs**: novo endpoint `PATCH /v1/persons/me`. Sem breaking change — rotas existentes intactas.
- **Docs**: `features/identity/README.md` documenta a nova regra de negócio.
- Sem novas dependências.
