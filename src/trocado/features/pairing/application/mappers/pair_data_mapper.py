from __future__ import annotations

from trocado.features.pairing.application.data.pair_data import PairData
from trocado.features.pairing.domain.entities.pair_entity import PairEntity


class PairDataMapper:
    """Maps a PairEntity to its public read-model."""

    @staticmethod
    def to_data(pair: PairEntity) -> PairData:
        return PairData(
            id=pair.id,
            created_at=pair.created_at,
            person_a_id=pair.person_a_id,
            person_b_id=pair.person_b_id,
        )
