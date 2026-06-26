from __future__ import annotations

from datetime import datetime

from trocado.features.identity.application.interfaces.session_repository_interface import (
    SessionRepositoryInterface,
)
from trocado.features.identity.domain.entities.session_entity import SessionEntity


class SessionRepository(SessionRepositoryInterface):
    """In-memory session store, keyed by id. A stand-in until an ORM-backed adapter replaces it.

    Owns the validity filter: ``find_valid_by_token`` surfaces only a live session (matching token, not
    revoked, not yet expired at the supplied ``now``), so callers never see revoked or expired rows.
    """

    def __init__(self) -> None:
        self._sessions: dict[str, SessionEntity] = {}

    async def create(self, session: SessionEntity) -> None:
        self._sessions[session.id] = session

    async def find_valid_by_token(self, token: str, now: datetime) -> SessionEntity | None:
        for session in self._sessions.values():
            if session.token == token and session.is_live(now):
                return session
        return None

    async def revoke(self, session: SessionEntity) -> None:
        self._sessions[session.id] = session
