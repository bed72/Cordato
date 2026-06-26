import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.budgeting.fakes.fake_budget_repository import FakeBudgetRepository
from tests.budgeting.fakes.fake_expense_reader import FakeExpenseReader
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.data.ledger_expense_data import LedgerExpenseData
from trocado.features.budgeting.application.use_cases.get_default_budget_use_case import (
    GetDefaultBudgetUseCase,
)
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity

_FIXED_NOW = datetime(2026, 6, 24, 12, 0, tzinfo=UTC)


def _budget(
    *,
    end_date: date,
    start_date: date,
    id: str = "budget-1",
    person_id: str = "person-1",
    deleted_at: datetime | None = None,
) -> BudgetEntity:
    budget = BudgetEntity.create(
        id=id,
        note=None,
        end_date=end_date,
        person_id=person_id,
        start_date=start_date,
        created_at=_FIXED_NOW,
        amount=MoneyValueObject(Decimal("500.00")),
    )
    budget.deleted_at = deleted_at

    return budget


def _expense(
    *,
    id: str,
    occurred_on: date,
    amount: str = "10.00",
    created_at: datetime = _FIXED_NOW,
) -> LedgerExpenseData:
    return LedgerExpenseData(
        id=id,
        description=None,
        person_id="person-1",
        created_at=created_at,
        amount=Decimal(amount),
        occurred_on=occurred_on,
    )


def _build(
    budgets: list[BudgetEntity],
    expenses: list[LedgerExpenseData],
) -> GetDefaultBudgetUseCase:
    repository = FakeBudgetRepository()
    repository.budgets.extend(budgets)
    reader = FakeExpenseReader({"person-1": expenses})
    return GetDefaultBudgetUseCase(repository=repository, expense_reader=reader)


def test_expense_outside_every_budget_lands_in_the_bucket() -> None:
    use_case = _build(
        budgets=[_budget(start_date=date(2026, 6, 1), end_date=date(2026, 6, 30))],
        expenses=[_expense(id="outside", occurred_on=date(2026, 7, 5), amount="25.00")],
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data.expenses] == ["outside"]
    assert data.total_spent == Decimal("25.00")


def test_expense_inside_a_budget_is_excluded() -> None:
    use_case = _build(
        budgets=[_budget(start_date=date(2026, 6, 1), end_date=date(2026, 6, 30))],
        expenses=[_expense(id="inside", occurred_on=date(2026, 6, 15))],
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert data.expenses == ()
    assert data.total_spent == Decimal("0")


def test_boundary_day_counts_as_covered() -> None:
    use_case = _build(
        budgets=[_budget(start_date=date(2026, 6, 1), end_date=date(2026, 6, 30))],
        expenses=[
            _expense(id="on-start", occurred_on=date(2026, 6, 1)),
            _expense(id="on-end", occurred_on=date(2026, 6, 30)),
        ],
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert data.expenses == ()


def test_membership_is_checked_against_every_live_budget() -> None:
    use_case = _build(
        budgets=[
            _budget(id="june", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30)),
            _budget(id="august", start_date=date(2026, 8, 1), end_date=date(2026, 8, 31)),
        ],
        expenses=[
            _expense(id="in-august", occurred_on=date(2026, 8, 10)),
            _expense(id="in-july-gap", occurred_on=date(2026, 7, 10), amount="7.00"),
        ],
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data.expenses] == ["in-july-gap"]
    assert data.total_spent == Decimal("7.00")


def test_a_soft_deleted_budget_covers_nothing() -> None:
    use_case = _build(
        budgets=[
            _budget(start_date=date(2026, 6, 1), end_date=date(2026, 6, 30), deleted_at=_FIXED_NOW),
        ],
        expenses=[_expense(id="june-spend", occurred_on=date(2026, 6, 15), amount="30.00")],
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data.expenses] == ["june-spend"]
    assert data.total_spent == Decimal("30.00")


def test_no_expenses_yields_an_empty_bucket() -> None:
    use_case = _build(
        budgets=[_budget(start_date=date(2026, 6, 1), end_date=date(2026, 6, 30))],
        expenses=[],
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert data.expenses == ()
    assert data.total_spent == Decimal("0")


def test_bucket_is_ordered_most_recent_first() -> None:
    use_case = _build(
        budgets=[],
        expenses=[
            _expense(id="older", occurred_on=date(2026, 7, 1)),
            _expense(id="newer", occurred_on=date(2026, 7, 20)),
        ],
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data.expenses] == ["newer", "older"]


def test_reads_only_the_owners_ledger() -> None:
    repository = FakeBudgetRepository()
    reader = FakeExpenseReader(
        {
            "person-1": [_expense(id="mine", occurred_on=date(2026, 7, 1))],
            "person-2": [_expense(id="theirs", occurred_on=date(2026, 7, 1))],
        }
    )
    use_case = GetDefaultBudgetUseCase(repository=repository, expense_reader=reader)

    data = asyncio.run(use_case.execute("person-1"))

    assert reader.queried_ids == ["person-1"]
    assert [item.id for item in data.expenses] == ["mine"]
