from datetime import date
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.pairing.domain.virtual_objects.couple_budget_virtual_object import (
    CoupleBudgetVirtualObject,
)
from trocado.features.pairing.domain.virtual_objects.partner_active_budget_virtual_object import (
    PartnerActiveBudgetVirtualObject,
)


def _budget(
    *,
    amount: str,
    end_date: date,
    start_date: date,
    total_spent: str,
) -> PartnerActiveBudgetVirtualObject:
    return PartnerActiveBudgetVirtualObject(
        end_date=end_date,
        start_date=start_date,
        amount=MoneyValueObject(Decimal(amount)),
        total_spent=MoneyValueObject(Decimal(total_spent)),
    )


def test_two_partners_span_min_start_to_max_end_and_sum_money() -> None:
    virtual_object = CoupleBudgetVirtualObject(
        (
            _budget(
                amount="100.00",
                total_spent="40.00",
                end_date=date(2026, 6, 20),
                start_date=date(2026, 6, 1),
            ),
            _budget(
                amount="50.00",
                total_spent="35.00",
                end_date=date(2026, 6, 30),
                start_date=date(2026, 6, 10),
            ),
        )
    )

    assert virtual_object.period_end == date(2026, 6, 30)
    assert virtual_object.period_start == date(2026, 6, 1)
    assert virtual_object.amount == MoneyValueObject(Decimal("150.00"))
    assert virtual_object.remaining == MoneyValueObject(Decimal("75.00"))
    assert virtual_object.total_spent == MoneyValueObject(Decimal("75.00"))


def test_single_partner_panorama_equals_that_budget() -> None:
    virtual_object = CoupleBudgetVirtualObject(
        (
            _budget(
                amount="80.00",
                total_spent="90.00",
                end_date=date(2026, 6, 25),
                start_date=date(2026, 6, 5),
            ),
        )
    )

    assert virtual_object.period_start == date(2026, 6, 5)
    assert virtual_object.period_end == date(2026, 6, 25)
    assert virtual_object.amount == MoneyValueObject(Decimal("80.00"))
    assert virtual_object.remaining == MoneyValueObject(Decimal("-10.00"))
    assert virtual_object.total_spent == MoneyValueObject(Decimal("90.00"))
