from __future__ import annotations

from abc import ABC, abstractmethod

from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity


class InviteCodeRepositoryInterface(ABC):
    """Port for persisting invite codes.

    This slice only mints codes, so the contract is a single ``create``. Lookup-by-token and the
    consumption update arrive with the accept-invite capability.
    """

    @abstractmethod
    async def create(self, invite_code: InviteCodeEntity) -> None:
        """Persist a new invite code."""
        raise NotImplementedError
