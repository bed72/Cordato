from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.domain.virtual_objects.default_budget_virtual_object import (
    DefaultBudgetVirtualObject,
)


def _bucket(*amounts: str) -> DefaultBudgetVirtualObject:
    return DefaultBudgetVirtualObject(
        expense_amounts=tuple(MoneyValueObject(Decimal(amount)) for amount in amounts),
    )


def test_total_spent_is_the_exact_sum_of_the_amounts() -> None:
    bucket = _bucket("10.00", "5.50", "0.49")

    assert bucket.total_spent == MoneyValueObject(Decimal("15.99"))


def test_total_spent_of_a_single_expense_is_that_amount() -> None:
    bucket = _bucket("42.00")

    assert bucket.total_spent == MoneyValueObject(Decimal("42.00"))


def test_empty_bucket_has_zero_total() -> None:
    bucket = _bucket()

    assert bucket.total_spent == MoneyValueObject(Decimal("0"))
