from __future__ import annotations

from trocado.features.pairing.application.data.current_pair_data import CurrentPairData
from trocado.features.pairing.infrastructure.http.responses.pair_response import PairResponse


class PairResponseMapper:
    @staticmethod
    def to_response(data: CurrentPairData) -> PairResponse:
        return PairResponse(
            pair_id=data.pair_id,
            partner_id=data.partner_id,
            partner_name=data.partner_name,
            paired_since=data.paired_since,
        )
