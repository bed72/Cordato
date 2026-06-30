from __future__ import annotations

from trocado.features.pairing.application.data.invite_code_data import InviteCodeData
from trocado.features.pairing.infrastructure.http.responses.invite_code_response import InviteCodeResponse


class InviteCodeResponseMapper:
    @staticmethod
    def to_response(data: InviteCodeData) -> InviteCodeResponse:
        return InviteCodeResponse(
            id=data.id,
            code=data.code,
            creator_id=data.creator_id,
            created_at=data.created_at,
            expires_at=data.expires_at,
            consumed_at=data.consumed_at,
        )
