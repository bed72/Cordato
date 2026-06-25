from decimal import Decimal

import pytest

from trocado.core.domain.errors.invalid_money_error import InvalidMoneyError
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject


def test_preserves_centavo_amount_exactly() -> None:
    assert MoneyValueObject(Decimal("19.90")).value == Decimal("19.90")


def test_normalizes_scale_to_two_places() -> None:
    assert MoneyValueObject(Decimal("19.9")).value == Decimal("19.90")
    assert MoneyValueObject(Decimal("20")).value == Decimal("20.00")


@pytest.mark.parametrize("raw", [Decimal("10.005"), Decimal("0.001"), Decimal("1.999")])
def test_rejects_more_than_two_decimal_places(raw: Decimal) -> None:
    with pytest.raises(InvalidMoneyError):
        MoneyValueObject(raw)


@pytest.mark.parametrize("raw", [Decimal("NaN"), Decimal("Infinity"), Decimal("-Infinity")])
def test_rejects_non_finite(raw: Decimal) -> None:
    with pytest.raises(InvalidMoneyError):
        MoneyValueObject(raw)


def test_allows_zero_and_negative() -> None:
    assert MoneyValueObject(Decimal("0")).value == Decimal("0.00")
    assert MoneyValueObject(Decimal("-5.5")).value == Decimal("-5.50")


def test_equality_is_by_normalized_value() -> None:
    assert MoneyValueObject(Decimal("19.9")) == MoneyValueObject(Decimal("19.90"))
