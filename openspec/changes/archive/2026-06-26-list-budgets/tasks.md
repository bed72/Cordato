## 1. Use case

- [x] 1.1 Add `ListBudgetsUseCase` in `src/trocado/features/budgeting/application/use_cases/list_budgets_use_case.py`: constructor takes `BudgetRepositoryInterface`; `async def execute(self, person_id: str) -> list[BudgetData]`.
- [x] 1.2 In `execute`, `await repository.list_live_for_person(person_id)`, sort by `start_date` descending then `created_at` descending, and map each entity with `BudgetDataMapper.to_data`. Reuse the existing `BudgetData` and `BudgetDataMapper` — add no new data/mapper.

## 2. Tests

- [x] 2.1 Unit test `tests/budgeting/application/use_cases/test_list_budgets_use_case.py` (hand-written `FakeBudgetRepository` reused/added under `tests/budgeting/fakes/`), covering: budgets returned, empty list, soft-deleted excluded, most-recent-period-first ordering with the same-`start_date` tie broken by `created_at`, and only-own-budgets scoping.
- [x] 2.2 Integration test `tests/budgeting/integrations/test_list_budgets.py` wiring `ListBudgetsUseCase` to the real in-memory `BudgetRepository`, asserting the ordered, soft-delete-excluded, owner-scoped output end to end.

## 3. Gate

- [x] 3.1 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) and make it green.
- [x] 3.2 Run `/trocado:guard` on the diff and resolve any CHANGES REQUIRED.
