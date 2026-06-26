from __future__ import annotations

from trocado.features.pairing.application.interfaces.pair_repository_interface import (
    PairRepositoryInterface,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity


class PairRepository(PairRepositoryInterface):
    """In-memory pair store, keyed by id. A stand-in until an ORM-backed adapter replaces it."""

    def __init__(self) -> None:
        self._pairs: dict[str, PairEntity] = {}

    async def find_active_by_person(self, person_id: str) -> PairEntity | None:
        for pair in self._pairs.values():
            if pair.deleted_at is None and person_id in (pair.person_a_id, pair.person_b_id):
                return pair
        return None

    async def create(self, pair: PairEntity) -> None:
        self._pairs[pair.id] = pair
