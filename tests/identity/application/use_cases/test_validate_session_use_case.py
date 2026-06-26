import asyncio
from datetime import UTC, datetime, timedelta

import pytest

from tests.core.fakes.fake_clock import FakeClock
from tests.identity.fakes.fake_person_repository import FakePersonRepository
from tests.identity.fakes.fake_session_repository import FakeSessionRepository
from trocado.features.identity.application.use_cases.validate_session_use_case import (
    ValidateSessionUseCase,
)
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.entities.session_entity import SessionEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject

_TOKEN = "live-token"
_NOW = datetime(2026, 6, 26, tzinfo=UTC)


def _person(person_id: str = "person-1") -> PersonEntity:
    return PersonEntity(
        id=person_id,
        password="hash",
        created_at=_NOW,
        status=PersonStatus.ACTIVE,
        name=NameValueObject("Ana"),
        email=EmailValueObject("ana@example.com"),
    )


def _session(
    *,
    token: str = _TOKEN,
    person_id: str = "person-1",
    revoked_at: datetime | None = None,
    expires_at: datetime = _NOW + timedelta(days=30),
) -> SessionEntity:
    return SessionEntity(
        id="session-1",
        token=token,
        created_at=_NOW,
        person_id=person_id,
        expires_at=expires_at,
        revoked_at=revoked_at,
    )


def _build(
    *,
    people: tuple[PersonEntity, ...] = (),
    sessions: tuple[SessionEntity, ...] = (),
) -> ValidateSessionUseCase:
    return ValidateSessionUseCase(
        clock=FakeClock(_NOW),
        repository=FakePersonRepository(*people),
        session_repository=FakeSessionRepository(*sessions),
    )


def _validate(use_case: ValidateSessionUseCase, token: str = _TOKEN) -> None:
    # Only used to provoke the failure path inside `pytest.raises`; the success path calls execute directly.
    asyncio.run(use_case.execute(token))


def test_live_token_returns_the_person() -> None:
    use_case = _build(people=(_person(),), sessions=(_session(),))

    data = asyncio.run(use_case.execute(_TOKEN))

    assert data.id == "person-1"
    assert data.email == "ana@example.com"


def test_unknown_token_is_rejected() -> None:
    use_case = _build(people=(_person(),))  # no sessions

    with pytest.raises(InvalidSessionError):
        _validate(use_case, token="nope")


def test_expired_session_is_rejected() -> None:
    expired = _session(expires_at=_NOW - timedelta(seconds=1))
    use_case = _build(people=(_person(),), sessions=(expired,))

    with pytest.raises(InvalidSessionError):
        _validate(use_case)


def test_revoked_session_is_rejected() -> None:
    revoked = _session(revoked_at=_NOW - timedelta(minutes=1))
    use_case = _build(people=(_person(),), sessions=(revoked,))

    with pytest.raises(InvalidSessionError):
        _validate(use_case)


def test_live_token_whose_person_is_no_longer_active_is_rejected() -> None:
    # The session is live, but the person is gone from active reads — the token must stop working.
    use_case = _build(people=(), sessions=(_session(),))

    with pytest.raises(InvalidSessionError):
        _validate(use_case)


def test_all_failures_carry_the_same_generic_message() -> None:
    cases = (
        _build(people=(_person(),)),  # unknown
        _build(people=(_person(),), sessions=(_session(expires_at=_NOW - timedelta(seconds=1)),)),  # expired
        _build(people=(_person(),), sessions=(_session(revoked_at=_NOW),)),  # revoked
        _build(sessions=(_session(),)),  # inactive person
    )
    messages = {str(_capture(use_case)) for use_case in cases}

    assert messages == {"Sessão inválida."}


def _capture(use_case: ValidateSessionUseCase) -> InvalidSessionError:
    try:
        asyncio.run(use_case.execute(_TOKEN))
    except InvalidSessionError as error:
        return error
    raise AssertionError("expected InvalidSessionError")
