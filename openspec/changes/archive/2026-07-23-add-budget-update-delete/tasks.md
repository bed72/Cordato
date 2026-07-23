## 1. Contrato de erro compartilhado (core)

- [x] 1.1 Adicionar `notFound(code: String, message: String): HttpResponse<ErrorsResponse>` em `core/infrastructure/http/responses/ErrorResponse.kt`, irmão de `unauthorized`/`unprocessable`/`internalError` — `404`, escalar, sem `source`.

## 2. Persistência — repositório e migração

- [x] 2.1 Estender `features/budget/application/driven/repositories/BudgetRepository.kt`: adicionar `findById(id: String): BudgetEntity?`, `update(budget: BudgetEntity)`, `delete(id: String, personId: String): Boolean`; adicionar `excludeId: String? = null` a `hasOverlappingLiveBudget`.
- [x] 2.2 Atualizar `features/budget/infrastructure/repositories/PersistenceBudgetRepository.kt`: implementar `findById` (sem filtro de dono/estado), `update` (por `id`), `delete` (`UPDATE ... WHERE id = ? AND person_id = ? AND status = 'LIVE'`, retorna se alguma linha foi afetada); estender a query de `hasOverlappingLiveBudget` com `AND id <> :excludeId` quando informado.
- [x] 2.3 Confirmar que nenhuma migração nova é necessária (a coluna `status` já existe em `V4__budget.sql`); nenhuma alteração de schema nesta fatia.
- [x] 2.4 Testes do repositório (harness Postgres): `findById` encontra/não encontra; `update` altera valor/intervalo/anotação; `delete` remove só quando vivo+dono corretos (três cenários de não-remoção: outro dono, já removido, id inexistente); `hasOverlappingLiveBudget` com `excludeId` não conta o próprio orçamento, e sem `excludeId` mantém o comportamento anterior.

## 3. Domínio e aplicação — edição (`UpdateBudget`)

- [x] 3.1 Criar `features/budget/domain/errors/UpdateBudgetError.kt` (`sealed interface`: `InvalidAmount`, `InvalidPeriod`, `InvalidNote`, `OverlappingBudget`, `BudgetNotFound`).
- [x] 3.2 Criar `features/budget/application/driving/commands/UpdateBudgetCommand.kt` (`budgetId`, `personId`, `amountInCents: Long`, `startDate: LocalDate`, `endDate: LocalDate`, `note: String?`).
- [x] 3.3 Criar `features/budget/application/driving/results/UpdateBudgetResult.kt` (`sealed interface`: `Success(budget)`, `Failure(error)`).
- [x] 3.4 Criar `features/budget/application/driving/use_cases/UpdateBudgetUseCase.kt`: valida valor → período → anotação (mesma ordem/regras de `CreateBudgetUseCase`) → `repository.findById(budgetId)` (nulo, dono diferente, ou não-vivo ⇒ `BudgetNotFound`) → `hasOverlappingLiveBudget(personId, period, excludeId = budgetId)` ⇒ `OverlappingBudget` → constrói entidade atualizada (mesmo id/personId/status) → `repository.update(budget)` → `Success`.
- [x] 3.5 Testes do use case com fakes: sucesso; `InvalidAmount`/`InvalidPeriod`/`InvalidNote`; `BudgetNotFound` (inexistente, de outra pessoa, já removido — mesma variante nos três); `OverlappingBudget` contra outro orçamento vivo; editar sem mudar o intervalo não conflita consigo mesmo; dono nunca muda mesmo que o command tente.

## 4. Domínio e aplicação — remoção (`DeleteBudget`)

- [x] 4.1 Criar `features/budget/domain/errors/DeleteBudgetError.kt` (`sealed interface` com o único caso `BudgetNotFound`, mesmo padrão de `MeError`).
- [x] 4.2 Criar `features/budget/application/driving/commands/DeleteBudgetCommand.kt` (`budgetId`, `personId`).
- [x] 4.3 Criar `features/budget/application/driving/results/DeleteBudgetResult.kt` (`sealed interface`: `Success(budget)`, `Failure(error)` — `Success` carrega o orçamento já removido para a resposta).
- [x] 4.4 Criar `features/budget/application/driving/use_cases/DeleteBudgetUseCase.kt`: `repository.delete(budgetId, personId)` → `false` ⇒ `Failure(BudgetNotFound)`; `true` ⇒ buscar o orçamento atualizado (ou montar a entidade com `status = DELETED` a partir do que se sabe) e retornar `Success`.
- [x] 4.5 Testes do use case com fakes: sucesso (orçamento vivo do dono correto); `BudgetNotFound` para id inexistente, orçamento de outra pessoa, e orçamento já removido.

## 5. Slice HTTP — edição e remoção

- [x] 5.1 Criar `features/budget/infrastructure/http/requests/UpdateBudgetRequest.kt` (`@Serdeable`, `@Schema`; mesmos campos/constraints de `CreateBudgetRequest`).
- [x] 5.2 Criar os mappers HTTP de edição: `mappers/requests/` (`UpdateBudgetRequest.toCommand(budgetId, personId)`), `mappers/errors/` (`UpdateBudgetErrorResponseMapper.kt`: os quatro erros de validação → `422` via `unprocessable`; `BudgetNotFound` → `404` via `notFound`); reaproveitar `BudgetResponseMapper.toResponse()` existente para o corpo de sucesso.
- [x] 5.3 Criar o mapper de erro de remoção: `mappers/errors/DeleteBudgetErrorResponseMapper.kt` (`BudgetNotFound` → `404` via `notFound`).
- [x] 5.4 Adicionar as chaves i18n em `src/main/resources/i18n/messages.properties`: `updateBudget.error.*` (reaproveitando o texto de `createBudget.error.*` onde o significado é idêntico), `updateBudget.error.budgetNotFound`, `deleteBudget.error.budgetNotFound`, e as chaves de request/edge de `UpdateBudgetRequest` se distintas de `createBudget.request.*`.
- [x] 5.5 Estender `features/budget/infrastructure/http/controllers/docs/BudgetControllerDoc.kt`: métodos `update`/`delete` com `@Operation`/`@ApiResponse` (`200` sucesso; `400`/`401`/`404`/`422`/`500` erro).
- [x] 5.6 Estender `features/budget/infrastructure/http/controllers/BudgetController.kt`: `@Patch("/{id}") @Authenticated` chamando `UpdateBudgetUseCase` (lê `id` do path + `AuthenticatedActor.personId`), `@Delete("/{id}") @Authenticated` chamando `DeleteBudgetUseCase`; ambos ramificam o resultado selado retornando `200 OK` com `BudgetResponse` no sucesso.

## 6. DI

- [x] 6.1 Atualizar `features/budget/main/BudgetFactory.kt`: expor `updateBudgetUseCase(repository)` e `deleteBudgetUseCase(repository)` como `@Singleton`, reaproveitando o `BudgetRepository` já existente — nenhuma dependência nova além do que o `CoreFactory` já fornece.

## 7. Testes de integração e fechamento

- [x] 7.1 Teste end-to-end HTTP de `PATCH /v1/budgets/{id}`: `200` autenticado; `401` sem sessão; `400` edge; `422` valor/intervalo/anotação/sobreposição inválidos; `404` para id inexistente, de outra pessoa e já removido.
- [x] 7.2 Teste end-to-end HTTP de `DELETE /v1/budgets/{id}`: `200` autenticado (corpo com estado removido); `401` sem sessão; `404` para id inexistente, de outra pessoa e já removido; orçamento removido deixa de aparecer em `GET /budgets/active` e passa a contar em `GET /budgets/default`; o intervalo liberado permite criar um novo orçamento sobreposto sem erro.
- [x] 7.3 Rodar `arch-review` sobre o diff (camadas/naming/HTTP) e corrigir desvios estruturais.
- [x] 7.4 `./gradlew build` e `./gradlew test` verdes.
- [x] 7.5 Atualizar o `README.md` do contexto `budget` se necessário e reconciliar specs (`/opsx:sync`) antes de arquivar.
