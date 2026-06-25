## Why

A person can already record expenses, but those expenses fall into no period yet — there is nowhere
for spend to belong. A **budget** is the period that gives an amount a window: a planned ceiling over
a date range. Introducing it is the prerequisite for every downstream view (active budget, the "No
budget" bucket, the couple lens). It is also where the model's two sharpest invariants first appear:
budgets of one person **may not overlap in time**, and a budget's spend is **derived, never stored**.

## What Changes

- Add a **`budgeting`** feature module as an in-memory vertical slice (no ORM/web yet), mirroring the
  shape of `expenses`: pure `domain/`, async ABC ports in `application/`, an in-memory repository
  adapter, reusing the shared-kernel `MoneyValueObject`, `ClockInterface`, and
  `IdentifierProviderInterface`.
- New **`BudgetEntity`** (`id`, `created_at`, `person_id`, `amount`, `start_date`, `end_date`, `note`,
  `deleted_at`) with a `create(...)` factory that enforces, in pure domain, that `start_date <= end_date`
  (inclusive on both ends, date-only — no time).
- New **`CreateBudgetUseCase`** that mints identity + timestamp from the determinism ports, builds the
  amount as `MoneyValueObject`, and persists — but only **after** asserting the non-overlap invariant
  against the person's existing live budgets.
- **Non-overlap invariant**: two *live* budgets of the same person share no date, not even the boundary
  day. A range that touches or overlaps any existing live budget is rejected with a domain error.
- **Active budget, derived**: a read that returns the person's live budget whose range contains a given
  day, enriched at read-time with `total_spent` (sum of that person's expenses falling in the range) and
  `remaining` (`amount − total_spent`). Nothing about this is stored — it is computed from events, per
  the "derive, don't store" principle. Spend is summed via a date-range query over expenses, with **no
  foreign key** from expense to budget.

## Capabilities

### New Capabilities
- `create-budget`: registering an individual budget — the entity, its `amount`/date-range/`note`
  fields, the `start_date <= end_date` rule, and the per-person **non-overlap** invariant enforced at
  creation.
- `active-budget`: the read-time derivation of a person's active budget for a given day, enriched with
  `total_spent` and `remaining`, where spend is summed from expenses by date-range with no stored link.

### Modified Capabilities
<!-- None. Expenses' read-by-range need is introduced here as a new port method, not a change to the record-expense spec's requirements. -->

## Impact

- **New module**: `src/trocado/features/budgeting/` (`domain/`, `application/`, `infrastructure/`) and
  its mirrored test tree `tests/budgeting/`.
- **Reuses** (no change): `core` `MoneyValueObject`, `ClockInterface`, `IdentifierProviderInterface`.
- **Expenses**: introduces a read port to sum a person's expenses within a date range (the mechanism
  that *derives* the expense→budget belonging). This is additive — a new abstract method and its
  in-memory implementation — and does not alter any existing record-expense behavior.
- **No new runtime dependencies.** Still pre-ORM/pre-web: the slice runs and is fully tested in memory.
