from __future__ import annotations

from trocado.features.pairing.application.interfaces.invite_code_repository_interface import (
    InviteCodeRepositoryInterface,
)
from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity


class InviteCodeRepository(InviteCodeRepositoryInterface):
    """In-memory invite-code store, keyed by id. A stand-in until an ORM-backed adapter replaces it."""

    def __init__(self) -> None:
        self._invite_codes: dict[str, InviteCodeEntity] = {}

    async def create(self, invite_code: InviteCodeEntity) -> None:
        self._invite_codes[invite_code.id] = invite_code
