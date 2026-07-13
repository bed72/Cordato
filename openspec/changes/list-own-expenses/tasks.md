## 1. Persistência — consulta por pessoa

- [x] 1.1 Adicionar `toEntity` (record `EXPENSE` → `ExpenseEntity`) ao `ExpenseRecordMapper` existente (`internal`, par do `toRecord` já presente), reconstruindo `MoneyValueObject`/`ExpenseDateValueObject`/`DescriptionValueObject` a partir das colunas.
- [x] 1.2 Adicionar `findByPerson(personId: String): List<ExpenseEntity>` ao port `ExpenseRepository` (devolve `List`, vazio quando não há gastos — nunca `null`).
- [x] 1.3 Implementar `findByPerson` no `PersistenceExpenseRepository`: `selectFrom(EXPENSE).where(PERSON_ID.eq(personId)).orderBy(SPENT_ON.desc(), ID.desc()).fetch { it.toEntity() }`. Sem migração nova (reusa a `V3`).

## 2. Aplicação do expense

- [x] 2.1 Criar `features/expense/application/driving/commands/ListExpensesCommand.kt` (`personId: String`).
- [x] 2.2 Criar `features/expense/application/driving/use_cases/ListExpensesUseCase.kt`: `invoke(command): List<ExpenseEntity>` delegando a `repository.findByPerson(command.personId)` — sem `Result`/`Error` selado (não há ramo de falha).
- [x] 2.3 Testes do use case com o `FakeExpenseRepository`: retorna só os gastos do `personId` do command; lista vazia quando não há gastos; a ordem determinística vem do repositório (o fake devolve o que lhe deram) — asserir o recorte por dono e o pass-through.

## 3. Slice HTTP do expense

- [x] 3.1 Adicionar o mapper `List<ExpenseEntity>.toResponse(): List<ExpenseResponse>` em `infrastructure/http/mappers/responses/` (sobre o `ExpenseEntity.toResponse()` já existente).
- [x] 3.2 Adicionar o método `list` ao `ExpenseControllerDoc`: `@Operation`/`@Tag`, `@ApiResponse` `200` com corpo `@Content(array = @ArraySchema(schema = @Schema(implementation = ExpenseResponse::class)))`, `401`/`500` → `ErrorResponse`.
- [x] 3.3 Adicionar `list(actor: AuthenticatedActor): HttpResponse<*>` ao `ExpenseController`: `@Get` `@Authenticated` `@Status(HttpStatus.OK)`, injetar `ListExpensesUseCase` no construtor, retornar `HttpResponse.ok(useCase(ListExpensesCommand(actor.personId)).toResponse())` — sem ramo de erro.

## 4. DI

- [x] 4.1 Adicionar `@Singleton listExpensesUseCase(repository: ExpenseRepository): ListExpensesUseCase` ao `ExpenseFactory` (herda o repositório já ligado; nenhum port novo do kernel).

## 5. Testes de integração e fechamento

- [x] 5.1 Teste end-to-end HTTP de `GET /v1/expenses`: `200` com o array dos gastos do ator autenticado, ordenado por data desc; `200` com array vazio quando o ator não tem gastos; recorte por dono (gastos de outra pessoa não vazam); `401` sem sessão (usando a harness Postgres e os fixtures de auth).
- [x] 5.2 Rodar `arch-review` sobre o diff (camadas/naming/HTTP) e corrigir desvios estruturais.
- [x] 5.3 `./gradlew build` e `./gradlew test` verdes.
- [x] 5.4 Atualizar o `README.md` do contexto `expense` se necessário e reconciliar specs (`/opsx:sync`) antes de arquivar.
