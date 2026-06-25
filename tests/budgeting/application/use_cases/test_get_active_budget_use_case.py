import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.budgeting.fakes.fake_budget_repository import FakeBudgetRepository
from tests.budgeting.fakes.fake_spend_reader import FakeSpendReader
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.use_cases.get_active_budget_use_case import (
    GetActiveBudgetUseCase,
)
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity

_START = date(2026, 6, 1)
_END = date(2026, 6, 30)
_TODAY = date(2026, 6, 15)
_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _budget(
    *,
    start_date: date = _START,
    end_date: date = _END,
    person_id: str = "person-1",
    amount: str = "500.00",
    deleted_at: datetime | None = None,
    id: str = "budget-1",
) -> BudgetEntity:
    budget = BudgetEntity.create(
        id=id,
        note=None,
        person_id=person_id,
        start_date=start_date,
        end_date=end_date,
        created_at=_FIXED_NOW,
        amount=MoneyValueObject(Decimal(amount)),
    )
    budget.deleted_at = deleted_at
    return budget


def _build(budgets: list[BudgetEntity], total_spent: str) -> GetActiveBudgetUseCase:
    budget_repository = FakeBudgetRepository()
    budget_repository.budgets.extend(budgets)
    spend_reader = FakeSpendReader(MoneyValueObject(Decimal(total_spent)))
    return GetActiveBudgetUseCase(repository=budget_repository, spend_reader=spend_reader)


def test_active_budget_is_enriched_with_total_spent_and_remaining() -> None:
    use_case = _build(budgets=[_budget(amount="500.00")], total_spent="150.00")

    data = asyncio.run(use_case.execute("person-1", _TODAY))

    assert data is not None
    assert data.id == "budget-1"
    assert data.remaining == Decimal("350.00")
    assert data.total_spent == Decimal("150.00")


def test_no_budget_for_the_day_returns_none() -> None:
    use_case = _build(
        budgets=[_budget(start_date=date(2026, 7, 1), end_date=date(2026, 7, 31))],
        total_spent="0.00",
    )

    assert asyncio.run(use_case.execute("person-1", _TODAY)) is None


def test_soft_deleted_budget_is_not_active() -> None:
    use_case = _build(budgets=[_budget(deleted_at=_FIXED_NOW)], total_spent="0.00")

    assert asyncio.run(use_case.execute("person-1", _TODAY)) is None


def test_overspend_makes_remaining_negative() -> None:
    use_case = _build(budgets=[_budget(amount="100.00")], total_spent="150.00")

    data = asyncio.run(use_case.execute("person-1", _TODAY))

    assert data is not None
    assert data.remaining == Decimal("-50.00")
    assert data.total_spent == Decimal("150.00")


def test_no_spend_leaves_full_remaining() -> None:
    use_case = _build(budgets=[_budget(amount="500.00")], total_spent="0.00")

    data = asyncio.run(use_case.execute("person-1", _TODAY))

    assert data is not None
    assert data.total_spent == Decimal("0.00")
    assert data.remaining == Decimal("500.00")
