## Why

Budgeting can already create, edit, and delete budgets, and it can read the *active* budget (the one
covering today) and the *default* "No budget" bucket. But a person has no way to see **all** their live
budgets — past, present, and future periods — as a single list. Without it the owner cannot review their
planning history or pick an arbitrary budget to inspect or edit; the only budgets reachable today are the
one covering this instant and the synthetic default. This closes the last read gap in budgeting.

## What Changes

- Add a read-only capability that returns a person's **live** budgets as a list, each carrying its own
  identity and fields (`id`, `person_id`, `amount`, `start_date`, `end_date`, `note`, `created_at`).
- The list is **read at request-time and never mutates** the ledger, excludes soft-deleted budgets (the
  two-read contract), and returns only the requester's own budgets (per-person authorization).
- The list is ordered **most-recent-period-first** — by `start_date` descending, breaking ties by
  `created_at` descending — mirroring `list-expenses`' most-recent-first contract.
- Reuses the existing `BudgetData` read-model and `BudgetDataMapper` (no spend — `total_spent`/`remaining`
  stay with the enriched active-budget read) and the existing `BudgetRepositoryInterface.list_live_for_person`
  port. The only new production unit is a `ListBudgetsUseCase`.
- No new domain entity, value object, or port. No ORM/web yet — ships as the current in-memory vertical slice.

## Capabilities

### New Capabilities

- `list-budgets`: A person can list their own live budgets, read-only, soft-deleted excluded, ordered
  most-recent-period-first, scoped to the requester.

### Modified Capabilities

<!-- None. No existing requirement changes; the existing port method is reused as-is. -->

## Impact

- **New code:** `application/use_cases/list_budgets_use_case.py` (`ListBudgetsUseCase`) in the `budgeting`
  feature, plus its unit test and an integration test wiring the use case to the in-memory repository.
- **Reused, unchanged:** `BudgetRepositoryInterface.list_live_for_person`, `BudgetData`, `BudgetDataMapper`.
- **No impact on** `domain/`, other features, dependencies, or the deferred ORM/web edge.
