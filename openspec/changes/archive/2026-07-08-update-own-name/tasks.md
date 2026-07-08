## 1. Domínio e persistência

- [x] 1.1 Criar `domain/errors/UpdateNameError.kt` — sealed com `InvalidName` e `PersonNotFound` (espelha `MeError`; `PersonNotFound` reusa a mesma semântica neutra)
- [x] 1.2 Estender `application/repositories/PersonRepository.kt` com uma operação estreita de atualização de nome da pessoa **ativa** (persistir a `PersonEntity` já com o novo nome, ou atualizar só a coluna do nome por id), documentando que só o nome muda e que zero linhas afetadas ⇒ ausente (pessoa não-ativa)
- [x] 1.3 Implementar a nova operação em `infrastructure/repositories/PersistencePersonRepository.kt` como um `UPDATE` só da coluna do nome, condicionado ao status **ativa** no `WHERE`, via `PersonRecordMapper`/property setters

## 2. Aplicação (use case)

- [x] 2.1 Criar `application/commands/UpdateNameCommand.kt` (`personId`, `name` cru)
- [x] 2.2 Criar `application/results/UpdateNameResult.kt` — sealed: `Success(person)` com a visão pública atualizada e `Failure(error: UpdateNameError)`
- [x] 2.3 Criar `application/use_cases/UpdateNameUseCase.kt` — constrói o `NameValueObject` (rejeição ⇒ `InvalidName`), resolve a pessoa ativa (`findById`; ausente ⇒ `PersonNotFound`), aplica `copy(name = ...)` e persiste; retorna o resultado sealed sem lançar exceção
- [x] 2.4 Fiar o `UpdateNameUseCase` no `main/IdentityFactory.kt` (`@Singleton`, recebendo `PersonRepository` por parâmetro)

## 3. Borda HTTP

- [x] 3.1 Criar `infrastructure/http/requests/UpdateNameRequest.kt` (`@Serdeable`), `name` com `@NotBlank` + `@Size(max = NameValueObject.MAX_LENGTH)`, mensagens por `{chave}` i18n; `@Schema` com exemplo sã no campo
- [x] 3.2 Criar o mapper de request (`infrastructure/http/mappers/requests/`) que monta o `UpdateNameCommand` a partir do `personId` do ator e do `name` do corpo
- [x] 3.3 Criar `infrastructure/http/mappers/errors/UpdateNameErrorResponseMapper.kt` — `InvalidName` ⇒ `unprocessable` (code `INVALID_NAME`, mensagem i18n); `PersonNotFound` ⇒ o mesmo `401` neutro (`UNAUTHENTICATED`, `error.authentication.message`) que `MeErrorResponseMapper`
- [x] 3.4 Adicionar o método `PATCH /me` em `PersonController.kt` — `@Authenticated`, injeta `AuthenticatedActor` e `@Valid @Body UpdateNameRequest`, ramifica sobre `UpdateNameResult` (Success ⇒ `200` com `PersonResponse`; Failure ⇒ `toResponse(messages)`)
- [x] 3.5 Documentar a rota em `controllers/docs/PersonControllerDoc.kt` — `@Operation`/`@ApiResponse` (`200 → PersonResponse`, `400/422/401 → ErrorResponse`), `@Status(HttpStatus.OK)` no método
- [x] 3.6 Adicionar as chaves i18n do novo request/erro em `src/main/resources/i18n/messages.properties` (nome em branco, nome acima do máximo, nome inválido de domínio)

## 4. Testes

- [x] 4.1 Testes de unidade do `UpdateNameUseCase` — sucesso (só o nome muda), `InvalidName` (nome persistido inalterado), `PersonNotFound` (pessoa não-ativa), usando o `FakePersonRepository`/fixtures em `factories/`
- [x] 4.2 Teste end-to-end de `PATCH /persons/me` (via `HttpClient` em `/v1/persons/me`): `200` autenticado com nome válido; `400` nome ausente/vazio/acima do máximo; `422` nome rejeitado pelo domínio; `401` sem sessão viva e para sessão órfã (indistinguíveis)

## 5. Docs e reconciliação

- [x] 5.1 Atualizar `features/identity/README.md` documentando, em linguagem de negócio, a regra "editar o próprio nome" (só o nome; e-mail/senha/status intocados; exige sessão viva)
- [x] 5.2 `./gradlew build` verde (Konsist incluído: sem literal duplicado, camadas respeitadas)
- [x] 5.3 Reconciliar specs (`/opsx:sync`) e arquivar a change (`/opsx:archive`)
