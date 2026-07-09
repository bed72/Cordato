## Why

Uma pessoa já corrige o próprio nome (`PATCH /persons/me/name`) e troca o próprio e-mail (`PATCH
/persons/me/email`), mas a **senha** — o segredo que autentica todas as demais operações — fica presa ao
valor do cadastro. Quem suspeita que a senha vazou, ou só quer rotacioná-la, não tem hoje como trocá-la. A
senha é o mais **sensível** dos campos: trocá-la é uma operação de step-up (exige a senha atual, como a troca
de e-mail e a exclusão de conta já exigem) e, por ser o gatilho clássico de comprometimento, **encerra as
demais sessões vivas** da pessoa — a decisão de invalidação de sessões que a troca de e-mail explicitamente
deixou "para revisitar junto com a troca de senha" vence aqui.

## What Changes

- Nova operação de aplicação em `identity`: dado o `personId` do ator autenticado, a **senha atual** para
  confirmação e a **nova senha**, resolve a pessoa **ativa**, confere a senha atual, valida a nova senha pela
  política (`PasswordValueObject`), rejeita uma nova senha **igual à atual**, e persiste **apenas** o hash da
  nova senha — nome, e-mail e status permanecem intocados. Retorna um resultado `sealed` exaustivo: sucesso
  com a visão pública, ou uma falha de domínio (`WeakPassword`, `SamePassword`, `InvalidCredentials`,
  `PersonNotFound`).
- **Ao trocar a senha, todas as demais sessões vivas da pessoa são revogadas; a sessão que fez a troca
  permanece válida.** É uma nova operação de persistência de sessão (`core`): revogar todas as sessões de um
  `personId` **exceto** a atual. O token opaco foi escolhido justamente para tornar essa revogação imediata e
  autoritativa no servidor.
- Nova rota HTTP protegida **`PATCH /persons/me/password`** (`@Authenticated`), corpo JSON
  `{ "currentPassword": "...", "newPassword": "..." }`, que delega ao novo use case usando o `personId` **e a
  sessão atual** do ator. Sucesso responde `200 OK` com a **mesma** `PersonResponse` reutilizada por cadastro,
  `GET /persons/me` e as edições de nome/e-mail (a visão pública não muda numa troca de senha, mas a forma é
  uniforme).
- **O `AuthenticatedActor` da borda passa a carregar também o `sessionId` da sessão atual**, além do
  `personId`. O filtro já resolve a `SessionEntity` inteira; agora guarda o id dela para que uma operação de
  escopo de sessão (revogar "as outras, menos esta") saiba qual poupar. Mudança **aditiva**: os handlers
  existentes (`me`, `updateName`, `updateEmail`) seguem usando só o `personId`.
- Validação de borda do novo request espelha as regras de domínio referenciando as **constantes do próprio
  value object** (`@NotBlank` + `@Size(min = PasswordValueObject.MIN_LENGTH)` na nova senha; `@NotBlank` na
  senha atual), nunca literais duplicados; o `PasswordValueObject` segue a autoridade única da política.
- Mapeamento de erro de domínio, por **kind**: nova senha fraca → `422` (a política mínima é uma regra
  **pública**, pode ser dita abertamente); nova senha igual à atual → `422`; senha atual incorreta **e**
  sessão órfã (pessoa não mais ativa) → o **mesmo `401` neutro** que o guard de borda emite — indistinguíveis
  entre si e de um token ausente/inválido.
- `PersonControllerDoc` ganha a documentação OpenAPI da nova rota; o README de `identity` passa a documentar,
  em linguagem de negócio, a regra "trocar a própria senha (com a senha atual), encerrando as demais sessões".

## Capabilities

### New Capabilities
<!-- Nenhuma capability nova: a troca de senha estende capabilities existentes. -->

### Modified Capabilities
- `person-profile`: ganha a operação de aplicação que troca a senha da própria pessoa ativa — confirma a
  senha atual, valida a nova senha pela política, rejeita uma nova senha igual à atual, persiste só o hash e
  **manda revogar as demais sessões vivas** — como resultado `sealed` exaustivo (`WeakPassword`,
  `SamePassword`, `InvalidCredentials`, `PersonNotFound`), sem exceções.
- `identity-http-api`: ganha a rota protegida `PATCH /persons/me/password` (validação de borda de presença da
  senha atual e de presença+tamanho mínimo da nova senha; mapeamento por kind: fraca/igual → `422`,
  incorreta/sessão-órfã → `401` neutro compartilhado), reutilizando a `PersonResponse` no sucesso.
- `session-management`: ganha a operação de **revogar todas as sessões de uma pessoa exceto uma** (a atual),
  autoritativa no servidor — a contrapartida de encerramento em massa que o token opaco habilita.
- `http-authentication-guard`: o ator autenticado tipado disponível ao handler passa a carregar também o
  `sessionId` da sessão viva atual (além do `personId`), para operações de escopo de sessão; o filtro o
  resolve e o guarda, o binder o lê de volta.

## Impact

- **Código novo (`identity`)**: `UpdatePasswordCommand`, `UpdatePasswordResult`, `UpdatePasswordUseCase`,
  `UpdatePasswordError` (domínio); `UpdatePasswordRequest` (DTO `@Serdeable`), seu request-mapper e o
  `UpdatePasswordErrorResponseMapper` (borda); método `PATCH /me/password` em `PersonController` + entrada em
  `PersonControllerDoc`.
- **Código modificado (`core`)**: `SessionRepository` ganha `revokeAllForPersonExcept(personId, sessionId)`,
  implementada no `PersistenceSessionRepository` como um `DELETE ... WHERE person_id = ? AND id <> ?`;
  `AuthenticatedActor` ganha o campo `sessionId` (e a segunda chave de atributo); `AuthenticatedFilter` guarda
  o `session.id` além do `personId`; `AuthenticatedActorBinder` lê os dois atributos; `FakeSessionRepository`
  (test double) ganha o novo método.
- **Código modificado (`identity`)**: `PersonRepository` ganha `updatePassword(id, hash): Boolean` (atualiza
  só o hash da pessoa **ativa**), implementada no `PersistencePersonRepository`; `IdentityFactory` fia o novo
  use case (recebendo `PasswordHasherPort`, `PersonRepository` e o `SessionRepository` do core);
  `messages.properties` ganha as chaves i18n do novo request/erro.
- **APIs**: novo endpoint `PATCH /v1/persons/me/password`. Rotas existentes intactas.
- **Docs**: `features/identity/README.md` documenta a nova regra de negócio.
- Sem novas dependências.
