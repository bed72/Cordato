from __future__ import annotations

from abc import ABC, abstractmethod

from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity


class InviteCodeRepositoryInterface(ABC):
    """Port for persisting and looking up invite codes.

    ``create`` mints; ``find_by_token`` resolves a redeemed token to its code; ``consume`` persists a
    code that has just been stamped as redeemed.
    """

    @abstractmethod
    async def create(self, invite_code: InviteCodeEntity) -> None:
        """Persist a new invite code."""
        raise NotImplementedError

    @abstractmethod
    async def find_by_token(self, code: str) -> InviteCodeEntity | None:
        """Return the invite carrying this token, or ``None`` if no invite matches."""
        raise NotImplementedError

    @abstractmethod
    async def consume(self, invite_code: InviteCodeEntity) -> None:
        """Persist a code whose ``consumed_at`` has just been stamped."""
        raise NotImplementedError
