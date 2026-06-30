from __future__ import annotations

from trocado.features.pairing.application.data.pair_data import PairData
from trocado.features.pairing.infrastructure.http.responses.accepted_pair_response import AcceptedPairResponse


class AcceptedPairResponseMapper:
    @staticmethod
    def to_response(data: PairData) -> AcceptedPairResponse:
        return AcceptedPairResponse(
            pair_id=data.id,
            person_a_id=data.person_a_id,
            person_b_id=data.person_b_id,
            paired_since=data.created_at,
        )
