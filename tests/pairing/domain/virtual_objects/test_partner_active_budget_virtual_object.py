from datetime import date
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.pairing.domain.virtual_objects.partner_active_budget_virtual_object import (
    PartnerActiveBudgetVirtualObject,
)


def _budget(*, amount: str, total_spent: str) -> PartnerActiveBudgetVirtualObject:
    return PartnerActiveBudgetVirtualObject(
        end_date=date(2026, 6, 30),
        start_date=date(2026, 6, 1),
        amount=MoneyValueObject(Decimal(amount)),
        total_spent=MoneyValueObject(Decimal(total_spent)),
    )


def test_remaining_is_amount_minus_total_spent() -> None:
    budget = _budget(amount="100.00", total_spent="30.00")

    assert budget.remaining == MoneyValueObject(Decimal("70.00"))


def test_remaining_is_zero_when_fully_spent() -> None:
    budget = _budget(amount="100.00", total_spent="100.00")

    assert budget.remaining == MoneyValueObject(Decimal("0.00"))


def test_remaining_is_negative_when_overspent() -> None:
    budget = _budget(amount="100.00", total_spent="130.00")

    assert budget.remaining == MoneyValueObject(Decimal("-30.00"))
