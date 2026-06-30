import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.expenses.fakes.fake_expense_repository import FakeExpenseRepository
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.core.infrastructure.gateways.spend_reader import SpendReader
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity

_UTC = UTC
_PERSON_ID = "person-1"


def _expense(occurred_on: date, amount: str) -> ExpenseEntity:
    return ExpenseEntity.create(
        description=None,
        person_id=_PERSON_ID,
        occurred_on=occurred_on,
        id=f"exp-{occurred_on}-{amount}",
        amount=MoneyValueObject(Decimal(amount)),
        created_at=datetime(2026, 1, 1, tzinfo=_UTC),
    )


def test_total_spent_sums_expenses_in_range() -> None:
    """total_spent returns the sum of all expenses within [start, end]."""
    repo = FakeExpenseRepository()
    asyncio.run(repo.create(_expense(date(2026, 6, 10), "100.00")))
    asyncio.run(repo.create(_expense(date(2026, 6, 20), "50.50")))

    reader = SpendReader(expense_repository=repo)
    data = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))

    assert data == MoneyValueObject(Decimal("150.50"))


def test_total_spent_returns_zero_when_no_expenses() -> None:
    """When the person has no expenses, total_spent is MoneyValueObject(0.00)."""
    repo = FakeExpenseRepository()
    reader = SpendReader(expense_repository=repo)
    data = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))

    assert data == MoneyValueObject(Decimal("0.00"))


def test_total_spent_excludes_expenses_outside_range() -> None:
    """Expenses outside [start, end] are not included in the total."""
    repo = FakeExpenseRepository()
    asyncio.run(repo.create(_expense(date(2026, 5, 31), "200.00")))  # before start
    asyncio.run(repo.create(_expense(date(2026, 7, 1), "300.00")))  # after end
    asyncio.run(repo.create(_expense(date(2026, 6, 15), "75.00")))  # within range

    reader = SpendReader(expense_repository=repo)
    data = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))

    assert data == MoneyValueObject(Decimal("75.00"))


def test_total_spent_includes_expenses_on_boundary_dates() -> None:
    """Boundary dates [start, end] are inclusive."""
    repo = FakeExpenseRepository()
    asyncio.run(repo.create(_expense(date(2026, 6, 1), "10.00")))  # start boundary
    asyncio.run(repo.create(_expense(date(2026, 6, 30), "20.00")))  # end boundary

    reader = SpendReader(expense_repository=repo)
    data = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))

    assert data == MoneyValueObject(Decimal("30.00"))


def test_total_spent_ignores_other_persons_expenses() -> None:
    """Expenses owned by a different person are not included."""
    repo = FakeExpenseRepository()
    other_expense = ExpenseEntity.create(
        id="other-exp",
        description=None,
        person_id="other-person",
        occurred_on=date(2026, 6, 15),
        amount=MoneyValueObject(Decimal("500.00")),
        created_at=datetime(2026, 6, 15, tzinfo=_UTC),
    )
    asyncio.run(repo.create(other_expense))
    asyncio.run(repo.create(_expense(date(2026, 6, 15), "25.00")))

    reader = SpendReader(expense_repository=repo)
    data = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))

    assert data == MoneyValueObject(Decimal("25.00"))
