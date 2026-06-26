import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.expenses.fakes.fake_expense_repository import FakeExpenseRepository
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.application.use_cases.list_expenses_use_case import ListExpensesUseCase
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity

_FIXED_NOW = datetime(2026, 6, 24, 12, 0, tzinfo=UTC)


def _expense(
    *,
    id: str,
    amount: str = "10.00",
    person_id: str = "person-1",
    created_at: datetime = _FIXED_NOW,
    deleted_at: datetime | None = None,
    occurred_on: date = date(2026, 6, 20),
) -> ExpenseEntity:
    expense = ExpenseEntity.create(
        id=id,
        description=None,
        person_id=person_id,
        created_at=created_at,
        occurred_on=occurred_on,
        amount=MoneyValueObject(Decimal(amount)),
    )
    expense.deleted_at = deleted_at

    return expense


def _build(*expenses: ExpenseEntity) -> ListExpensesUseCase:
    repository = FakeExpenseRepository()
    repository.expenses.extend(expenses)
    return ListExpensesUseCase(repository=repository)


def test_returns_the_persons_live_expenses() -> None:
    use_case = _build(
        _expense(id="expense-1", amount="10.00"),
        _expense(id="expense-2", amount="20.00"),
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert {item.id for item in data} == {"expense-1", "expense-2"}
    assert {item.amount for item in data} == {Decimal("10.00"), Decimal("20.00")}


def test_a_person_with_no_expenses_gets_an_empty_list() -> None:
    use_case = _build()

    assert asyncio.run(use_case.execute("person-1")) == []


def test_soft_deleted_expenses_are_excluded() -> None:
    use_case = _build(
        _expense(id="live"),
        _expense(id="removed", deleted_at=_FIXED_NOW),
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["live"]


def test_lists_only_the_requesters_own_expenses() -> None:
    use_case = _build(
        _expense(id="mine", person_id="person-1"),
        _expense(id="theirs", person_id="person-2"),
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["mine"]


def test_orders_most_recent_first_by_day_then_creation() -> None:
    use_case = _build(
        _expense(id="older-day", occurred_on=date(2026, 6, 10)),
        _expense(id="newer-day", occurred_on=date(2026, 6, 20)),
        _expense(
            id="same-day-earlier",
            occurred_on=date(2026, 6, 20),
            created_at=datetime(2026, 6, 24, 8, 0, tzinfo=UTC),
        ),
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["newer-day", "same-day-earlier", "older-day"]
