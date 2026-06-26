import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from tests.core.fakes.fake_clock import FakeClock
from tests.expenses.fakes.fake_expense_repository import FakeExpenseRepository
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.application.data.delete_expense_data import DeleteExpenseData
from trocado.features.expenses.application.use_cases.delete_expense_use_case import (
    DeleteExpenseUseCase,
)
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.domain.errors.expense_not_found_error import ExpenseNotFoundError

_A_DAY = date(2026, 6, 20)
_CREATED_AT = datetime(2026, 6, 20, tzinfo=UTC)
_DELETED_AT = datetime(2026, 6, 24, tzinfo=UTC)


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


def _build_use_case(*expenses: ExpenseEntity) -> tuple[DeleteExpenseUseCase, FakeExpenseRepository]:
    repository = FakeExpenseRepository()
    repository.expenses.extend(expenses)
    use_case = DeleteExpenseUseCase(clock=FakeClock(_DELETED_AT), repository=repository)

    return use_case, repository


def _command(requester_id: str = "person-1", expense_id: str = "exp-1") -> DeleteExpenseData:
    return DeleteExpenseData(requester_id=requester_id, expense_id=expense_id)


def test_owner_soft_deletes_own_live_expense() -> None:
    expense = _an_expense()
    use_case, repository = _build_use_case(expense)

    result = asyncio.run(use_case.execute(_command()))

    assert result is None
    assert expense.deleted_at == _DELETED_AT
    # Gone from normal reads, still present in the audit read.
    assert asyncio.run(repository.find_in_range("person-1", _A_DAY, _A_DAY)) == []
    assert asyncio.run(repository.list_including_removed("person-1")) == [expense]


def test_unknown_id_is_rejected_and_changes_nothing() -> None:
    use_case, repository = _build_use_case(_an_expense())

    with pytest.raises(ExpenseNotFoundError):
        asyncio.run(use_case.execute(_command(expense_id="ghost")))
    assert repository.expenses[0].deleted_at is None


def test_another_persons_expense_is_rejected_and_left_untouched() -> None:
    theirs = _an_expense(id="theirs", person_id="person-2")
    use_case, _ = _build_use_case(theirs)

    with pytest.raises(ExpenseNotFoundError):
        asyncio.run(use_case.execute(_command(expense_id="theirs")))
    assert theirs.deleted_at is None


def test_already_deleted_expense_is_rejected_without_overwriting() -> None:
    original = datetime(2026, 6, 21, tzinfo=UTC)
    removed = _an_expense(deleted_at=original)
    use_case, _ = _build_use_case(removed)

    with pytest.raises(ExpenseNotFoundError):
        asyncio.run(use_case.execute(_command()))
    # The original removal instant is never moved by a second delete.
    assert removed.deleted_at == original
