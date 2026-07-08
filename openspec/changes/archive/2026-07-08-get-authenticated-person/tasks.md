## 1. Persistência — consulta por id ativo

- [x] 1.1 Adicionar `findById(id: String): PersonEntity?` ao port `PersonRepository`, com KDoc espelhando a neutralidade de `findByEmail` (colapsa inexistente e não-ativa em `null`).
- [x] 1.2 Implementar `findById` em `PersistencePersonRepository` (jOOQ: `PERSON.ID.eq(id).and(PERSON.STATUS.eq(ACTIVE.name))`, `.fetchOne()?.toEntity()`).
- [x] 1.3 Implementar `findById` no fake de teste `FakePersonRepository` (em `factories/`), respeitando o filtro de status ativo.

## 2. Aplicação — operação `Me`

- [x] 2.1 Criar `MeCommand(personId: String)` em `identity/application/commands/`.
- [x] 2.2 Criar `MeError` (`sealed`) em `identity/domain/errors/` com o caso único `PersonNotFound`.
- [x] 2.3 Criar `MeResult` (`sealed`) em `identity/application/results/` com `Success(person: PersonEntity)` e `Failure(error: MeError)`.
- [x] 2.4 Criar `MeUseCase` em `identity/application/use_cases/`: `invoke(MeCommand) -> MeResult` via `repository.findById`, mapeando ausência para `Failure(PersonNotFound)`.

## 3. Borda HTTP — rota protegida `GET /persons/me`

- [x] 3.1 Criar `PersonControllerDoc` em `identity/infrastructure/http/controllers/docs/`: `@Tag`, `@Operation`, `@ApiResponse` (200→`PersonResponse`, 401/500→`ErrorResponse`), `@SecurityRequirement(name = "bearerAuth")`; método `me(actor): HttpResponse<*>`.
- [x] 3.2 Criar `PersonController` (`@Controller("/persons")`) implementando `PersonControllerDoc`: `@Get("/me")` + `@Authenticated` no método, injeta `MessagePort` + `MeUseCase`, recebe `AuthenticatedActor`, ramifica sobre `MeResult`.
- [x] 3.3 Criar `MeErrorResponseMapper` em `identity/infrastructure/http/mappers/errors/` (`internal fun MeError.toResponse(messages)`): `PersonNotFound -> unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))`.
- [x] 3.4 Confirmar reuso de `PersonResponse` + `PersonEntity.toResponse()` (sem novo DTO/mapper de resposta).

## 4. OpenAPI — security scheme Bearer

- [x] 4.1 Declarar `@SecurityScheme(name = "bearerAuth", type = HTTP, scheme = "bearer")` no `OpenApiDefinition` do core (junto do metadado global).
- [x] 4.2 Verificar que a operação `me` referencia o esquema e que sign-up/sign-in permanecem sem `@SecurityRequirement`.

## 5. Wiring (DI)

- [x] 5.1 Adicionar `@Singleton fun meUseCase(repository: PersonRepository): MeUseCase` ao `IdentityFactory`.

## 6. Testes

- [x] 6.1 Teste unitário de `MeUseCase` (fake repo): pessoa ativa → `Success` com a pessoa; ausência/não-ativa → `Failure(PersonNotFound)`.
- [x] 6.2 Teste unitário/de repositório do `findById` cobrindo os três cenários (ativa, inexistente, não-ativa).
- [x] 6.3 Teste HTTP ponta-a-ponta (`@MicronautTest`) de `GET /persons/me`: Bearer vivo (fake session + fake person) → `200` com id/nome/e-mail e sem material de senha.
- [x] 6.4 Teste HTTP: sem token / token inválido → `401` neutro (`UNAUTHENTICATED`) pelo guard, use case não invocado.
- [x] 6.5 Teste HTTP: sessão viva porém pessoa não-ativa (órfã) → `401` neutro, indistinguível do caso 6.4 no corpo e no status.

## 7. Verificação

- [x] 7.1 `./gradlew test` verde (inclui a Konsist architecture test — domínio/aplicação sem imports de framework).
- [x] 7.2 `./gradlew build` e conferência do documento OpenAPI: `GET /persons/me` com cadeado; sign-up/sign-in abertos.
