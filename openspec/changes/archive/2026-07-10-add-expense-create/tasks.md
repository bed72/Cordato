## 1. Shared kernel — Money

- [x] 1.1 Criar `core/domain/value_objects/MoneyValueObject.kt`: `@JvmInline value class` sobre `cents: Long`, `of(cents: Long): MoneyValueObject?` retornando `null` quando `cents <= 0`; sem aritmética especulativa.
- [x] 1.2 Teste de `MoneyValueObject` (`of` aceita > 0, rejeita 0 e negativo) em `core` seguindo as convenções de teste.

## 2. Persistência — esquema e jOOQ

- [x] 2.1 Confirmar o estilo de FK em `V1__person.sql`/`V2__session.sql` (há FK cruzada?) para manter consistência.
- [x] 2.2 Criar `src/main/resources/db/migration/V3__expense.sql`: tabela `expense(id, person_id, amount_cents bigint, spent_on date, description text null)`, sem coluna de orçamento; índice por `person_id` (e `spent_on`, ver design).
- [x] 2.3 Rodar `./gradlew jooqCodegen` (ou build) e verificar que `Tables.EXPENSE` é gerado.

## 3. Domínio do expense

- [x] 3.1 Criar `features/expense/domain/value_objects/ExpenseDateValueObject.kt` (envolve `LocalDate`, `of(raw)` valida só data intrínseca — a regra "não-futura" fica no use case).
- [x] 3.2 Criar `features/expense/domain/value_objects/DescriptionValueObject.kt` com `const MAX_LENGTH = 255`, `of(raw)` faz trim e valida `length <= MAX_LENGTH`.
- [x] 3.3 Criar `features/expense/domain/entities/ExpenseEntity.kt` (`id`, `personId`, `amount: MoneyValueObject`, `date: ExpenseDateValueObject`, `description: DescriptionValueObject?`) — sem referência a orçamento.
- [x] 3.4 Criar `features/expense/domain/errors/CreateExpenseError.kt` (`sealed interface`: `InvalidAmount`, `FutureDate`, `InvalidDescription`).
- [x] 3.5 Testes de domínio para os value objects e para a construção da entidade.

## 4. Aplicação do expense

- [x] 4.1 Criar `features/expense/application/driving/commands/CreateExpenseCommand.kt` (`personId`, `amountInCents: Long`, `date: LocalDate?`, `description: String?`).
- [x] 4.2 Criar `features/expense/application/driving/results/CreateExpenseResult.kt` (`sealed interface`: `Success(expense)`, `Failure(error)`).
- [x] 4.3 Criar `features/expense/application/driven/repositories/ExpenseRepository.kt` (port com `create(expense: ExpenseEntity)`).
- [x] 4.4 Criar `features/expense/application/driving/use_cases/CreateExpenseUseCase.kt`: valida valor → data (default hoje via `ClockPort`, rejeita futuro) → descrição (blank→ausente) → constrói entidade com `IdGeneratorPort` → persiste.
- [x] 4.5 Testes do use case (sucesso; `InvalidAmount`; `FutureDate`; `InvalidDescription`; data ausente→hoje; descrição blank→ausente; dono vem do command, não do corpo) com fakes segundo as convenções de teste.

## 5. Slice HTTP do expense

- [x] 5.1 Criar `features/expense/infrastructure/http/requests/CreateExpenseRequest.kt` (`@Serdeable`, `@Schema`; `amountInCents` com constraint de edge referenciando a regra do money; `description` com `@Size(max = DescriptionValueObject.MAX_LENGTH)`; `date` opcional).
- [x] 5.2 Criar `features/expense/infrastructure/http/responses/ExpenseResponse.kt` (`@Serdeable`, `@Schema`; `id`, `amountInCents`, `date`, `description?`).
- [x] 5.3 Criar os mappers HTTP: `mappers/requests/` (`toCommand(personId)`), `mappers/responses/` (`toResponse()`), `mappers/errors/` (`CreateExpenseError.toResponse(messages)` → `422` via `unprocessable` do core).
- [x] 5.4 Criar `features/expense/infrastructure/http/controllers/docs/ExpenseControllerDoc.kt` (`@Operation`/`@ApiResponse` 201→`ExpenseResponse`, 400/401/422/500→`ErrorResponse`/`@Tag`).
- [x] 5.5 Criar `features/expense/infrastructure/http/controllers/ExpenseController.kt` (`@Controller("/expenses")`, `@Post` `@Authenticated` `@Status(CREATED)`, lê `AuthenticatedActor`, ramifica o resultado selado) implementando o Doc.
- [x] 5.6 Adicionar as chaves i18n do expense em `src/main/resources/i18n/messages.properties` (mensagens de edge + de domínio 422).

## 6. Persistência (adapter) e DI

- [x] 6.1 Criar `features/expense/infrastructure/repositories/mappers/ExpenseRecordMapper.kt` (`toRecord`/`toEntity`, `internal`).
- [x] 6.2 Criar `features/expense/infrastructure/repositories/PersistenceExpenseRepository.kt` (adapter jOOQ sobre `DSLContext`, insere na `EXPENSE`).
- [x] 6.3 Criar `features/expense/main/ExpenseFactory.kt` (`@Factory`): `expenseRepository(dslContext)` e `createExpenseUseCase(clock, generator, repository)`, herdando o kernel do `CoreFactory`.

## 7. Testes de integração e fechamento

- [x] 7.1 Teste end-to-end HTTP de `POST /v1/expenses`: 201 autenticado; 401 sem sessão; 400 edge; 422 data futura/valor inválido (usando a harness Postgres e os fixtures de auth).
- [x] 7.2 Rodar `arch-review` sobre o diff (camadas/naming/HTTP) e corrigir desvios estruturais.
- [x] 7.3 `./gradlew build` e `./gradlew test` verdes.
- [x] 7.4 Atualizar o `README.md` do contexto expense se necessário e reconciliar specs (`/opsx:sync`) antes de arquivar.
