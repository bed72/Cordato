## 1. Domain

- [x] 1.1 Add `BudgetEntity.edit(*, amount, start_date, end_date, note)` to
  `domain/entities/budget_entity.py`: re-validate `amount.value > 0` (`InvalidBudgetAmountError`) and
  `start_date <= end_date` (`InvalidBudgetRangeError`), normalize the note (`note.strip() or None`),
  overwrite the four editable fields in place, and leave `id`/`person_id`/`created_at`/`deleted_at`
  untouched.

## 2. Application

- [x] 2.1 Add `EditBudgetData` in `application/data/edit_budget_data.py` — frozen, slotted dataclass:
  `requester_id: str`, `budget_id: str`, `amount: Decimal`, `start_date: date`, `end_date: date`,
  `note: str | None`.
- [x] 2.2 Add `async def update(self, budget: BudgetEntity) -> None` to `BudgetRepositoryInterface`
  (`application/interfaces/budget_repository_interface.py`) — persist a mutated *live* budget; document
  it as distinct from `create` (introduce) and `delete` (persist soft-deleted state).
- [x] 2.3 Add `EditBudgetUseCase` in `application/use_cases/edit_budget_use_case.py`, depending only on
  `BudgetRepositoryInterface`: guard with `find_active_by_id(requester_id, budget_id)` →
  `BudgetNotFoundError`; call `budget.edit(...)` with `MoneyValueObject(data.amount)`; fetch
  `list_live_for_person(requester_id)` and raise `OverlappingBudgetError` if any *other* live budget
  (`o.id != budget.id`) overlaps; `await repository.update(budget)`; return
  `BudgetDataMapper.to_data(budget)`.

## 3. Infrastructure

- [x] 3.1 Implement `update` in the in-memory `BudgetRepository`
  (`infrastructure/repositories/budget_repository.py`) — `self._budgets[budget.id] = budget`.

## 4. Tests

- [x] 4.1 `tests/budgeting/domain/entities/test_budget_entity.py` (extend): `edit` overwrites the four
  fields and preserves id/created_at; rejects non-positive amount with `InvalidBudgetAmountError`;
  rejects inverted range with `InvalidBudgetRangeError`; normalizes a blank/whitespace note to `None`.
- [x] 4.2 `tests/budgeting/application/use_cases/test_edit_budget_use_case.py`: happy path returns the
  updated `BudgetData` with same id; unknown / foreign-owner / soft-deleted all raise
  `BudgetNotFoundError`; edited range overlapping another live budget raises `OverlappingBudgetError`;
  adjacent range is accepted; re-saving the same budget in its own range does not self-overlap.
- [x] 4.3 Extend the budgeting `FakeBudgetRepository` (under `tests/budgeting/fakes/`) with `update`
  if the fake does not already inherit a usable implementation.
- [x] 4.4 `tests/budgeting/integrations/test_edit_budget_integration.py`: wire `EditBudgetUseCase` with
  the real in-memory `BudgetRepository`; assert narrowing/widening the range leaves expenses untouched
  in storage and only changes derived grouping on the next read (derive-don't-store).

## 5. Quality gate

- [x] 5.1 Run `/trocado:guard` on the diff and resolve any findings.
- [x] 5.2 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) until green.
