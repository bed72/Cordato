import asyncio
from datetime import UTC, datetime

import pytest

from tests.core.fakes.fake_clock import FakeClock
from tests.pairing.fakes.fake_pair_repository import FakePairRepository
from trocado.features.pairing.application.data.dissolve_pair_data import DissolvePairData
from trocado.features.pairing.application.use_cases.dissolve_pair_use_case import (
    DissolvePairUseCase,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError

_PERSON_A = "person-a"
_PERSON_B = "person-b"
_NOW = datetime(2026, 6, 26, 9, tzinfo=UTC)
_CREATED_AT = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _live_pair(id: str = "pair-1") -> PairEntity:
    return PairEntity.create(
        id=id,
        person_a_id=_PERSON_A,
        person_b_id=_PERSON_B,
        created_at=_CREATED_AT,
    )


def _dissolved_pair(id: str = "pair-0") -> PairEntity:
    pair = _live_pair(id=id)
    pair.dissolve(_CREATED_AT)
    return pair


def _build(
    *,
    now: datetime = _NOW,
    pairs: tuple[PairEntity, ...] = (),
) -> tuple[DissolvePairUseCase, FakePairRepository]:
    pair_repository = FakePairRepository(*pairs)
    use_case = DissolvePairUseCase(clock=FakeClock(now), repository=pair_repository)
    return use_case, pair_repository


def test_requester_is_person_a_dissolves_and_persists() -> None:
    pair = _live_pair()
    use_case, pair_repository = _build(pairs=(pair,))

    asyncio.run(use_case.execute(DissolvePairData(requester_id=_PERSON_A)))

    assert pair.deleted_at == _NOW
    assert pair_repository.pairs == [pair]
    assert asyncio.run(pair_repository.find_active_by_person(_PERSON_A)) is None


def test_requester_is_person_b_dissolves_and_persists() -> None:
    pair = _live_pair()
    use_case, pair_repository = _build(pairs=(pair,))

    asyncio.run(use_case.execute(DissolvePairData(requester_id=_PERSON_B)))

    assert pair.deleted_at == _NOW
    assert asyncio.run(pair_repository.find_active_by_person(_PERSON_B)) is None


def test_requester_in_no_live_pair_raises_and_persists_nothing() -> None:
    use_case, pair_repository = _build(pairs=())

    with pytest.raises(NotPairedError):
        asyncio.run(use_case.execute(DissolvePairData(requester_id=_PERSON_A)))

    assert pair_repository.pairs == []


def test_requester_only_pair_already_dissolved_raises() -> None:
    already = _dissolved_pair()
    use_case, _ = _build(pairs=(already,))

    with pytest.raises(NotPairedError):
        asyncio.run(use_case.execute(DissolvePairData(requester_id=_PERSON_A)))
