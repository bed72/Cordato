import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _an_expense(
    *,
    id: str = "exp-1",
    person_id: str = "person-1",
    deleted_at: datetime | None = None,
    occurred_on: date = date(2026, 6, 20),
) -> ExpenseEntity:
    expense = ExpenseEntity.create(
        id=id,
        person_id=person_id,
        description="almoço",
        created_at=_FIXED_NOW,
        occurred_on=occurred_on,
        amount=MoneyValueObject(Decimal("10.00")),
    )
    expense.deleted_at = deleted_at

    return expense


def test_created_expense_is_stored_under_its_id() -> None:
    expense = _an_expense()
    repository = ExpenseRepository()

    asyncio.run(repository.create(expense))

    assert repository._expenses == {"exp-1": expense}


def _seed(*expenses: ExpenseEntity) -> ExpenseRepository:
    repository = ExpenseRepository()
    for expense in expenses:
        asyncio.run(repository.create(expense))
    return repository


def test_find_in_range_returns_only_expenses_within_the_inclusive_range() -> None:
    after = _an_expense(id="after", occurred_on=date(2026, 7, 1))
    before = _an_expense(id="before", occurred_on=date(2026, 5, 31))
    inside_end = _an_expense(id="end", occurred_on=date(2026, 6, 30))
    inside_start = _an_expense(id="start", occurred_on=date(2026, 6, 1))

    repository = _seed(inside_start, inside_end, before, after)

    found = asyncio.run(repository.find_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))

    assert {expense.id for expense in found} == {"start", "end"}


def test_find_in_range_excludes_other_people() -> None:
    mine = _an_expense(id="mine", person_id="person-1")
    theirs = _an_expense(id="theirs", person_id="person-2")
    repository = _seed(mine, theirs)

    found = asyncio.run(repository.find_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))

    assert [expense.id for expense in found] == ["mine"]


def test_find_in_range_excludes_soft_deleted() -> None:
    live = _an_expense(id="live")
    removed = _an_expense(id="removed", deleted_at=_FIXED_NOW)
    repository = _seed(live, removed)

    found = asyncio.run(repository.find_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))

    assert [expense.id for expense in found] == ["live"]
