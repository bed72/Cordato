from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.domain.errors.invalid_budget_amount_error import (
    InvalidBudgetAmountError,
)
from trocado.features.budgeting.domain.errors.invalid_budget_range_error import (
    InvalidBudgetRangeError,
)

_END = date(2026, 6, 30)
_START = date(2026, 6, 1)
_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _create(
    *,
    amount: str = "500.00",
    start_date: date = _START,
    end_date: date = _END,
    note: str | None = "mercado",
    id: str = "budget-1",
    person_id: str = "person-1",
) -> BudgetEntity:
    return BudgetEntity.create(
        id=id,
        created_at=_FIXED_NOW,
        person_id=person_id,
        amount=MoneyValueObject(Decimal(amount)),
        start_date=start_date,
        end_date=end_date,
        note=note,
    )


def test_create_builds_a_live_budget() -> None:
    budget = _create()

    assert budget.id == "budget-1"
    assert budget.end_date == _END
    assert budget.note == "mercado"
    assert budget.deleted_at is None
    assert budget.start_date == _START
    assert budget.person_id == "person-1"
    assert budget.amount.value == Decimal("500.00")


def test_single_day_budget_is_valid() -> None:
    budget = _create(start_date=_START, end_date=_START)

    assert budget.start_date == budget.end_date


def test_rejects_start_after_end() -> None:
    with pytest.raises(InvalidBudgetRangeError):
        _create(start_date=_END, end_date=_START)


@pytest.mark.parametrize("amount", ["0", "0.00", "-1.00"])
def test_rejects_non_positive_amount(amount: str) -> None:
    with pytest.raises(InvalidBudgetAmountError):
        _create(amount=amount)


def test_trims_note() -> None:
    assert _create(note="  mercado  ").note == "mercado"


@pytest.mark.parametrize("note", [None, "", "   "])
def test_blank_note_becomes_none(note: str | None) -> None:
    assert _create(note=note).note is None


def test_identity_equality_is_by_id() -> None:
    a = _create()
    b = _create(id="budget-1", person_id="someone-else", amount="999.00")

    assert a == b
    assert hash(a) == hash(b)


def test_disjoint_ranges_do_not_overlap() -> None:
    a = _create(start_date=date(2026, 6, 1), end_date=date(2026, 6, 10))
    b = _create(start_date=date(2026, 7, 1), end_date=date(2026, 7, 10))

    assert not a.overlaps(b)
    assert not b.overlaps(a)


def test_adjacent_ranges_do_not_overlap() -> None:
    a = _create(start_date=date(2026, 6, 1), end_date=date(2026, 6, 15))
    b = _create(start_date=date(2026, 6, 16), end_date=date(2026, 6, 30))

    assert not a.overlaps(b)
    assert not b.overlaps(a)


def test_shared_boundary_day_overlaps() -> None:
    a = _create(start_date=date(2026, 6, 1), end_date=date(2026, 6, 15))
    b = _create(start_date=date(2026, 6, 15), end_date=date(2026, 6, 30))

    assert a.overlaps(b)
    assert b.overlaps(a)


def test_contained_range_overlaps() -> None:
    outer = _create(start_date=date(2026, 6, 1), end_date=date(2026, 6, 30))
    inner = _create(start_date=date(2026, 6, 10), end_date=date(2026, 6, 20))

    assert outer.overlaps(inner)
    assert inner.overlaps(outer)
