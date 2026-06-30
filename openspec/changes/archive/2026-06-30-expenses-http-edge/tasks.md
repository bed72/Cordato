## 1. HTTP Response DTO

- [x] 1.1 Create `features/expenses/infrastructure/http/responses/expense_response.py` → `ExpenseResponse` (Pydantic v2, fields: `id`, `person_id`, `amount`, `occurred_on`, `description`, `created_at`, with `Field(description=, examples=)`)
- [x] 1.2 Create `features/expenses/infrastructure/http/mappers/responses/expense_response_mapper.py` → `ExpenseResponseMapper.to_response(ExpenseData) -> ExpenseResponse` (`@staticmethod`)

## 2. Request DTOs and Mappers

- [x] 2.1 Create `features/expenses/infrastructure/http/requests/create_expense_request.py` → `CreateExpenseRequest` (Pydantic v2: `amount: Decimal`, `occurred_on: date`, `description: str | None`)
- [x] 2.2 Create `features/expenses/infrastructure/http/mappers/requests/create_expense_request_mapper.py` → `CreateExpenseRequestMapper.to_data(request, person_id) -> CreateExpenseData` (`@staticmethod`)
- [x] 2.3 Create `features/expenses/infrastructure/http/requests/update_expense_request.py` → `UpdateExpenseRequest` (Pydantic v2: `amount: Decimal`, `occurred_on: date`, `description: str | None`)
- [x] 2.4 Create `features/expenses/infrastructure/http/mappers/requests/update_expense_request_mapper.py` → `UpdateExpenseRequestMapper.to_data(request, person_id, expense_id) -> UpdateExpenseData` (`@staticmethod`)

## 3. Controller

- [x] 3.1 Create `features/expenses/infrastructure/http/controllers/expense_controller.py` → `ExpenseController(Controller)` with `path = "/expenses"`, `tags = ["Expenses"]`, and four methods: `create` (`@post()` → 201), `list_expenses` (`@get()` → 200), `update` (`@patch("/{expense_id:str}")` → 200), `delete` (`@delete("/{expense_id:str}", status_code=204)` → 204 / `None`)

## 4. Error Table

- [x] 4.1 Create `features/expenses/infrastructure/http/errors/lookups/expenses_status_error.py` → `EXPENSES_STATUS_ERROR: dict[type[Exception], int]` mapping `ExpenseNotFoundError → 404`, `InvalidAmountError → 422`, `InvalidMoneyError → 422`

## 5. DI Provider and Router

- [x] 5.1 Create `features/expenses/main/expenses_router.py` → `register_expenses_router() -> Router` que constrói o `ExpenseRepository` como singleton, provides os quatro use cases, registra `EXPENSES_STATUS_ERROR` scoped neste router, e retorna o `Router`.

## 6. Composition Root

- [x] 6.1 Update `core/infrastructure/http/app.py::build()` to call `register_expenses_router()` and add its router to the `/v1` route handlers alongside identity and budgeting

## 7. Tests

- [x] 7.1 Create `tests/expenses/integrations/http/test_expenses_http.py` — 15 HTTP integration tests cobrindo todos os endpoints e cenários de erro
- [x] 7.2 Create `tests/expenses/infrastructure/http/errors/lookups/test_expenses_status_error.py` — unit test da tabela de erros (puro Python, sem HTTP)
- [x] 7.3 Create `tests/stress/test_expenses_flow.py` — Locust `HttpUser` scenario com record, list, update, delete

## 8. Guard and Verification

- [x] 8.1 Run `uv run poe check` — all gates pass (format, lint, mypy strict, pytest)
- [x] 8.2 Run `/trocado:guard` — architecture audit passes with no violations
