## Why

A person can create, read, and delete budgets, but never correct one. A typo in the amount, a wrong
note, or a date range that needs nudging today forces delete-and-recreate — which loses the budget's
identity and `created_at`, and clutters the audit trail with a removal that was really an edit. Editing
is the missing arm of budget CRUD, and it is the natural place to prove, once more, that money belonging
is derived: changing a budget's dates must rewire nothing.

## What Changes

- New use case to **edit an existing live budget** — change its `amount`, `start_date`, `end_date`,
  and/or `note` in place, keeping the same `id` and `created_at`.
- **Per-person authorization via the lookup**: only a live budget the requester owns can be edited.
  An unknown id, a budget owned by someone else, and an already soft-deleted budget all reject
  identically with `BudgetNotFoundError`, revealing nothing.
- **Non-overlap invariant re-validated on the edited range**, against the owner's *other* live budgets
  (the budget being edited is excluded from its own check) — a shared boundary day still counts as
  overlap, mere adjacency does not.
- **Amount and range re-validated** by the entity: amount must be a positive exact decimal (cents, BRL),
  `start_date` must not be after `end_date`.
- **No expense is touched.** Belonging is computed from dates at read-time, so moving a budget's range
  only changes which expenses *fall under it on the next read* — there is nothing stored to rewire.
- A new repository port method to **persist the mutated live budget** (distinct from soft-delete).
- Domain errors stay short, pt-BR, and non-leaking. No new error type is needed — the four existing
  budgeting errors cover every rejection.

## Capabilities

### New Capabilities
- `edit-budget`: editing an existing live budget in place (amount, dates, note), under per-person
  authorization, re-validating the amount/range invariants and the non-overlap invariant against the
  owner's other live budgets, while touching no expense.

### Modified Capabilities
<!-- None. Editing reuses the active-budget/derivation behavior unchanged; no existing requirement changes. -->

## Impact

- **New code** in `features/budgeting`: `EditBudgetData` (command), `EditBudgetUseCase`, a
  `BudgetEntity.edit(...)` mutation method, and an `update(...)` method on
  `BudgetRepositoryInterface` + its in-memory adapter.
- **Reused unchanged**: `BudgetData` / `BudgetDataMapper` (output), `MoneyValueObject`, the clock port,
  and the four budgeting errors (`InvalidBudgetAmountError`, `InvalidBudgetRangeError`,
  `OverlappingBudgetError`, `BudgetNotFoundError`).
- **No identity churn**: `id` and `created_at` are preserved; no `updated_at` field is introduced (the
  entity's shape is unchanged — adding edit-auditing would be a separate change).
- **Still ORM-deferred**: no `Model`/`ModelMapper`; the slice ships against the in-memory repository.
- No change to expenses, no migration, no new dependency.
