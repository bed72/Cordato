## 1. SpendReader Gateway

- [x] 1.1 Create `features/budgeting/infrastructure/gateways/spend_reader.py` → `SpendReader(SpendReaderInterface)` que recebe `ExpenseRepositoryInterface` no construtor e implementa `total_spent` somando `expense.amount.value` para todos os expenses retornados por `find_in_range(person_id, start, end)`

## 2. Response DTOs e Mappers

- [x] 2.1 Extend `features/budgeting/infrastructure/http/responses/budget_response.py` (já existente) — verificar se os campos `id`, `person_id`, `amount`, `start_date`, `end_date`, `note`, `created_at` com `Field(description=, examples=)` já estão completos; ajustar se faltar qualquer campo ou anotação
- [ ] 2.2 Create `features/budgeting/infrastructure/http/responses/active_budget_response.py` → `ActiveBudgetResponse` (Pydantic v2: todos os campos de `BudgetResponse` mais `total_spent: Decimal` e `remaining: Decimal`, com `Field(description=, examples=)`)
- [ ] 2.3 Create `features/budgeting/infrastructure/http/mappers/responses/active_budget_response_mapper.py` → `ActiveBudgetResponseMapper.to_response(ActiveBudgetData) -> ActiveBudgetResponse` (`@staticmethod`)

## 3. Request DTO e Mapper para Update

- [ ] 3.1 Create `features/budgeting/infrastructure/http/requests/update_budget_request.py` → `UpdateBudgetRequest` (Pydantic v2: `amount: Decimal`, `start_date: date`, `end_date: date`, `note: str | None`, com `Field(description=, examples=)` e model-level example)
- [ ] 3.2 Create `features/budgeting/infrastructure/http/mappers/requests/update_budget_request_mapper.py` → `UpdateBudgetRequestMapper.to_data(request, person_id, budget_id) -> UpdateBudgetData` (`@staticmethod`)

## 4. Controller — quatro novos handlers

- [ ] 4.1 Add `list_budgets` method to `BudgetController`: `@get()` → `list[BudgetResponse]`, injeta `list_budgets_use_case` e `current_person_provider`, retorna a lista mapeada via `BudgetResponseMapper`
- [ ] 4.2 Add `active` method to `BudgetController`: `@get("/active")` → `ActiveBudgetResponse`, injeta `get_active_budget_use_case`, `current_person_provider` e `clock: NamedDependency[ClockInterface]`; deriva `today = (await clock.now()).date()`; levanta `BudgetNotFoundError()` quando o use case retorna `None`
- [ ] 4.3 Add `update` method to `BudgetController`: `@patch("/{budget_id:str}")` → `BudgetResponse`, recebe `data: UpdateBudgetRequest` e `budget_id: str`, injeta `update_budget_use_case` e `current_person_provider`
- [ ] 4.4 Add `delete` method to `BudgetController`: `@delete("/{budget_id:str}", status_code=204)` → `None`, recebe `budget_id: str`, injeta `delete_budget_use_case` e `current_person_provider`

## 5. DI Provider — atualizar `budgeting_route.py`

- [ ] 5.1 Update `register_budgeting_router()` to accept `expense_repository: ExpenseRepositoryInterface` as parameter; build `SpendReader(expense_repository)` inside the function; add providers for `list_budgets_use_case`, `get_active_budget_use_case` (injecting `spend_reader`), `update_budget_use_case`, `delete_budget_use_case`

## 6. Composition Root

- [ ] 6.1 Update `core/infrastructure/http/app.py::build()`: extract the `ExpenseRepository` singleton from `register_expenses_router` (or share it via parameter), pass it to `register_budgeting_router(expense_repository=...)` so the `SpendReader` can be wired

## 7. Tests

- [ ] 7.1 Create `tests/budgeting/integrations/http/test_budgets_http.py` — HTTP integration tests cobrindo: `GET /v1/budgets` (lista vazia, lista com budgets, sem auth), `GET /v1/budgets/active` (com budget ativo, sem budget ativo/404, sem auth), `PATCH /v1/budgets/{id}` (sucesso/200, não encontrado/404, sobreposição/409, body inválido/422, sem auth), `DELETE /v1/budgets/{id}` (sucesso/204, não encontrado/404, sem auth)
- [ ] 7.2 Create `tests/budgeting/infrastructure/gateways/test_spend_reader.py` — unit test do `SpendReader`: soma correta, sem expenses retorna zero, expenses fora do range são excluídos
- [ ] 7.3 Create `tests/stress/test_budgets_flow.py` — Locust `HttpUser` scenario com sign-up, create budget, list budgets, active budget, update, delete

## 8. Guard e Verificação

- [ ] 8.1 Run `uv run poe check` — todos os gates passam (format, lint, mypy strict, pytest)
- [ ] 8.2 Run `/trocado:guard` — auditoria de arquitetura passa sem violações
