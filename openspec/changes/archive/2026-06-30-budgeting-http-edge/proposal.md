## Why

`POST /v1/budgets` is live, but the remaining four operations — list, active budget, update, and
delete — have no HTTP edge. Without them a client cannot view, manage, or remove budgets, leaving
the feature effectively write-only. This change completes the budgeting HTTP surface by exposing
the four use cases that already exist in the application layer.

## What Changes

- Expose `GET /v1/budgets` — list the acting person's live budgets, most-recent-period-first,
  responding `200 OK`.
- Expose `GET /v1/budgets/active` — return the acting person's active budget for today, enriched
  with `total_spent` and `remaining`, responding `200 OK`; respond `404` with the unified envelope
  when no budget contains today.
- Expose `PATCH /v1/budgets/{budget_id}` — full replacement of editable fields on an owned live
  budget, responding `200 OK` with the updated budget.
- Expose `DELETE /v1/budgets/{budget_id}` — soft-delete an owned live budget, responding
  `204 No Content`.
- Add the missing request/response DTOs, mappers, and handlers to the existing `BudgetController`
  and `budgeting_status_error` table.
- Write HTTP integration tests and a Locust stress scenario for the new endpoints.

## Capabilities

### New Capabilities

_(none — all operations are already captured by existing specs; this change adds HTTP requirements
to each)_

### Modified Capabilities

- `list-budgets`: add HTTP requirement — `GET /v1/budgets`, `200 OK`, ordered
  most-recent-period-first.
- `active-budget`: add HTTP requirement — `GET /v1/budgets/active`, `200 OK` with enriched totals,
  `404` when none.
- `update-budget`: add HTTP requirement — `PATCH /v1/budgets/{budget_id}`, `200 OK`, unified error
  envelope.
- `delete-budget`: add HTTP requirement — `DELETE /v1/budgets/{budget_id}`, `204 No Content`,
  unified error envelope.

## Impact

- **Modified files** under `features/budgeting/infrastructure/http/`:
  - `controllers/budget_controller.py` — four new handler methods.
  - `errors/lookups/budgeting_status_error.py` — add `BudgetNotFoundError` and
    `InvalidBudgetRangeError` entries.
  - New request/response DTOs and their mappers:
    `requests/update_budget_request.py`,
    `responses/active_budget_response.py`, `responses/budget_list_response.py`,
    `mappers/requests/update_budget_request_mapper.py`,
    `mappers/responses/active_budget_response_mapper.py`,
    `mappers/responses/budget_list_response_mapper.py`.
- **`features/budgeting/main/budgeting_route.py`** — wire the new DI providers (use cases).
- **`tests/budgeting/integrations/http/`** — new HTTP integration test file.
- **`tests/stress/`** — new Locust scenario file.
- No change to `domain/` or `application/` — use cases, ports, and repositories are untouched.
- No new runtime dependencies.
