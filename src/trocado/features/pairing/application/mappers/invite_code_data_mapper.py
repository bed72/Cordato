from __future__ import annotations

from trocado.features.pairing.application.data.invite_code_data import InviteCodeData
from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity


class InviteCodeDataMapper:
    """Maps an InviteCodeEntity to its public read-model."""

    @staticmethod
    def to_data(invite_code: InviteCodeEntity) -> InviteCodeData:
        return InviteCodeData(
            id=invite_code.id,
            code=invite_code.code,
            creator_id=invite_code.creator_id,
            created_at=invite_code.created_at,
            expires_at=invite_code.expires_at,
            consumed_at=invite_code.consumed_at,
        )
