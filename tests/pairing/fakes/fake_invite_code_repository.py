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

    async def find_by_token(self, code: str) -> InviteCodeEntity | None:
        for invite_code in self.invite_codes:
            if invite_code.code == code:
                return invite_code
        return None

    async def consume(self, invite_code: InviteCodeEntity) -> None:
        self._upsert(invite_code)

    async def revoke(self, invite_code: InviteCodeEntity) -> None:
        self._upsert(invite_code)

    def _upsert(self, invite_code: InviteCodeEntity) -> None:
        for index, stored in enumerate(self.invite_codes):
            if stored.id == invite_code.id:
                self.invite_codes[index] = invite_code
                return
        self.invite_codes.append(invite_code)
