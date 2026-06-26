from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.pairing.domain.enums.perspective import Perspective
from trocado.features.pairing.domain.virtual_objects.couple_expense_virtual_object import (
    CoupleExpenseVirtualObject,
)

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _view(*, owner_id: str, reader_id: str) -> CoupleExpenseVirtualObject:
    return CoupleExpenseVirtualObject(
        expense_id="expense-1",
        owner_id=owner_id,
        reader_id=reader_id,
        occurred_on=date(2026, 6, 24),
        created_at=_FIXED_NOW,
        description=None,
        amount=MoneyValueObject(Decimal("10.00")),
    )


def test_perspective_is_mine_when_reader_owns_it() -> None:
    view = _view(owner_id="reader-1", reader_id="reader-1")

    assert view.perspective is Perspective.MINE


def test_perspective_is_theirs_when_partner_owns_it() -> None:
    view = _view(owner_id="partner-1", reader_id="reader-1")

    assert view.perspective is Perspective.THEIRS
