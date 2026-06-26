## 1. list-expenses — expenses context

- [x] 1.1 Extend `ExpenseRepositoryInterface` with `async def list_live_for_person(person_id: str) -> list[ExpenseEntity]` (all live, no range; soft-deleted excluded), documenting it against the two-read contract
- [x] 1.2 Implement `list_live_for_person` on the in-memory `ExpenseRepository` (filter `deleted_at is None` and `person_id`)
- [x] 1.3 Add `ListExpensesUseCase` (`application/use_cases`): read the person's live expenses, sort most-recent-first (`occurred_on` desc, then `created_at` desc), map each via the existing `ExpenseDataMapper`, return `list[ExpenseData]`
- [x] 1.4 Confirm `ExpenseData` / `ExpenseDataMapper` are reused as-is (no new read-model needed)

## 2. default-budget — budgeting domain

- [x] 2.1 Add `BudgetEntity.covers(day: date) -> bool` (inclusive `start_date <= day <= end_date`) — the single-day sibling of `overlaps`, with a docstring distinguishing the two
- [x] 2.2 Add `DefaultBudgetVirtualObject` (`domain/virtual_objects`): carries the bucket's leftover expense amounts and derives `total_spent` as an exact-decimal `MoneyValueObject` sum; no `amount`, no `remaining`. Docstring framing it as the third domain shape

## 3. default-budget — budgeting application

- [x] 3.1 Add `LedgerExpenseData` (`application/data`): budgeting's own cross-context expense read shape (`id`, `person_id`, `amount`, `occurred_on`, `description`, `created_at`)
- [x] 3.2 Add `ExpenseReaderInterface` (`application/interfaces`): ABC gateway port, `async def list_for_person(person_id: str) -> list[LedgerExpenseData]`, documented as an ACL seam distinct from `SpendReaderInterface`
- [x] 3.3 Add `DefaultBudgetData` (`application/data`): `total_spent: Decimal` + `expenses: tuple[LedgerExpenseData, ...]`
- [x] 3.4 Add `DefaultBudgetDataMapper` (`application/mappers`): `@staticmethod to_data(virtual_object, expenses) -> DefaultBudgetData` (takes the money-deriving VO plus its leftover expenses; the bucket holds only its money in the domain, derive-don't-store)
- [x] 3.5 Add `GetDefaultBudgetUseCase` (`application/use_cases`): `asyncio.gather` live budgets + ledger; select leftovers via `not any(budget.covers(day))`; sort most-recent-first; build the VO; return the mapped `DefaultBudgetData`

## 4. Tests

- [x] 4.1 `BudgetEntity.covers` unit tests (before/inside/after, both inclusive boundaries) — in `test_budget_entity.py`
- [x] 4.2 `DefaultBudgetVirtualObject` unit tests (`total_spent` exact sum, single expense, empty bucket → zero). NOTE: leftover *selection* across budgets is use-case orchestration (it spans budgets + the cross-context ledger), so those scenarios are covered in 4.5, not on the VO
- [x] 4.3 `ListExpensesUseCase` tests (ordering, own-data-only, soft-deleted excluded, empty list) with a fake expense repository
- [x] 4.4 Add `FakeExpenseReader` under `tests/budgeting/fakes/` satisfying `ExpenseReaderInterface`
- [x] 4.5 `GetDefaultBudgetUseCase` tests (expense outside/inside/boundary, multiple budgets, soft-deleted budget covers nothing, own-data-only, ordering, empty cases) with the fake reader + fake budget repository
- [x] 4.6 Integration tests under `tests/expenses/integrations/` (list-expenses through in-memory `ExpenseRepository`) and `tests/budgeting/integrations/` (default-budget through in-memory `BudgetRepository` + `FakeExpenseReader`)

## 5. Quality gate

- [x] 5.1 Run `/trocado:guard` (architecture-guard) over the diff and resolve any findings — PASS, 0 blockers
- [x] 5.2 `uv run poe check` green (format → lint → mypy --strict → pytest) — 262 passed
