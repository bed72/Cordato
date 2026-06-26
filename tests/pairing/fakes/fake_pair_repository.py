from trocado.features.pairing.application.interfaces.pair_repository_interface import (
    PairRepositoryInterface,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity


class FakePairRepository(PairRepositoryInterface):
    """In-memory test double. Stores pairs in a list for assertions.

    Seed live or dissolved pairs via the constructor to drive the at-most-one-live-pair invariant.
    """

    def __init__(self, *pairs: PairEntity) -> None:
        self.pairs: list[PairEntity] = list(pairs)

    async def find_active_by_person(self, person_id: str) -> PairEntity | None:
        for pair in self.pairs:
            if pair.deleted_at is None and person_id in (pair.person_a_id, pair.person_b_id):
                return pair
        return None

    async def create(self, pair: PairEntity) -> None:
        self.pairs.append(pair)
