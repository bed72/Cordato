from datetime import UTC, datetime

from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.entities.session_entity import SessionEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.domain.virtual_objects.authenticated_session_virtual_object import (
    AuthenticatedSessionVirtualObject,
)

_NOW = datetime(2026, 6, 26, tzinfo=UTC)


def _person() -> PersonEntity:
    return PersonEntity(
        id="person-1",
        password="hash",
        created_at=_NOW,
        status=PersonStatus.ACTIVE,
        name=NameValueObject("Ana"),
        email=EmailValueObject("ana@example.com"),
    )


def test_surfaces_the_session_token_expiry_and_holds_the_person() -> None:
    session = SessionEntity.create(id="session-1", token="opaque", person_id="person-1", created_at=_NOW)
    person = _person()

    authenticated_session = AuthenticatedSessionVirtualObject(session=session, person=person)

    assert authenticated_session.person is person
    assert authenticated_session.token == "opaque"
    assert authenticated_session.expires_at == session.expires_at
