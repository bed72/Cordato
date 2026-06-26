## Why

A person can record, read, and delete expenses, but never correct one. A typo in the amount, a wrong
day, or a description that needs fixing today forces delete-and-recreate — which loses the expense's
identity and `created_at`, and clutters the audit trail with a removal that was really an edit. Editing
is the missing arm of expense CRUD (record / list / delete / **edit**), and it is the natural place to
prove, once more, that budget belonging is derived: changing an expense's day or amount must rewire no
budget — the spend simply recomputes on the next read.

## What Changes

- New use case to **edit an existing live expense** — change its `amount`, `occurred_on`, and/or
  `description` in place, keeping the same `id` and `created_at`.
- **Per-person authorization via the lookup**: only a live expense the requester owns can be edited.
  An unknown id, an expense owned by someone else, and an already soft-deleted expense all reject
  identically with `ExpenseNotFoundError`, revealing nothing.
- **Amount re-validated** by the entity: amount must be a positive exact decimal (cents, BRL). The
  description is normalized exactly as at creation (`strip()` → blank becomes absent).
- **No non-overlap check** — unlike a budget, an expense is a single-day fact with no range and no
  invariant against its siblings. Editing is amount/day/description re-validation plus
  authorization-via-lookup, nothing more.
- **No budget is touched.** Belonging is computed from `occurred_on` at read-time, so moving an expense
  to another day (or changing its amount) only changes which budget it falls under *on the next read* —
  there is nothing stored to rewire.
- A new repository port method to **persist the mutated live expense** (distinct from soft-delete).
- Domain errors stay short, pt-BR, and non-leaking. No new error type is needed — the two existing
  expense errors cover every rejection.

## Capabilities

### New Capabilities
- `edit-expense`: editing an existing live expense in place (amount, day, description), under per-person
  authorization, re-validating the amount invariant and normalizing the description, while touching no
  budget.

### Modified Capabilities
<!-- None. Editing reuses the budget-derivation behavior unchanged; no existing requirement changes. -->

## Impact

- **New code** in `features/expenses`: `EditExpenseData` (command), `EditExpenseUseCase`, an
  `ExpenseEntity.edit(...)` mutation method, and an `update(...)` method on
  `ExpenseRepositoryInterface` + its in-memory adapter.
- **Reused unchanged**: `ExpenseData` / `ExpenseDataMapper` (output), `MoneyValueObject`, and the two
  expense errors (`InvalidAmountError`, `ExpenseNotFoundError`).
- **No identity churn**: `id` and `created_at` are preserved; no `updated_at` field is introduced (the
  entity's shape is unchanged — adding edit-auditing would be a separate change).
- **No clock dependency**: with no `updated_at` to stamp, the use case depends only on the repository
  (contrast delete, which needs the clock for `deleted_at`).
- **Still ORM-deferred**: no `Model`/`ModelMapper`; the slice ships against the in-memory repository.
- No change to budgeting, no migration, no new dependency.
