## 1. Core: revogação de sessões e ator com sessionId

- [x] 1.1 Estender `core/application/driven/repositories/SessionRepository.kt` com `revokeAllForPersonExcept(personId: String, sessionId: String): Int` — revoga todas as sessões vivas da pessoa exceto a indicada; documentar que é autoritativa (a sessão revogada deixa de ser resolvida por `findActiveByToken`) e que "nada a revogar" é válido (retorna 0), não um erro
- [x] 1.2 Implementar `revokeAllForPersonExcept` em `core/infrastructure/repositories/PersistenceSessionRepository.kt` como `DELETE FROM session WHERE person_id = ? AND id <> ?`, retornando a contagem de linhas afetadas
- [x] 1.3 Estender `AuthenticatedActor` (`core/.../authentication/actors/`) com o campo `sessionId` (data class `personId` + `sessionId`, ainda não value class), adicionando a segunda chave de atributo no `companion` (ex. `ATTRIBUTE_SESSION`); atualizar o KDoc ("carries the personId **and** the current sessionId")
- [x] 1.4 Atualizar `AuthenticatedFilter` para guardar `session.id` sob a nova chave de atributo, além de `session.personId`
- [x] 1.5 Atualizar `AuthenticatedActorBinder` para ler as duas chaves e montar `AuthenticatedActor(personId, sessionId)`; atributo ausente ⇒ binding não satisfeito (inalterado)
- [x] 1.6 Estender o `FakeSessionRepository` (`core/factories/`) com o novo método, refletindo a revogação in-memory, para os testes

## 2. Identity: domínio e persistência

- [x] 2.1 Criar `domain/errors/UpdatePasswordError.kt` — sealed com `WeakPassword`, `SamePassword`, `InvalidCredentials`, `PersonNotFound`; documentar que `WeakPassword`/`SamePassword` são regras públicas (`422` específico) e que `InvalidCredentials`/`PersonNotFound` são neutros, indistinguíveis do `401` do guard
- [x] 2.2 Estender `application/driven/repositories/PersonRepository.kt` com `updatePassword(id: String, hash: String): Boolean` — atualiza **apenas** o hash da pessoa **ativa** (dois estados: `true` atualizado / `false` nenhuma pessoa ativa), documentando que só o hash muda
- [x] 2.3 Implementar `updatePassword` em `infrastructure/repositories/PersistencePersonRepository.kt` como `UPDATE person SET password_hash=? WHERE id=? AND status=ACTIVE` (0 linhas ⇒ `false`), via `PersonRecordMapper`/property setters conforme a convenção de mappers

## 3. Identity: aplicação (use case)

- [x] 3.1 Criar `application/driving/commands/UpdatePasswordCommand.kt` (`personId`, `sessionId`, `currentPassword` cru, `newPassword` cru)
- [x] 3.2 Criar `application/driving/results/UpdatePasswordResult.kt` — sealed: `Success(person)` com a visão pública e `Failure(error: UpdatePasswordError)`
- [x] 3.3 Criar `application/driving/use_cases/UpdatePasswordUseCase.kt` (recebe `PasswordHasherPort`, `PersonRepository` e o `SessionRepository` do core) — ordem: `PasswordValueObject.of(newPassword)` (rejeição ⇒ `WeakPassword`) → `findById` (ausente ⇒ `PersonNotFound`) → `verify(currentPassword, hash)` falso ⇒ `InvalidCredentials` → `verify(newPassword, hash)` verdadeiro ⇒ `SamePassword` → `create(newPassword)` + `updatePassword` (`false` ⇒ `PersonNotFound`) → `revokeAllForPersonExcept(personId, sessionId)` → `Success(person)`; sem lançar exceção
- [x] 3.4 Fiar o `UpdatePasswordUseCase` no `main/IdentityFactory.kt` (`@Singleton`, recebendo `PasswordHasherPort`, `PersonRepository` e `SessionRepository` por parâmetro)

## 4. Identity: borda HTTP

- [x] 4.1 Criar `infrastructure/http/requests/UpdatePasswordRequest.kt` (`@Serdeable`) — `currentPassword` com `@NotBlank`; `newPassword` com `@NotBlank` + `@Size(min = PasswordValueObject.MIN_LENGTH)`; mensagens por `{chave}` i18n; `@Schema` com exemplos sãos (sem vazar senha real)
- [x] 4.2 Criar o request-mapper (`infrastructure/http/mappers/requests/`) que monta o `UpdatePasswordCommand` a partir do `personId` e do `sessionId` do ator e do `currentPassword`/`newPassword` do corpo
- [x] 4.3 Criar `infrastructure/http/mappers/errors/UpdatePasswordErrorResponseMapper.kt` — `WeakPassword` ⇒ `unprocessable("WEAK_PASSWORD", …)`; `SamePassword` ⇒ `unprocessable("SAME_PASSWORD", …)`; `InvalidCredentials` **e** `PersonNotFound` ⇒ o mesmo `unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))`
- [x] 4.4 Adicionar o método `PATCH /me/password` em `PersonController.kt` — `@Authenticated`, injeta `AuthenticatedActor` e `@Valid @Body UpdatePasswordRequest`, ramifica sobre `UpdatePasswordResult` (Success ⇒ `200` com `PersonResponse`; Failure ⇒ `toResponse(messages)`)
- [x] 4.5 Atualizar `controllers/docs/PersonControllerDoc.kt` — documentar `PATCH /me/password` (`@Operation`/`@ApiResponse` `200 → PersonResponse`, `400/422/401/500 → ErrorResponse`, `@Status(HttpStatus.OK)`, `@SecurityRequirement`), descrevendo o step-up e a revogação das demais sessões
- [x] 4.6 Adicionar as chaves i18n do novo request/erro em `src/main/resources/i18n/messages.properties` (senha atual em branco, nova senha em branco/curta, senha fraca de domínio, senha igual à atual)

## 5. Testes

- [x] 5.1 Testes de unidade do `UpdatePasswordUseCase` — sucesso (só o hash muda **e** as outras sessões são revogadas, a atual poupada); `WeakPassword` (nada persistido, nada revogado); `InvalidCredentials` (senha atual errada, nada persistido/revogado); `SamePassword` (nova == atual, nada persistido/revogado); `PersonNotFound` (pessoa não-ativa no `findById` e corrida no write) — usando `FakePersonRepository`/`FakeSessionRepository`/fixtures em `factories/` (fake de repositório estendido com `updatePassword`, fake de sessão com `revokeAllForPersonExcept`)
- [x] 5.2 Teste end-to-end de `PATCH /persons/me/password` (via `HttpClient` em `/v1/persons/me/password`): `200` autenticado com senhas válidas (e as outras sessões deixam de resolver, a atual continua); `400` campo ausente/nova senha curta; `422` senha fraca e senha igual à atual (corpos específicos); `401` sem sessão viva, senha atual incorreta e sessão órfã (indistinguíveis)
- [x] 5.3 Atualizar os testes de `AuthenticatedFilter`/binder (e quaisquer fixtures que construam `AuthenticatedActor`) para o novo campo `sessionId`

## 6. Docs e reconciliação

- [x] 6.1 Atualizar `features/identity/README.md` documentando, em linguagem de negócio, a regra "trocar a própria senha": exige sessão viva **e** a confirmação da senha atual; altera só a senha (nome/e-mail/status intocados); a nova senha cumpre a política mínima (regra pública) e deve ser diferente da atual; ao trocar, as demais sessões são encerradas e a atual permanece; a recusa por senha incorreta é indistinguível de uma sessão ausente
- [x] 6.2 Atualizar o `CLAUDE.md` na linha do `AuthenticatedActor` ("carries only the personId" → "carries the personId + the current sessionId")
- [x] 6.3 `./gradlew build` verde (Konsist incluído: sem literal duplicado, camadas respeitadas)
- [x] 6.4 Reconciliar specs (`/opsx:sync`) e arquivar a change (`/opsx:archive`)
