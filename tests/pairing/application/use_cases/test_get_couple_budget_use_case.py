import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from tests.pairing.fakes.fake_pair_repository import FakePairRepository
from tests.pairing.fakes.fake_partner_budget_reader import FakePartnerBudgetReader
from trocado.features.pairing.application.data.partner_active_budget_data import (
    PartnerActiveBudgetData,
)
from trocado.features.pairing.application.use_cases.get_couple_budget_use_case import (
    GetCoupleBudgetUseCase,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError

_READER = "reader-1"
_PARTNER = "partner-1"
_DAY = date(2026, 6, 24)
_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _live_pair() -> PairEntity:
    return PairEntity.create(
        id="pair-1",
        person_a_id=_READER,
        person_b_id=_PARTNER,
        created_at=_FIXED_NOW,
    )


def _dissolved_pair() -> PairEntity:
    return PairEntity(
        id="pair-0",
        person_a_id=_READER,
        person_b_id=_PARTNER,
        created_at=_FIXED_NOW,
        deleted_at=_FIXED_NOW,
    )


def _budget(
    *,
    person_id: str,
    amount: str = "100.00",
    total_spent: str = "40.00",
    end_date: date = date(2026, 6, 30),
    start_date: date = date(2026, 6, 1),
) -> PartnerActiveBudgetData:
    return PartnerActiveBudgetData(
        end_date=end_date,
        person_id=person_id,
        start_date=start_date,
        amount=Decimal(amount),
        total_spent=Decimal(total_spent),
    )


def _build(
    *,
    pairs: tuple[PairEntity, ...] = (),
    budgets: dict[str, PartnerActiveBudgetData] | None = None,
) -> GetCoupleBudgetUseCase:
    return GetCoupleBudgetUseCase(
        repository=FakePairRepository(*pairs),
        partner_budget_reader=FakePartnerBudgetReader(budgets or {}),
    )


def test_combines_both_active_budgets_into_a_panorama() -> None:
    use_case = _build(
        pairs=(_live_pair(),),
        budgets={
            _READER: _budget(
                amount="100.00",
                person_id=_READER,
                total_spent="40.00",
                start_date=date(2026, 6, 1),
                end_date=date(2026, 6, 20),
            ),
            _PARTNER: _budget(
                amount="50.00",
                person_id=_PARTNER,
                total_spent="35.00",
                end_date=date(2026, 6, 30),
                start_date=date(2026, 6, 10),
            ),
        },
    )

    result = asyncio.run(use_case.execute(_READER, _DAY))

    assert result is not None
    assert result.amount == Decimal("150.00")
    assert result.remaining == Decimal("75.00")
    assert result.total_spent == Decimal("75.00")
    assert result.period_end == date(2026, 6, 30)
    assert result.period_start == date(2026, 6, 1)


def test_spans_only_the_partner_who_has_an_active_budget() -> None:
    use_case = _build(
        pairs=(_live_pair(),),
        budgets={
            _READER: _budget(
                amount="80.00",
                person_id=_READER,
                total_spent="30.00",
                end_date=date(2026, 6, 25),
                start_date=date(2026, 6, 5),
            ),
        },
    )

    result = asyncio.run(use_case.execute(_READER, _DAY))

    assert result is not None
    assert result.amount == Decimal("80.00")
    assert result.remaining == Decimal("50.00")
    assert result.total_spent == Decimal("30.00")
    assert result.period_end == date(2026, 6, 25)
    assert result.period_start == date(2026, 6, 5)


def test_returns_none_when_neither_partner_has_an_active_budget() -> None:
    use_case = _build(pairs=(_live_pair(),), budgets={})

    assert asyncio.run(use_case.execute(_READER, _DAY)) is None


def test_rejects_reader_with_no_live_pair() -> None:
    use_case = _build(pairs=(), budgets={})

    with pytest.raises(NotPairedError):
        asyncio.run(use_case.execute(_READER, _DAY))


def test_dissolved_pair_grants_no_view() -> None:
    use_case = _build(pairs=(_dissolved_pair(),), budgets={})

    with pytest.raises(NotPairedError):
        asyncio.run(use_case.execute(_READER, _DAY))
