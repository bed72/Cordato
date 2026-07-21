## 1. Persistência — esquema e jOOQ

- [x] 1.1 Criar `src/main/resources/db/migration/V4__budget.sql`: tabela `budget(id, person_id, amount_cents bigint, start_date date, end_date date, note varchar null, status varchar not null)`, sem coluna de gasto; índice por `(person_id, status)` para a consulta de sobreposição.
- [x] 1.2 Rodar `./gradlew jooqCodegen` (ou build) e verificar que `Tables.BUDGET` é gerado.

## 2. Domínio do budget

- [x] 2.1 Criar `features/budget/domain/value_objects/BudgetPeriodValueObject.kt` (`startDate`/`endDate: LocalDate`, `of(startDate, endDate)` retorna `null` quando `endDate < startDate`).
- [x] 2.2 Criar `features/budget/domain/value_objects/NoteValueObject.kt` com `const MAX_LENGTH = 255`, `of(raw)` faz trim e valida `length <= MAX_LENGTH`.
- [x] 2.3 Criar `features/budget/domain/enums/BudgetStatusEnum.kt` (`LIVE`, `DELETED`).
- [x] 2.4 Criar `features/budget/domain/entities/BudgetEntity.kt` (`id`, `personId`, `amount: MoneyValueObject`, `period: BudgetPeriodValueObject`, `note: NoteValueObject?`, `status: BudgetStatusEnum`) — sem referência a gastos.
- [x] 2.5 Criar `features/budget/domain/errors/CreateBudgetError.kt` (`sealed interface`: `InvalidAmount`, `InvalidPeriod`, `InvalidNote`, `OverlappingBudget`).
- [x] 2.6 Testes de domínio para os value objects (período, anotação) e para a construção da entidade.

## 3. Aplicação do budget

- [x] 3.1 Criar `features/budget/application/driving/commands/CreateBudgetCommand.kt` (`personId`, `amountInCents: Long`, `startDate: LocalDate`, `endDate: LocalDate`, `note: String?`).
- [x] 3.2 Criar `features/budget/application/driving/results/CreateBudgetResult.kt` (`sealed interface`: `Success(budget)`, `Failure(error)`).
- [x] 3.3 Criar `features/budget/application/driven/repositories/BudgetRepository.kt` (port com `hasOverlappingLiveBudget(personId, startDate, endDate): Boolean` e `create(budget: BudgetEntity)`).
- [x] 3.4 Criar `features/budget/application/driving/use_cases/CreateBudgetUseCase.kt`: valida valor → período → anotação (blank→ausente) → checa sobreposição via repositório → constrói entidade com `IdGeneratorPort` e status `LIVE` → persiste.
- [x] 3.5 Testes do use case (sucesso; `InvalidAmount`; `InvalidPeriod`; `InvalidNote`; `OverlappingBudget`; anotação blank→ausente; dono vem do command, não do corpo; orçamento removido não conta para sobreposição) com fakes segundo as convenções de teste.

## 4. Slice HTTP do budget

- [x] 4.1 Criar `features/budget/infrastructure/http/requests/CreateBudgetRequest.kt` (`@Serdeable`, `@Schema`; `amountInCents` com constraint de edge, `startDate`/`endDate: LocalDate` obrigatórios, `note` com `@Size(max = NoteValueObject.MAX_LENGTH)`).
- [x] 4.2 Criar `features/budget/infrastructure/http/responses/BudgetResponse.kt` (`@Serdeable`, `@Schema`; `id`, `amountInCents`, `startDate`, `endDate`, `note?`).
- [x] 4.3 Criar os mappers HTTP: `mappers/requests/` (`toCommand(personId)`), `mappers/responses/` (`toResponse()`), `mappers/errors/` (`CreateBudgetError.toResponse(messages)` → `422` via `unprocessable` do core).
- [x] 4.4 Criar `features/budget/infrastructure/http/controllers/docs/BudgetControllerDoc.kt` (`@Operation`/`@ApiResponse` 201→`BudgetResponse`, 400/401/422/500→`ErrorResponse`/`@Tag`).
- [x] 4.5 Criar `features/budget/infrastructure/http/controllers/BudgetController.kt` (`@Controller("/budgets")`, `@Post` `@Authenticated` `@Status(CREATED)`, lê `AuthenticatedActor`, ramifica o resultado selado) implementando o Doc.
- [x] 4.6 Adicionar as chaves i18n do budget em `src/main/resources/i18n/messages.properties` (mensagens de edge + de domínio 422, incluindo sobreposição).

## 5. Persistência (adapter) e DI

- [x] 5.1 Criar `features/budget/infrastructure/repositories/mappers/BudgetRecordMapper.kt` (`toRecord`/`toEntity`, `internal`).
- [x] 5.2 Criar `features/budget/infrastructure/repositories/PersistenceBudgetRepository.kt` (adapter jOOQ sobre `DSLContext`: `hasOverlappingLiveBudget` via `EXISTS` com comparação inclusiva de fronteira filtrando por `status = LIVE`; `create` insere na `BUDGET`).
- [x] 5.3 Criar `features/budget/main/BudgetFactory.kt` (`@Factory`): `budgetRepository(dslContext)` e `createBudgetUseCase(generator, repository)`, herdando o kernel do `CoreFactory`.

## 6. Testes de integração e fechamento

- [x] 6.1 Teste end-to-end HTTP de `POST /v1/budgets`: 201 autenticado; 401 sem sessão; 400 edge; 422 valor/intervalo/anotação inválidos; 422 sobreposição de fronteira; 201 para intervalos adjacentes (sem sobreposição) — usando a harness Postgres e os fixtures de auth.
- [x] 6.2 Rodar `arch-review` sobre o diff (camadas/naming/HTTP) e corrigir desvios estruturais.
- [x] 6.3 `./gradlew build` e `./gradlew test` verdes.
- [x] 6.4 Atualizar o `README.md` do contexto budget se necessário e reconciliar specs (`/opsx:sync`) antes de arquivar.
