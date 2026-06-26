from __future__ import annotations

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.identity.application.data.sign_out_data import SignOutData
from trocado.features.identity.application.interfaces.session_repository_interface import (
    SessionRepositoryInterface,
)


class SignOutUseCase:
    """Revoke the session for a presented token — the `sign_out` half of the family.

    Idempotent and non-leaking: it revokes the live session the token identifies and stops there. A token
    that identifies no live session — unknown, already expired, or already revoked — is a successful no-op,
    never an error and never an oracle for whether the token existed. Only the presented token's session is
    revoked; another device's session of the same person stays live.
    """

    def __init__(
        self,
        clock: ClockInterface,
        session_repository: SessionRepositoryInterface,
    ) -> None:
        self._clock = clock
        self._session_repository = session_repository

    async def execute(self, data: SignOutData) -> None:
        now = await self._clock.now()

        # Only a live session is surfaced; nothing to revoke for an unknown/expired/already-revoked token.
        session = await self._session_repository.find_valid_by_token(data.token, now)
        if session is None:
            return

        session.revoke(now)
        await self._session_repository.revoke(session)
