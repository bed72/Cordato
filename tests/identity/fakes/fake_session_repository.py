from datetime import datetime

from trocado.features.identity.application.interfaces.session_repository_interface import (
    SessionRepositoryInterface,
)
from trocado.features.identity.domain.entities.session_entity import SessionEntity


class FakeSessionRepository(SessionRepositoryInterface):
    """In-memory test double, keyed by id. Reads surface only a live session (not revoked, not expired)."""

    def __init__(self, *sessions: SessionEntity) -> None:
        self.sessions: dict[str, SessionEntity] = {session.id: session for session in sessions}

    async def create(self, session: SessionEntity) -> None:
        self.sessions[session.id] = session

    async def find_valid_by_token(self, token: str, now: datetime) -> SessionEntity | None:
        return next(
            (session for session in self.sessions.values() if session.token == token and session.is_live(now)),
            None,
        )

    async def revoke(self, session: SessionEntity) -> None:
        self.sessions[session.id] = session
