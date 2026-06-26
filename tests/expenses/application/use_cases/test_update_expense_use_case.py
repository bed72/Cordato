import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from tests.expenses.fakes.fake_expense_repository import FakeExpenseRepository
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.application.data.update_expense_data import UpdateExpenseData
from trocado.features.expenses.application.use_cases.update_expense_use_case import (
    UpdateExpenseUseCase,
)
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.domain.errors.expense_not_found_error import ExpenseNotFoundError
from trocado.features.expenses.domain.errors.invalid_amount_error import InvalidAmountError

_A_DAY = date(2026, 6, 20)
_NEW_DAY = date(2026, 6, 25)
_CREATED_AT = datetime(2026, 6, 20, tzinfo=UTC)


def _an_expense(
    *,
    id: str = "exp-1",
    person_id: str = "person-1",
    deleted_at: datetime | None = None,
) -> ExpenseEntity:
    expense = ExpenseEntity.create(
        id=id,
        occurred_on=_A_DAY,
        person_id=person_id,
        description="almoço",
        created_at=_CREATED_AT,
        amount=MoneyValueObject(Decimal("10.00")),
    )
    expense.deleted_at = deleted_at

    return expense


def _build_use_case(*expenses: ExpenseEntity) -> tuple[UpdateExpenseUseCase, FakeExpenseRepository]:
    repository = FakeExpenseRepository()
    repository.expenses.extend(expenses)
    use_case = UpdateExpenseUseCase(repository=repository)

    return use_case, repository


def _command(
    *,
    requester_id: str = "person-1",
    expense_id: str = "exp-1",
    amount: str = "42.50",
    occurred_on: date = _NEW_DAY,
    description: str | None = "jantar",
) -> UpdateExpenseData:
    return UpdateExpenseData(
        requester_id=requester_id,
        expense_id=expense_id,
        amount=Decimal(amount),
        occurred_on=occurred_on,
        description=description,
    )


def test_owner_updates_own_live_expense() -> None:
    expense = _an_expense()
    use_case, _ = _build_use_case(expense)

    result = asyncio.run(use_case.execute(_command()))

    # Returns the updated read-model, identity preserved.
    assert result.id == "exp-1"
    assert result.description == "jantar"
    assert result.occurred_on == _NEW_DAY
    assert result.created_at == _CREATED_AT
    assert result.amount == Decimal("42.50")
    # The stored entity is the very one that was mutated in place.
    assert expense.amount.value == Decimal("42.50")
    assert expense.occurred_on == _NEW_DAY


def test_blank_description_is_normalized_to_none() -> None:
    use_case, _ = _build_use_case(_an_expense())

    result = asyncio.run(use_case.execute(_command(description="   ")))

    assert result.description is None


def test_unknown_id_is_rejected_and_changes_nothing() -> None:
    use_case, repository = _build_use_case(_an_expense())

    with pytest.raises(ExpenseNotFoundError):
        asyncio.run(use_case.execute(_command(expense_id="ghost")))
    # The guard runs before any mutation: the untouched expense keeps its original values.
    assert repository.expenses[0].amount.value == Decimal("10.00")
    assert repository.expenses[0].occurred_on == _A_DAY


def test_another_persons_expense_is_rejected_and_left_untouched() -> None:
    theirs = _an_expense(id="theirs", person_id="person-2")
    use_case, _ = _build_use_case(theirs)

    with pytest.raises(ExpenseNotFoundError):
        asyncio.run(use_case.execute(_command(expense_id="theirs")))
    assert theirs.amount.value == Decimal("10.00")
    assert theirs.occurred_on == _A_DAY


def test_already_deleted_expense_is_rejected() -> None:
    removed = _an_expense(deleted_at=datetime(2026, 6, 21, tzinfo=UTC))
    use_case, _ = _build_use_case(removed)

    with pytest.raises(ExpenseNotFoundError):
        asyncio.run(use_case.execute(_command()))
    assert removed.amount.value == Decimal("10.00")


@pytest.mark.parametrize("amount", ["0", "0.00", "-1.00"])
def test_non_positive_amount_is_rejected_and_changes_nothing(amount: str) -> None:
    expense = _an_expense()
    use_case, _ = _build_use_case(expense)

    with pytest.raises(InvalidAmountError):
        asyncio.run(use_case.execute(_command(amount=amount)))
    # The amount guard lives in the entity and runs before any field is overwritten.
    assert expense.amount.value == Decimal("10.00")
    assert expense.occurred_on == _A_DAY
