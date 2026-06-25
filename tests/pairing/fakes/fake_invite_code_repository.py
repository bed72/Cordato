from trocado.features.pairing.application.interfaces.invite_code_repository_interface import (
    InviteCodeRepositoryInterface,
)
from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity


class FakeInviteCodeRepository(InviteCodeRepositoryInterface):
    """In-memory test double. Stores invite codes in a list for assertions."""

    def __init__(self) -> None:
        self.invite_codes: list[InviteCodeEntity] = []

    async def create(self, invite_code: InviteCodeEntity) -> None:
        self.invite_codes.append(invite_code)
