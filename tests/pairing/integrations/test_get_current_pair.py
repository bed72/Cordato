import asyncio
from datetime import UTC, datetime

from tests.pairing.fakes.fake_person_directory import FakePersonDirectory
from trocado.features.pairing.application.use_cases.get_current_pair_use_case import (
    GetCurrentPairUseCase,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository

_BOB = "bob"
_ALICE = "alice"
_PROFILES = {_ALICE: "Alice", _BOB: "Bob"}
_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def test_real_pair_repository_drives_the_current_pair_read() -> None:
    repository = PairRepository()
    directory = FakePersonDirectory(profiles=_PROFILES)
    use_case = GetCurrentPairUseCase(pair_repository=repository, person_directory=directory)

    # No pair yet → not paired is a valid, error-free answer.
    assert asyncio.run(use_case.execute(_ALICE)) is None

    pair = PairEntity.create(
        id="pair-1",
        person_b_id=_BOB,
        person_a_id=_ALICE,
        created_at=_FIXED_NOW,
    )
    asyncio.run(repository.create(pair))

    # Each member reads the same pair, with the other as partner.
    bob_view = asyncio.run(use_case.execute(_BOB))
    alice_view = asyncio.run(use_case.execute(_ALICE))

    assert alice_view is not None
    assert alice_view.partner_id == _BOB
    assert alice_view.pair_id == "pair-1"
    assert alice_view.partner_name == "Bob"

    assert bob_view is not None
    assert bob_view.pair_id == "pair-1"
    assert bob_view.partner_id == _ALICE
    assert bob_view.partner_name == "Alice"

    # Dissolving the pair takes the shared view down → back to not paired.
    pair.dissolve(_FIXED_NOW)
    asyncio.run(repository.dissolve(pair))

    assert asyncio.run(use_case.execute(_BOB)) is None
    assert asyncio.run(use_case.execute(_ALICE)) is None
