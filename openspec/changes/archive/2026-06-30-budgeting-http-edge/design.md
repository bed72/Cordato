## Context

The budgeting vertical slice is complete at the domain and application layers: `BudgetEntity`,
`BudgetRepository` (in-memory), and five use cases (`CreateBudgetUseCase`,
`ListBudgetsUseCase`, `GetActiveBudgetUseCase`, `UpdateBudgetUseCase`,
`DeleteBudgetUseCase`). The existing `BudgetController` exposes only `POST /v1/budgets`.
The remaining four use cases are unreachable over HTTP.

The expenses HTTP edge (`2026-06-30-expenses-http-edge`) established the pattern that this
change follows exactly: extend the existing controller, add DTOs/mappers, wire new providers
in the route builder, write HTTP integration tests.

One constraint: `GetActiveBudgetUseCase` depends on `SpendReaderInterface` (a gateway port
that reads spend from the expenses ledger). No concrete adapter exists in `src/` yet — only
fakes in tests. This change must introduce the adapter as part of wiring the active-budget
endpoint.

## Goals / Non-Goals

**Goals:**
- Expose `GET /v1/budgets` → `ListBudgetsUseCase`, `200 OK`.
- Expose `GET /v1/budgets/active` → `GetActiveBudgetUseCase`, `200 OK`; `404` when no
  active budget for today.
- Expose `PATCH /v1/budgets/{budget_id}` → `UpdateBudgetUseCase`, `200 OK`.
- Expose `DELETE /v1/budgets/{budget_id}` → `DeleteBudgetUseCase`, `204 No Content`.
- Add `SpendReader` gateway adapter to make `GetActiveBudgetUseCase` wireable.
- HTTP integration tests for all four new endpoints.
- Locust stress scenario for the budgeting flow.

**Non-Goals:**
- `GET /v1/budgets/default` (`GetDefaultBudgetUseCase`) — not part of this change.
- `GET /v1/budgets/{budget_id}` (single budget by id) — no use case for this yet.
- Audit endpoint (`GET /v1/budgets?include_deleted=true`) — separate scope.
- Any change to `domain/` or `application/` — use cases, ports, and in-memory repository
  are untouched.
- ORM/persistence.

## Decisions

### D1 — Extend the existing `BudgetController`, not a new class

Four new methods (`list`, `active`, `update`, `delete`) are added to the existing
`BudgetController(Controller)`. The resource path `/budgets` is declared once on the class;
Litestar resolves child paths (`/active`, `/{budget_id:str}`) from the decorated methods.
No second controller.

### D2 — Path parameter name: `budget_id`

The route uses `/{budget_id:str}` (not `/{id}`), consistent with the expenses pattern
(`/{expense_id:str}`). The handler declares `budget_id: str`; Litestar binds it from the
path.

### D3 — `GET /v1/budgets/active` → `404` when use case returns `None`

`GetActiveBudgetUseCase.execute` returns `None` when no live budget contains today. This
is not a domain error — it is a valid no-result. The HTTP controller raises
`BudgetNotFoundError()` explicitly when the result is `None`, so the existing error table
(`BUDGETING_STATUS_ERROR: BudgetNotFoundError → 404`) frames the 404 uniformly, without any
special-casing in the controller.

The controller injects `ClockInterface` (already a named dependency at the `/v1` router)
to derive `today: date` from `clock.now()`.

### D4 — `SpendReader` gateway in `budgeting/infrastructure/gateways/spend_reader.py`

`GetActiveBudgetUseCase` requires `SpendReaderInterface`. The concrete adapter is created as
a gateway class in `budgeting/infrastructure/gateways/spend_reader.py`. It receives an
`ExpenseRepositoryInterface` at construction time (injected by the composition root, the sole
layer that knows both modules) and implements `total_spent` by calling
`expense_repository.find_in_range` and summing the amounts.

This cross-feature import (`budgeting/infrastructure` ← `expenses/application`) is the
expected pre-ORM pattern: the `SpendReaderInterface` docstring explicitly states the adapter
lives at the composition root today and moves to `infrastructure/gateways/` once a shared DB
query is available. Here we land it in `gateways/` immediately — the composition root still
owns the wiring.

The `ExpenseRepository` singleton (already built by `register_expenses_router`) is passed to
`register_budgeting_router` as a parameter from `app.py`.

### D5 — `BUDGETING_STATUS_ERROR` table is already complete

The existing table already covers every error reachable at the new handlers:
- `BudgetNotFoundError` → 404 (update, delete, active's not-found sentinel)
- `OverlappingBudgetError` → 409 (update)
- `InvalidBudgetRangeError` → 422 (update)
- `InvalidBudgetAmountError` → 422 (update)
- `InvalidMoneyError` → 422 (via `CORE_STATUS_ERROR` at the app layer)

No changes to `budgeting_status_error.py`.

### D6 — `ActiveBudgetResponse` is a separate DTO from `BudgetResponse`

`ActiveBudgetData` carries `total_spent` and `remaining` that `BudgetData` does not. Two
distinct Pydantic models and mappers: `BudgetResponse` (used by create, list, update) and
`ActiveBudgetResponse` (used only by active). No inheritance to avoid coupling.

### D7 — `PATCH` uses full-replacement semantics, `DELETE` returns `204 No Content`

Consistent with the expenses pattern and the domain contract of `UpdateBudgetUseCase`
(overwrites all editable fields). Clients must always supply `amount`, `start_date`,
`end_date`, and optionally `note`. The `UpdateBudgetRequest` mirrors `CreateBudgetRequest`
shape exactly (same fields). The response is a `BudgetResponse`.

`DELETE` returns `None` with `status_code=204`. No response mapper.

## Risks / Trade-offs

- **[Cross-feature gateway import]** → `spend_reader.py` imports `ExpenseRepositoryInterface`
  from expenses' application layer. Accepted: this is the documented transitional pattern. Will
  be replaced by a shared-DB query once the ORM lands.
- **[`app.py` coupling grows]** → `register_budgeting_router` now takes an
  `ExpenseRepository` from the composition root. Mitigation: `app.py` already knows all
  modules; adding one constructor parameter keeps the coupling explicit and in one file.
- **[In-memory store]** → Data is lost on restart. Expected transitional constraint.
