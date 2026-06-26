import asyncio
from datetime import UTC, datetime

import pytest

from tests.pairing.fakes.fake_pair_repository import FakePairRepository
from tests.pairing.fakes.fake_person_directory import FakePersonDirectory
from trocado.features.pairing.application.use_cases.get_current_pair_use_case import (
    GetCurrentPairUseCase,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity

_BOB = "bob"
_ALICE = "alice"
_PROFILES = {_ALICE: "Alice", _BOB: "Bob"}
_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _live_pair() -> PairEntity:
    return PairEntity.create(
        id="pair-1",
        person_b_id=_BOB,
        person_a_id=_ALICE,
        created_at=_FIXED_NOW,
    )


def _dissolved_pair() -> PairEntity:
    return PairEntity(
        id="pair-0",
        person_b_id=_BOB,
        person_a_id=_ALICE,
        created_at=_FIXED_NOW,
        deleted_at=_FIXED_NOW,
    )


def _use_case(*pairs: PairEntity, profiles: dict[str, str] | None = None) -> GetCurrentPairUseCase:
    return GetCurrentPairUseCase(
        pair_repository=FakePairRepository(*pairs),
        person_directory=FakePersonDirectory(profiles=_PROFILES if profiles is None else profiles),
    )


def test_reader_is_person_a_sees_person_b_as_partner() -> None:
    use_case = _use_case(_live_pair())

    data = asyncio.run(use_case.execute(_ALICE))

    assert data is not None
    assert data.pair_id == "pair-1"
    assert data.partner_id == _BOB
    assert data.partner_name == "Bob"
    assert data.paired_since == _FIXED_NOW


def test_reader_is_person_b_sees_person_a_as_partner() -> None:
    use_case = _use_case(_live_pair())

    data = asyncio.run(use_case.execute(_BOB))

    assert data is not None
    assert data.partner_id == _ALICE
    assert data.partner_name == "Alice"


def test_no_live_pair_returns_none() -> None:
    use_case = _use_case()

    assert asyncio.run(use_case.execute(_ALICE)) is None


def test_dissolved_only_pair_returns_none() -> None:
    use_case = _use_case(_dissolved_pair())

    assert asyncio.run(use_case.execute(_ALICE)) is None


def test_unresolvable_partner_on_a_live_pair_raises() -> None:
    # The pair is live but identity cannot resolve the partner — an integrity breach, not the unpaired case.
    use_case = _use_case(_live_pair(), profiles={_ALICE: "Alice"})

    with pytest.raises(RuntimeError):
        asyncio.run(use_case.execute(_ALICE))


def test_reader_resolves_only_their_own_pair() -> None:
    other_pair = PairEntity.create(
        id="pair-2",
        person_b_id="dave",
        person_a_id="carol",
        created_at=_FIXED_NOW,
    )
    use_case = _use_case(
        _live_pair(),
        other_pair,
        profiles={_ALICE: "Alice", _BOB: "Bob", "carol": "Carol", "dave": "Dave"},
    )

    data = asyncio.run(use_case.execute(_ALICE))

    assert data is not None
    assert data.partner_id == _BOB
    assert data.pair_id == "pair-1"
