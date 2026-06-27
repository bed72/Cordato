from __future__ import annotations

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.pairing.application.data.revoke_invite_code_data import RevokeInviteCodeData
from trocado.features.pairing.application.interfaces.invite_code_repository_interface import (
    InviteCodeRepositoryInterface,
)
from trocado.features.pairing.domain.errors.invite_code_already_consumed_error import (
    InviteCodeAlreadyConsumedError,
)
from trocado.features.pairing.domain.errors.invite_code_not_found_error import (
    InviteCodeNotFoundError,
)


class RevokeInviteCodeUseCase:
    """Kill a pending invite: resolve the token, confirm ownership, and stamp it revoked.

    Owner-scoped — a non-owner request is rejected as not-found (it never reveals the token exists). A
    consumed code cannot be revoked (it is already a pair). Revoking an already-revoked code is an
    idempotent no-op that preserves the original instant. Expiry does not block a revoke.
    """

    def __init__(self, clock: ClockInterface, repository: InviteCodeRepositoryInterface) -> None:
        self._clock = clock
        self._repository = repository

    async def execute(self, data: RevokeInviteCodeData) -> None:
        invite_code = await self._repository.find_by_token(data.code)
        if invite_code is None or invite_code.creator_id != data.requester_id:
            # A non-owner is treated exactly as an unknown token — no enumeration of others' invites.
            raise InviteCodeNotFoundError()

        if invite_code.is_consumed:
            raise InviteCodeAlreadyConsumedError()
        if invite_code.is_revoked:
            # Idempotent: re-revoking converges on the same terminal state; keep the original instant.
            return

        now = await self._clock.now()
        invite_code.revoke(now)
        await self._repository.revoke(invite_code)
