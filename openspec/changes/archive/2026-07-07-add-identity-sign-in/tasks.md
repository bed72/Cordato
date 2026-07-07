## 1. Fundação de sessão no `core`

- [x] 1.1 Criar `core/domain/entities/SessionEntity.kt` (id, personId, `hashToken`, `expiresAt`, `createdAt`) — `data class` pura, sem framework.
- [x] 1.2 Criar `core/application/ports/TokenizerPort.kt` — `generate(): String` (token opaco em claro) e `hash(token: String): String` (SHA-256 a persistir).
- [x] 1.3 Criar `core/application/repositories/SessionRepository.kt` — `open(session): Boolean`/`save` e `findActiveByToken(token, now): SessionEntity?` (só sessão viva; ausência sem exceção).
- [x] 1.4 Criar `core/infrastructure/adapters/TokenizerAdapter.kt` — `SecureRandom` → base64url (sem padding) para `generate`; `MessageDigest` SHA-256 para `hash`. JDK puro.
- [x] 1.5 Criar migração Flyway da tabela `sessions` (`hash_token` único, `person_id`, `expires_at`, `created_at`), espelhando o padrão de `identity-persistence`.
- [x] 1.6 Criar `core/infrastructure/repositories/PersistenceSessionRepository.kt` (jOOQ) + `mappers/SessionRecordMapper.kt` (setters de record, extension `toRecord`/`toEntity`).
- [x] 1.7 Adicionar o builder `unauthorized(code, message)` em `core/infrastructure/http/responses/ErrorResponses.kt` — `401` escalar, sem `WWW-Authenticate` (remover/atualizar o comentário que o antecipa).
- [x] 1.8 Fiar em `core/main/CoreFactory.kt` os singletons `TokenizerPort` e `SessionRepository` (recebendo `DSLContext`).

## 2. Domínio e aplicação de `identity`

- [x] 2.1 Criar `identity/domain/errors/SignInError.kt` — `sealed`, único `data object InvalidCredentials`.
- [x] 2.2 Criar `identity/application/commands/SignInCommand.kt` (`email`, `password`).
- [x] 2.3 Criar `identity/application/results/SignInResult.kt` — `sealed interface` com `Success(session: SessionEntity, token: String)` e `Failure(error: SignInError)`.
- [x] 2.4 Estender `identity/application/ports/PasswordHasherPort.kt` com `verify(password, hash): Boolean`.
- [x] 2.5 Estender `identity/application/repositories/PersonRepository.kt` com `findByEmail(email): PersonEntity?` (apenas pessoas ativas).
- [x] 2.6 Criar `identity/application/use_cases/SignInUseCase.kt` — `findByEmail` → **sempre** `verify` (hash real ou dummy fixo timing-constant) → em sucesso `tokenizer.generate` + `SessionRepository.open` (expiração via `Clock.now()+TTL`) → `Success(session, token)`; qualquer recusa colapsa em `Failure(InvalidCredentials)`.

## 3. Adapters de `identity`

- [x] 3.1 Implementar `PasswordHasherAdapter.verify` (bcrypt at.favre, mesma configuração do hash).
- [x] 3.2 Implementar `PersonRepository.findByEmail` em `PersistencePersonRepository` (filtro `status = ACTIVE`, retorna `null` para inexistente ou não-ativa).

## 4. Fatia HTTP de `identity` (sem OpenAPI doc)

- [x] 4.1 Criar `identity/infrastructure/http/requests/SignInRequest.kt` — `@Serdeable`, `@NotBlank` em `email`/`password` (presença apenas; nunca `@Size`/`@Pattern`), `message` por chave i18n.
- [x] 4.2 Criar `identity/infrastructure/http/responses/SignInResponse.kt` — `@Serdeable` `{ token, expiresAt }`.
- [x] 4.3 Criar `identity/infrastructure/http/mappers/requests/SignInRequestMapper.kt` (request → `SignInCommand`).
- [x] 4.4 Criar `identity/infrastructure/http/mappers/responses/SignInResponseMapper.kt` (`SignInResult.Success` → `SignInResponse`, token em claro + `expiresAt`).
- [x] 4.5 Criar `identity/infrastructure/http/mappers/errors/SignInErrorResponseMapper.kt` — `InvalidCredentials → unauthorized("UNAUTHENTICATED", <i18n>)` (`401`).
- [x] 4.6 Adicionar a rota `POST /sign-in` no controller de `identity` (`@Post`/`@Body`/`@Valid`), delegando ao `SignInUseCase` e ramificando o `SignInResult` (sucesso → `200` com body; falha → mapper de erro). Sem tocar no `<Controller>Doc` (follow-up).

## 5. Fiação e i18n

- [x] 5.1 Fiar em `identity/main/IdentityFactory.kt` o `SignInUseCase` (recebendo `PasswordHasherPort`, `PersonRepository`, `SessionRepository`, `TokenizerPort`, `ClockPort`).
- [x] 5.2 Adicionar as chaves em `src/main/resources/i18n/messages.properties` — mensagens de presença do request (`{signin.request...}`) e a mensagem genérica do `401` (`code` `UNAUTHENTICATED` permanece constante inline, não localizado).

## 6. Verificação de build

- [x] 6.1 `./gradlew build` compila (Konsist de arquitetura passa: domínio/aplicação sem Micronaut; sessão em `core`; identity referenciando core). Testes e OpenAPI/README ficam para o follow-up.
