from __future__ import annotations

from trocado.features.identity.application.data.session_data import SessionData
from trocado.features.identity.application.mappers.person_data_mapper import PersonDataMapper
from trocado.features.identity.domain.virtual_objects.authenticated_session_virtual_object import (
    AuthenticatedSessionVirtualObject,
)


class SessionDataMapper:
    """Maps an AuthenticatedSessionVirtualObject to the public sign-in read-model.

    Takes the single composed virtual object (never the session and person as two args), surfacing the
    token and expiry and delegating the person's projection to the existing PersonDataMapper.
    """

    @staticmethod
    def to_data(authenticated_session: AuthenticatedSessionVirtualObject) -> SessionData:
        return SessionData(
            token=authenticated_session.token,
            expires_at=authenticated_session.expires_at,
            person=PersonDataMapper.to_data(authenticated_session.person),
        )
