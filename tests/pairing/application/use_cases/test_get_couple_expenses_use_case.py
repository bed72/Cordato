import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from tests.pairing.fakes.fake_pair_repository import FakePairRepository
from tests.pairing.fakes.fake_partner_expense_reader import FakePartnerExpenseReader
from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.application.use_cases.get_couple_expenses_use_case import (
    GetCoupleExpensesUseCase,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError

_READER = "reader-1"
_PARTNER = "partner-1"
_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _live_pair() -> PairEntity:
    return PairEntity.create(
        id="pair-1",
        created_at=_FIXED_NOW,
        person_a_id=_READER,
        person_b_id=_PARTNER,
    )


def _dissolved_pair() -> PairEntity:
    return PairEntity(
        id="pair-0",
        person_a_id=_READER,
        person_b_id=_PARTNER,
        created_at=_FIXED_NOW,
        deleted_at=_FIXED_NOW,
    )


def _expense(
    *,
    id: str,
    person_id: str,
    amount: str = "10.00",
    occurred_on: date = date(2026, 6, 24),
    created_at: datetime = _FIXED_NOW,
) -> PartnerExpenseData:
    return PartnerExpenseData(
        id=id,
        person_id=person_id,
        amount=Decimal(amount),
        occurred_on=occurred_on,
        created_at=created_at,
        description=None,
    )


def _build(
    *,
    pairs: tuple[PairEntity, ...] = (),
    ledgers: dict[str, list[PartnerExpenseData]] | None = None,
) -> GetCoupleExpensesUseCase:
    return GetCoupleExpensesUseCase(
        repository=FakePairRepository(*pairs),
        partner_expense_reader=FakePartnerExpenseReader(ledgers or {}),
    )


def test_unions_both_ledgers_marking_mine_and_theirs() -> None:
    use_case = _build(
        pairs=(_live_pair(),),
        ledgers={
            _READER: [_expense(id="mine-1", person_id=_READER)],
            _PARTNER: [_expense(id="theirs-1", person_id=_PARTNER)],
        },
    )

    result = asyncio.run(use_case.execute(_READER))

    by_id = {item.id: item for item in result}
    assert by_id["mine-1"].perspective == "mine"
    assert by_id["theirs-1"].perspective == "theirs"
    assert by_id["theirs-1"].person_id == _PARTNER


def test_orders_most_recent_first_by_day_then_creation() -> None:
    use_case = _build(
        pairs=(_live_pair(),),
        ledgers={
            _READER: [
                _expense(id="old", person_id=_READER, occurred_on=date(2026, 6, 1)),
                _expense(
                    id="same-day-earlier",
                    person_id=_READER,
                    occurred_on=date(2026, 6, 24),
                    created_at=datetime(2026, 6, 24, 8, tzinfo=UTC),
                ),
            ],
            _PARTNER: [
                _expense(
                    id="same-day-later",
                    person_id=_PARTNER,
                    occurred_on=date(2026, 6, 24),
                    created_at=datetime(2026, 6, 24, 20, tzinfo=UTC),
                ),
            ],
        },
    )

    result = asyncio.run(use_case.execute(_READER))

    assert [item.id for item in result] == ["same-day-later", "same-day-earlier", "old"]


def test_returns_only_present_ledger_when_partner_is_empty() -> None:
    use_case = _build(
        pairs=(_live_pair(),),
        ledgers={_READER: [_expense(id="mine-1", person_id=_READER)]},
    )

    result = asyncio.run(use_case.execute(_READER))

    assert [item.id for item in result] == ["mine-1"]


def test_returns_empty_when_neither_partner_has_expenses() -> None:
    use_case = _build(pairs=(_live_pair(),), ledgers={})

    assert asyncio.run(use_case.execute(_READER)) == []


def test_rejects_reader_with_no_live_pair() -> None:
    use_case = _build(pairs=(), ledgers={})

    with pytest.raises(NotPairedError):
        asyncio.run(use_case.execute(_READER))


def test_dissolved_pair_grants_no_view() -> None:
    use_case = _build(pairs=(_dissolved_pair(),), ledgers={})

    with pytest.raises(NotPairedError):
        asyncio.run(use_case.execute(_READER))
