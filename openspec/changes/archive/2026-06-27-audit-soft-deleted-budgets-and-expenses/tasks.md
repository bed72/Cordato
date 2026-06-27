## 1. Budgeting — audit read-model & mapper

- [x] 1.1 Add `AuditBudgetData` in `src/trocado/features/budgeting/application/data/audit_budget_data.py`: a `@dataclass(frozen=True, slots=True)` with `id`, `person_id`, `amount: Decimal`, `start_date: date`, `end_date: date`, `note: str | None`, `created_at: datetime`, and `deleted_at: datetime | None`. No spend fields.
- [x] 1.2 Add `AuditBudgetDataMapper` in `src/trocado/features/budgeting/application/mappers/audit_budget_data_mapper.py`: `@staticmethod to_data(budget: BudgetEntity) -> AuditBudgetData`, unwrapping money to `Decimal` and passing `deleted_at` through.

## 2. Budgeting — use case

- [x] 2.1 Add `AuditBudgetsUseCase` in `src/trocado/features/budgeting/application/use_cases/audit_budgets_use_case.py`: constructor takes `BudgetRepositoryInterface`; `async def execute(self, person_id: str) -> list[AuditBudgetData]`.
- [x] 2.2 In `execute`, `await repository.list_including_removed(person_id)`, sort by `start_date` descending then `created_at` descending, and map each entity with `AuditBudgetDataMapper.to_data`. Add no new port method.

## 3. Expenses — audit read-model & mapper

- [x] 3.1 Add `AuditExpenseData` in `src/trocado/features/expenses/application/data/audit_expense_data.py`: a `@dataclass(frozen=True, slots=True)` with `id`, `person_id`, `amount: Decimal`, `occurred_on: date`, `description: str | None`, `created_at: datetime`, and `deleted_at: datetime | None`. No budget reference.
- [x] 3.2 Add `AuditExpenseDataMapper` in `src/trocado/features/expenses/application/mappers/audit_expense_data_mapper.py`: `@staticmethod to_data(expense: ExpenseEntity) -> AuditExpenseData`, unwrapping money to `Decimal` and passing `deleted_at` through.

## 4. Expenses — use case

- [x] 4.1 Add `AuditExpensesUseCase` in `src/trocado/features/expenses/application/use_cases/audit_expenses_use_case.py`: constructor takes `ExpenseRepositoryInterface`; `async def execute(self, person_id: str) -> list[AuditExpenseData]`.
- [x] 4.2 In `execute`, `await repository.list_including_removed(person_id)`, sort by `occurred_on` descending then `created_at` descending, and map each entity with `AuditExpenseDataMapper.to_data`. Add no new port method.

## 5. Tests — budgeting

- [x] 5.1 Unit test `tests/budgeting/application/use_cases/test_audit_budgets_use_case.py` (reusing/extending the hand-written `FakeBudgetRepository` under `tests/budgeting/fakes/` so it returns live + soft-deleted from `list_including_removed`), covering: both live and soft-deleted returned, empty list, `deleted_at` null for live and stamped for removed, most-recent-period-first ordering with the same-`start_date` tie broken by `created_at`, and only-own-budgets scoping.
- [x] 5.2 Integration test `tests/budgeting/integrations/test_audit_budgets_integration.py` wiring `AuditBudgetsUseCase` to the real in-memory `BudgetRepository`, asserting the ordered, soft-deleted-included, owner-scoped output end to end.

## 6. Tests — expenses

- [x] 6.1 Unit test `tests/expenses/application/use_cases/test_audit_expenses_use_case.py` (reusing/extending the hand-written `FakeExpenseRepository` under `tests/expenses/fakes/` so it returns live + soft-deleted from `list_including_removed`), covering: both live and soft-deleted returned, empty list, `deleted_at` null for live and stamped for removed, most-recent-first ordering with the same-`occurred_on` tie broken by `created_at`, and only-own-expenses scoping.
- [x] 6.2 Integration test `tests/expenses/integrations/test_audit_expenses_integration.py` wiring `AuditExpensesUseCase` to the real in-memory `ExpenseRepository`, asserting the ordered, soft-deleted-included, owner-scoped output end to end.

## 7. Gate

- [x] 7.1 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) and make it green.
- [x] 7.2 Run `/trocado:guard` on the diff and resolve any CHANGES REQUIRED.
