## 1. Domínio e persistência

- [x] 1.1 Criar `domain/errors/UpdateEmailError.kt` — sealed com `InvalidEmail`, `EmailAlreadyInUse`, `InvalidCredentials`, `PersonNotFound`; documentar o não-vazamento (`EmailAlreadyInUse` sem e-mail/dado; `InvalidCredentials`/`PersonNotFound` neutros indistinguíveis do `401` do guard)
- [x] 1.2 Definir o desfecho de três estados da persistência de e-mail no `application` (ex. `enum UpdateEmailOutcome { UPDATED, EMAIL_TAKEN, PERSON_INACTIVE }`), puro e sem dependência de framework
- [x] 1.3 Estender `application/repositories/PersonRepository.kt` com `updateEmail(id, email): UpdateEmailOutcome` — atualiza **apenas** o e-mail da pessoa **ativa**, autoritativo na unicidade (colisão ⇒ `EMAIL_TAKEN`; zero linhas ⇒ `PERSON_INACTIVE`; sucesso ⇒ `UPDATED`), documentando que só o e-mail muda
- [x] 1.4 Implementar `updateEmail` em `infrastructure/repositories/PersistencePersonRepository.kt` como `UPDATE person SET email=? WHERE id=? AND status=ACTIVE`, capturando a violação da restrição de unicidade ⇒ `EMAIL_TAKEN`, via `PersonRecordMapper`/property setters conforme a convenção de mappers

## 2. Aplicação (use case)

- [x] 2.1 Criar `application/commands/UpdateEmailCommand.kt` (`personId`, `email` cru, `password` cru)
- [x] 2.2 Criar `application/results/UpdateEmailResult.kt` — sealed: `Success(person)` com a visão pública atualizada e `Failure(error: UpdateEmailError)`
- [x] 2.3 Criar `application/use_cases/UpdateEmailUseCase.kt` (recebe `PasswordHasherPort` + `PersonRepository`) — ordem: `EmailValueObject.of` (rejeição ⇒ `InvalidEmail`) → `findById` (ausente ⇒ `PersonNotFound`) → `hasher.verify` (falha ⇒ `InvalidCredentials`) → e-mail normalizado == atual ⇒ `Success` no-op → `updateEmail` ramifica o desfecho (`UPDATED` ⇒ `Success(copy(email=…))`; `EMAIL_TAKEN` ⇒ `EmailAlreadyInUse`; `PERSON_INACTIVE` ⇒ `PersonNotFound`); sem lançar exceção
- [x] 2.4 Fiar o `UpdateEmailUseCase` no `main/IdentityFactory.kt` (`@Singleton`, recebendo `PasswordHasherPort` e `PersonRepository` por parâmetro)

## 3. Borda HTTP

- [x] 3.1 Criar `infrastructure/http/requests/UpdateEmailRequest.kt` (`@Serdeable`), `email` com `@NotBlank` + `@Pattern(regexp = EmailValueObject.PATTERN)` e `password` com `@NotBlank`, mensagens por `{chave}` i18n; `@Schema` com exemplos sãos nos campos
- [x] 3.2 Criar o request-mapper (`infrastructure/http/mappers/requests/`) que monta o `UpdateEmailCommand` a partir do `personId` do ator e do `email`/`password` do corpo
- [x] 3.3 Criar `infrastructure/http/mappers/errors/UpdateEmailErrorResponseMapper.kt` — `InvalidEmail` ⇒ `unprocessable("INVALID_EMAIL", …)`; `EmailAlreadyInUse` ⇒ `unprocessable("EMAIL_UPDATE_REJECTED", …)` genérico e escalar; `InvalidCredentials` **e** `PersonNotFound` ⇒ o mesmo `unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))`
- [x] 3.4 Adicionar o método `PATCH /me/email` em `PersonController.kt` — `@Authenticated`, injeta `AuthenticatedActor` e `@Valid @Body UpdateEmailRequest`, ramifica sobre `UpdateEmailResult` (Success ⇒ `200` com `PersonResponse`; Failure ⇒ `toResponse(messages)`)
- [x] 3.5 Mover a rota de troca de nome de `@Patch("/me")` para `@Patch("/me/name")` no `PersonController.kt` (comportamento inalterado, só o path)
- [x] 3.6 Atualizar `controllers/docs/PersonControllerDoc.kt` — documentar `PATCH /me/email` (`@Operation`/`@ApiResponse` `200 → PersonResponse`, `400/422/401 → ErrorResponse`, `@Status(HttpStatus.OK)`) e ajustar o path documentado da troca de nome para `/me/name`
- [x] 3.7 Adicionar as chaves i18n do novo request/erro em `src/main/resources/i18n/messages.properties` (e-mail em branco/formato inválido, senha em branco, e-mail inválido de domínio, e-mail já em uso genérico)

## 4. Testes

- [x] 4.1 Testes de unidade do `UpdateEmailUseCase` — sucesso (só o e-mail muda); `InvalidEmail` (nada persistido); `InvalidCredentials` (senha errada, nada persistido); `PersonNotFound` (pessoa não-ativa e corrida no write); `EmailAlreadyInUse` (colisão com outra pessoa); no-op ao trocar para o próprio e-mail atual — usando o `FakePersonRepository`/fixtures em `factories/` (estendendo o fake com o desfecho de três estados e um hasher fake)
- [x] 4.2 Teste end-to-end de `PATCH /persons/me/email` (via `HttpClient` em `/v1/persons/me/email`): `200` autenticado com e-mail+senha válidos; `400` campo ausente/e-mail malformado; `422` e-mail rejeitado pelo domínio e e-mail já em uso (corpos genéricos, sem `field`); `401` sem sessão viva, senha incorreta e sessão órfã (indistinguíveis)
- [x] 4.3 Atualizar o teste e2e da troca de nome para o novo path `/v1/persons/me/name`

## 5. Docs e reconciliação

- [x] 5.1 Atualizar `features/identity/README.md` documentando, em linguagem de negócio, a regra "trocar o próprio e-mail": exige sessão viva **e** confirmação da senha atual; altera só o e-mail (nome/senha/status intocados); e-mail único (não pode ser o de outra pessoa); a recusa nunca revela se o e-mail já está cadastrado nem qual fator falhou
- [x] 5.2 `./gradlew build` verde (Konsist incluído: sem literal duplicado, camadas respeitadas)
- [x] 5.3 Reconciliar specs (`/opsx:sync`) e arquivar a change (`/opsx:archive`)
