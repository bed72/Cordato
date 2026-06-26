from __future__ import annotations

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.identity.application.data.person_data import PersonData
from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.application.interfaces.session_repository_interface import (
    SessionRepositoryInterface,
)
from trocado.features.identity.application.mappers.person_data_mapper import PersonDataMapper
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError


class ValidateSessionUseCase:
    """Resolve a session token to its authenticated person — the per-request auth check.

    Possession of a token whose session is live (not revoked, not expired) and whose person is still active
    is the authorization. Every failure mode — unknown token, expired or revoked session, or a person no
    longer active — collapses into one generic `InvalidSessionError`, so the result never reveals which
    condition failed (no oracle for guessing valid tokens).
    """

    def __init__(
        self,
        clock: ClockInterface,
        repository: PersonRepositoryInterface,
        session_repository: SessionRepositoryInterface,
    ) -> None:
        self._clock = clock
        self._repository = repository
        self._session_repository = session_repository

    async def execute(self, token: str) -> PersonData:
        now = await self._clock.now()

        # The repository surfaces only a live session (not revoked, not expired) — unknown/expired/revoked
        # all return None and fail identically.
        session = await self._session_repository.find_valid_by_token(token, now)
        if session is None:
            raise InvalidSessionError()

        # Re-check the person is still active: an outstanding token must stop working once the account is gone.
        person = await self._repository.find_active_by_id(session.person_id)
        if person is None:
            raise InvalidSessionError()

        return PersonDataMapper.to_data(person)
