from __future__ import annotations

from trocado.features.identity.application.data.session_data import SessionData
from trocado.features.identity.infrastructure.http.responses.person_response import PersonResponse
from trocado.features.identity.infrastructure.http.responses.session_response import SessionResponse


class SessionResponseMapper:
    @staticmethod
    def to_response(data: SessionData) -> SessionResponse:
        return SessionResponse(
            token=data.token,
            expires_at=data.expires_at,
            person=PersonResponse(
                id=data.person.id,
                name=data.person.name,
                email=data.person.email,
            ),
        )
