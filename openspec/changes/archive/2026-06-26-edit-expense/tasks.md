## 1. Domain

- [x] 1.1 Add `ExpenseEntity.edit(*, amount, occurred_on, description)` to
  `domain/entities/expense_entity.py`: re-validate `amount.value > 0` (`InvalidAmountError`), normalize
  the description (`description.strip() or None`), overwrite the three editable fields in place, and
  leave `id`/`person_id`/`created_at`/`deleted_at` untouched.

## 2. Application

- [x] 2.1 Add `UpdateExpenseData` in `application/data/update_expense_data.py` — frozen, slotted
  dataclass: `requester_id: str`, `expense_id: str`, `amount: Decimal`, `occurred_on: date`,
  `description: str | None`. (Command named after the persistence verb `update`; the entity mutation
  keeps the domain verb `edit`.)
- [x] 2.2 Add `async def update(self, expense: ExpenseEntity) -> None` to `ExpenseRepositoryInterface`
  (`application/interfaces/expense_repository_interface.py`) — persist a mutated *live* expense;
  document it as distinct from `create` (introduce) and `delete` (persist soft-deleted state).
- [x] 2.3 Add `UpdateExpenseUseCase` in `application/use_cases/update_expense_use_case.py`, depending
  only on `ExpenseRepositoryInterface`: guard with `find_active_by_id(requester_id, expense_id)` →
  `ExpenseNotFoundError`; call `expense.edit(...)` with `MoneyValueObject(data.amount)`;
  `await repository.update(expense)`; return `ExpenseDataMapper.to_data(expense)`.

## 3. Infrastructure

- [x] 3.1 Implement `update` in the in-memory `ExpenseRepository`
  (`infrastructure/repositories/expense_repository.py`) — `self._expenses[expense.id] = expense`.

## 4. Tests

- [x] 4.1 `tests/expenses/domain/entities/test_expense_entity.py` (extend): `edit` overwrites the three
  fields and preserves id/created_at; rejects non-positive amount with `InvalidAmountError`; normalizes
  a blank/whitespace description to `None`; leaves `deleted_at` untouched.
- [x] 4.2 `tests/expenses/application/use_cases/test_update_expense_use_case.py`: happy path returns the
  updated `ExpenseData` with same id; unknown / foreign-owner / soft-deleted all raise
  `ExpenseNotFoundError`; non-positive amount raises `InvalidAmountError`; the guard runs before any
  mutation (a rejected update calls no `update`).
- [x] 4.3 Extend the expenses `FakeExpenseRepository` (`tests/expenses/fakes/fake_expense_repository.py`)
  with `update` — `self._expenses[expense.id] = expense`, mirroring its `create`.
- [x] 4.4 `tests/expenses/integrations/test_update_expense_integration.py`: wire `UpdateExpenseUseCase`
  with the real in-memory `ExpenseRepository`; assert that moving an expense's `occurred_on` across a
  budget boundary (and changing its amount) leaves every budget untouched in storage and only changes
  derived grouping/spend on the next read (derive-don't-store).

## 5. Quality gate

- [x] 5.1 Run `/trocado:guard` on the diff and resolve any findings.
- [x] 5.2 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) until green.
