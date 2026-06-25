import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository


def _an_expense() -> ExpenseEntity:
    return ExpenseEntity.create(
        id="exp-1",
        person_id="person-1",
        description="almoço",
        date=date(2026, 6, 20),
        amount=MoneyValueObject(Decimal("10.00")),
        created_at=datetime(2026, 6, 24, tzinfo=UTC),
    )


def test_created_expense_is_stored_under_its_id() -> None:
    expense = _an_expense()
    repository = ExpenseRepository()

    asyncio.run(repository.create(expense))

    assert repository._expenses == {"exp-1": expense}
