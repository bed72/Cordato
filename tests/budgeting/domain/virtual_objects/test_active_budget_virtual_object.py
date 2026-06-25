from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.domain.virtual_objects.active_budget_virtual_object import (
    ActiveBudgetVirtualObject,
)

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _budget(amount: str = "500.00") -> BudgetEntity:
    return BudgetEntity.create(
        id="budget-1",
        created_at=_FIXED_NOW,
        person_id="person-1",
        amount=MoneyValueObject(Decimal(amount)),
        start_date=date(2026, 6, 1),
        end_date=date(2026, 6, 30),
        note=None,
    )


def _active(amount: str = "500.00", total_spent: str = "150.00") -> ActiveBudgetVirtualObject:
    return ActiveBudgetVirtualObject(
        budget=_budget(amount),
        total_spent=MoneyValueObject(Decimal(total_spent)),
    )


def test_remaining_is_amount_minus_total_spent() -> None:
    active = _active(amount="500.00", total_spent="150.00")

    assert active.remaining == MoneyValueObject(Decimal("350.00"))


def test_remaining_goes_negative_when_overspent() -> None:
    active = _active(amount="100.00", total_spent="150.00")

    assert active.remaining == MoneyValueObject(Decimal("-50.00"))


def test_remaining_is_full_amount_when_nothing_spent() -> None:
    active = _active(amount="500.00", total_spent="0.00")

    assert active.remaining == MoneyValueObject(Decimal("500.00"))


def test_carries_the_budget_entity() -> None:
    budget = _budget()
    active = ActiveBudgetVirtualObject(budget=budget, total_spent=MoneyValueObject(Decimal("10.00")))

    assert active.budget is budget
