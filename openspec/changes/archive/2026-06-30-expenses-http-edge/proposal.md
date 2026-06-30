## Why

The expenses domain and application layers are complete, but zero expense operations are reachable over the
network. Without an HTTP edge, a client cannot record, list, edit, or delete expenses — the individual
financial view is effectively empty. This change brings the four core CRUD operations into the HTTP adapter,
completing the day-to-day individual flow: create budget → record expense → list expenses.

## What Changes

- Expose `POST /v1/expenses` — record a new expense, responding `201 Created` with the created expense.
- Expose `GET /v1/expenses` — list the acting person's live expenses, most-recent-first, responding `200 OK`.
- Expose `PATCH /v1/expenses/{expense_id}` — update an owned expense (full replacement of editable fields),
  responding `200 OK` with the updated expense.
- Expose `DELETE /v1/expenses/{expense_id}` — soft-delete an owned expense, responding `204 No Content`.
- Wire a new `ExpenseController` into the composition root, scoped to its own `Router` with its own DI
  providers — mirroring the budgeting pattern exactly.
- Add the expenses error→status table (`EXPENSES_STATUS_ERROR`) covering `ExpenseNotFoundError`,
  `InvalidAmountError`, `InvalidMoneyError`.
- Write HTTP integration tests and a Locust stress scenario for the new endpoints.

## Capabilities

### New Capabilities

_(none — the four operations are already captured by existing specs; this change adds HTTP requirements to each)_

### Modified Capabilities

- `record-expense`: add HTTP requirement — `POST /v1/expenses`, `201 Created`, unified error envelope.
- `list-expenses`: add HTTP requirement — `GET /v1/expenses`, `200 OK`, ordered most-recent-first.
- `update-expense`: add HTTP requirement — `PATCH /v1/expenses/{expense_id}`, `200 OK`, unified error envelope.
- `delete-expense`: add HTTP requirement — `DELETE /v1/expenses/{expense_id}`, `204 No Content`, unified error envelope.

## Impact

- **New files** under `features/expenses/infrastructure/http/`: controller, requests, responses, mappers,
  errors/lookups.
- **New file** under `features/expenses/main/`: `expenses_provider.py` (Router builder, DI wiring).
- **`core/infrastructure/http/app.py`**: one `register_expenses()` call added — no other change.
- **`tests/expenses/integrations/http/`**: new HTTP integration test file.
- **`tests/stress/`**: new Locust scenario file.
- No change to `domain/` or `application/` — the use cases, ports, and in-memory repositories are untouched.
- No new runtime dependencies.
