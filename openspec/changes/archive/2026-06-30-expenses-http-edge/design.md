## Context

The expenses domain and application layers are complete vertical slices: `ExpenseEntity`,
`MoneyValueObject`, four use cases (`CreateExpenseUseCase`, `ListExpensesUseCase`,
`UpdateExpenseUseCase`, `DeleteExpenseUseCase`), an ABC repository port, and an in-memory
adapter. None of these are reachable over HTTP. The Litestar web pattern has already been
established by the budgeting and identity edges; this change applies that same pattern to
expenses without introducing any new architectural choices.

## Goals / Non-Goals

**Goals:**
- Expose `POST /v1/expenses` → `CreateExpenseUseCase`, `201 Created`.
- Expose `GET /v1/expenses` → `ListExpensesUseCase`, `200 OK`.
- Expose `PATCH /v1/expenses/{expense_id}` → `UpdateExpenseUseCase`, `200 OK`.
- Expose `DELETE /v1/expenses/{expense_id}` → `DeleteExpenseUseCase`, `204 No Content`.
- Wire `ExpenseController` as a scoped `Router` (expenses-scoped DI) in the composition root.
- Add the expenses error→status table (`EXPENSES_STATUS_ERROR`) covering every domain error reachable at the boundary.
- HTTP integration tests + Locust stress scenario.

**Non-Goals:**
- Any change to `domain/` or `application/` — use cases, ports, and in-memory repositories are untouched.
- Persistence / ORM — the in-memory repository stays.
- Other HTTP endpoints (budgeting list/edit/delete, pairing, identity remaining).

## Decisions

### D1 — Replicate the budgeting controller shape exactly

`ExpenseController(Controller)` with `path = "/expenses"`, `tags = ["Expenses"]`, and one decorated
method per operation (`@post()`, `@get()`, `@patch("/{expense_id:str}")`,
`@delete("/{expense_id:str}", status_code=204)`). The controller only binds, maps, delegates, and
frames — no business logic. Pydantic v2 request DTOs, one per operation that carries a body; a shared
`ExpenseResponse` for create, list, and update. Delete returns `None` with status 204.

### D2 — Path parameter name: `expense_id`

The route uses `/{expense_id:str}` (not `/{id}`). Using a fully-qualified name avoids shadowing and
aligns with the project's no-abbreviation rule. The handler declares `expense_id: str` in its
signature; Litestar binds it from the path.

### D3 — Error→status table covers all reachable domain errors

```python
EXPENSES_STATUS_ERROR: dict[type[Exception], int] = {
    ExpenseNotFoundError: 404,
    InvalidAmountError:   422,
    InvalidMoneyError:    422,
}
```

This table is framework-independent (plain dict, no Litestar types), unit-tested in isolation.
The feature's `Router` registers its exception handler with
`{**CORE_STATUS_ERROR, **EXPENSES_STATUS_ERROR}`, scoped to the expenses router only —
mirroring the budgeting pattern.

### D4 — Auth: same `current_person_provider` pattern

All four handlers declare `current_person_provider: NamedDependency[CurrentPersonProvider]`
and call `await current_person_provider.data()` to obtain the acting `PersonData`. The provider
is registered on the `/v1` router at the composition root and inherited by the expenses router.

### D5 — `UpdateExpenseRequest` is a full-replacement body

`PATCH /v1/expenses/{expense_id}` takes a body with `amount`, `occurred_on`, and `description`
(optional). Despite using `PATCH` as the HTTP verb (a single resource operation), the domain
contract is full replacement of editable fields — consistent with `UpdateExpenseUseCase.execute`
which overwrites all three fields. No partial/sparse-update semantics.

### D6 — `DELETE` returns `204 No Content` with no body

The use case returns `None`. The controller method has return type `None` and
`status_code=204`. There is no response mapper for delete.

### D7 — File layout mirrors budgeting

```
features/expenses/infrastructure/http/
  controllers/  expense_controller.py
  requests/     create_expense_request.py
                update_expense_request.py
  responses/    expense_response.py
  mappers/
    requests/   create_expense_request_mapper.py
                update_expense_request_mapper.py
    responses/  expense_response_mapper.py
  errors/
    lookups/    expenses_status_error.py

features/expenses/main/
  expenses_provider.py      (Router builder, DI wiring)
```

`core/infrastructure/http/app.py`: one `register_expenses()` call added alongside
`register_identity()` and `register_budgeting()`.

## Risks / Trade-offs

- **[In-memory store]** → Data is lost on restart. Expected for this transitional stage; the ORM change replaces the adapter behind the unchanged port.
- **[No auth beyond current_person_provider]** → The expenses router trusts the session-token-validated identity from the provider. Per-person authorization is enforced in the use case via the scoped lookup (`find_active_by_id(requester_id, expense_id)`).
- **[`PATCH` with full-replacement semantics]** → Pragmatic choice aligned with the domain contract. Clients must always supply all editable fields. Documented in the request DTO's field descriptions.
