from datetime import UTC, datetime, timedelta

from trocado.features.identity.domain.entities.session_entity import (
    SESSION_TIME_TO_LIVE,
    SessionEntity,
)

_NOW = datetime(2026, 6, 26, tzinfo=UTC)


def _session(token: str = "tok", person_id: str = "person-1") -> SessionEntity:
    return SessionEntity.create(id="session-1", token=token, person_id=person_id, created_at=_NOW)


def test_factory_births_a_live_session_with_derived_expiry() -> None:
    session = _session()

    assert session.revoked_at is None
    assert session.is_live(_NOW) is True
    assert session.expires_at == _NOW + SESSION_TIME_TO_LIVE


def test_is_live_is_false_once_expired() -> None:
    session = _session()

    # expires_at itself counts as expired (the window is exclusive on the far end).
    assert session.is_live(session.expires_at) is False
    assert session.is_live(session.expires_at + timedelta(seconds=1)) is False


def test_revoke_stamps_the_instant_and_ends_the_session() -> None:
    session = _session()

    session.revoke(_NOW)

    assert session.revoked_at == _NOW
    # Revoked sessions are not live, even well before expiry.
    assert session.is_live(_NOW) is False


def test_equality_is_by_id() -> None:
    one = _session(token="a")
    same_id_other_fields = SessionEntity.create(id="session-1", token="b", person_id="other", created_at=_NOW)
    different = SessionEntity.create(id="session-2", token="a", person_id="person-1", created_at=_NOW)

    assert one != different
    assert one == same_id_other_fields
    assert hash(one) == hash(same_id_other_fields)
