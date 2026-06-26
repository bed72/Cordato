import asyncio
from datetime import UTC, datetime

from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _pair(id: str = "pair-1", person_a_id: str = "person-1", person_b_id: str = "person-2") -> PairEntity:
    return PairEntity.create(id=id, created_at=_FIXED_NOW, person_a_id=person_a_id, person_b_id=person_b_id)


def test_create_persists_the_pair() -> None:
    repository = PairRepository()

    asyncio.run(repository.create(_pair("pair-1")))

    assert repository._pairs["pair-1"].id == "pair-1"


def test_find_active_matches_either_member() -> None:
    repository = PairRepository()
    asyncio.run(repository.create(_pair("pair-1", person_a_id="a", person_b_id="b")))

    assert asyncio.run(repository.find_active_by_person("a")) is not None
    assert asyncio.run(repository.find_active_by_person("b")) is not None


def test_find_active_returns_none_for_unpaired_person() -> None:
    repository = PairRepository()
    asyncio.run(repository.create(_pair("pair-1", person_a_id="a", person_b_id="b")))

    assert asyncio.run(repository.find_active_by_person("c")) is None


def test_find_active_ignores_dissolved_pairs() -> None:
    repository = PairRepository()
    dissolved = PairEntity(id="pair-1", created_at=_FIXED_NOW, person_a_id="a", person_b_id="b", deleted_at=_FIXED_NOW)
    asyncio.run(repository.create(dissolved))

    assert asyncio.run(repository.find_active_by_person("a")) is None
