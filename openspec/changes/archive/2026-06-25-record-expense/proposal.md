## Why

An expense is the domain's atomic fact — *"this person spent this amount on this day"* — and the
principle the whole model rests on is **store events, compute groupings**. Budgets, the active-budget
view with `total_spent`, the couple panorama, and the notifications all **derive** from expenses; none
of them can be demonstrated until expenses exist. Recording an expense is therefore the natural next
capability after registering a person: it is the lowest-coupling entity in the graph (it points to no
budget — *by design*) and it produces the events every later read computes over.

## What Changes

- Introduce the `expenses` context with its first use case: **record a new expense** from an owner
  (`person_id`), an amount, a date, and an optional description.
- Introduce `MoneyValueObject` in the **shared kernel** (`core/domain/value_objects/`) — the project's
  exact-decimal, BRL, centavo-precise money type. It is born here because `expenses` needs it first, but
  it is shared (budgeting and the couple aggregates will reuse it), so it does **not** live inside the
  `expenses` module. This also creates `core/domain/` (the kernel's domain layer) for the first time.
- Enforce the domain rules for an Expense at creation time: the amount is an exact decimal in centavos
  and **must be greater than zero**; the date is a pure `date` (no time); the description is optional
  free text (trimmed; blank becomes absent); the expense starts live (`deleted_at = null`) and receives
  an opaque `id` and a `created_at` from the determinism ports.
- **No link to any Budget.** The expense stores only *who* spent, *how much*, and *when*. Belonging to a
  budget is a read-time derivation by date range, never a stored reference — so no foreign key, no
  rewiring on budget edits, ever.
- Define the port this use case depends on: an async `ExpenseRepositoryInterface` for persistence. Reuse
  the existing core determinism ports (`ClockInterface`, `IdentifierProviderInterface`) — no new ones.
- Provide a working adapter for the current (framework-less, ORM-less) stage: an **in-memory** expense
  repository. This yields a vertical slice that runs and is fully testable today.
- **Out of scope (deferred to their own changes):** listing/querying expenses, the `find_in_range`
  derivation that powers budget belonging, editing, soft-deleting, any HTTP/web handler (no framework
  chosen), any ORM-backed persistence (no ORM chosen), and verifying that `person_id` refers to an
  existing/active person (authorization arrives with the auth change). This change only *records* an
  expense.

## Capabilities

### New Capabilities
- `record-expense`: Recording a new individual expense — validating the amount as exact-decimal,
  centavo-precise, positive money; accepting a pure date and an optional (normalized) description;
  assigning identity and timestamp; persisting it with **no reference to any budget**; and returning the
  expense's public data.

### Modified Capabilities
<!-- None. This is a new domain capability; `register-person`, `core-determinism`, and `dev-environment`
     are unaffected. -->

## Impact

- **New module:** `src/trocado/features/expenses/` with `domain/`, `application/`, `infrastructure/`.
- **New shared kernel domain:** `src/trocado/core/domain/value_objects/money_value_object.py`
  (`MoneyValueObject`) and `src/trocado/core/domain/errors/invalid_money_error.py` (`InvalidMoneyError`).
  First occupant of `core/domain/`.
- **New domain:** `ExpenseEntity` and the `InvalidAmountError` (amount must be positive).
- **New port + adapter:** `ExpenseRepositoryInterface` + in-memory `ExpenseRepository`. Reuses core
  `ClockInterface` / `IdentifierProviderInterface` and their existing adapters.
- **New application shapes:** `CreateExpenseData` (command), `ExpenseData` (read-model), `ExpenseDataMapper`.
- **No new dependency.** No web/ORM dependency added; no `ExpenseModel`/`ExpenseModelMapper` (no table yet).
- **Tests:** unit tests for `MoneyValueObject`, `ExpenseEntity`, `InvalidAmountError`, the use case (every
  scenario), the in-memory repository, plus an integration test wiring the real adapter + core
  determinism adapters through the use case. Reuses `tests/core/fakes/` (clock, id) and adds a
  `FakeExpenseRepository`.
