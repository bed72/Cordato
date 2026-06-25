from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.domain.errors.invalid_amount_error import InvalidAmountError

_A_DAY = date(2026, 6, 20)
_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _create(amount: str = "10.00", description: str | None = "almoço") -> ExpenseEntity:
    return ExpenseEntity.create(
        id="exp-1",
        occurred_on=_A_DAY,
        person_id="person-1",
        created_at=_FIXED_NOW,
        description=description,
        amount=MoneyValueObject(Decimal(amount)),
    )


def test_create_builds_a_live_expense() -> None:
    expense = _create()

    assert expense.id == "exp-1"
    assert expense.deleted_at is None
    assert expense.occurred_on == _A_DAY
    assert expense.person_id == "person-1"
    assert expense.description == "almoço"
    assert expense.amount.value == Decimal("10.00")


@pytest.mark.parametrize("amount", ["0", "0.00", "-1.00"])
def test_rejects_non_positive_amount(amount: str) -> None:
    with pytest.raises(InvalidAmountError):
        _create(amount=amount)


def test_trims_description() -> None:
    assert _create(description="  almoço  ").description == "almoço"


@pytest.mark.parametrize("description", [None, "", "   "])
def test_blank_description_becomes_none(description: str | None) -> None:
    assert _create(description=description).description is None


def test_holds_no_budget_reference() -> None:
    expense = _create()
    assert not hasattr(expense, "budget")
    assert not hasattr(expense, "budget_id")


def test_identity_equality_is_by_id() -> None:
    a = _create()
    b = ExpenseEntity.create(
        id="exp-1",
        occurred_on=_A_DAY,
        created_at=_FIXED_NOW,
        description="different",
        person_id="someone-else",
        amount=MoneyValueObject(Decimal("999.00")),
    )

    assert a == b
    assert hash(a) == hash(b)
