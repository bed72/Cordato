import asyncio
from datetime import UTC, datetime

import pytest

from tests.core.fakes.fake_clock import FakeClock
from tests.core.fakes.fake_identifier_provider import FakeIdentifierProvider
from tests.identity.fakes.fake_password_hasher import FakePasswordHasher
from tests.identity.fakes.fake_person_repository import FakePersonRepository
from tests.identity.fakes.fake_recording_password_hasher import FakeRecordingPasswordHasher
from tests.identity.fakes.fake_session_repository import FakeSessionRepository
from tests.identity.fakes.fake_token_generator import FakeTokenGenerator
from trocado.features.identity.application.data.session_data import SessionData
from trocado.features.identity.application.data.sign_in_data import SignInData
from trocado.features.identity.application.use_cases.sign_in_use_case import _DECOY_HASH, SignInUseCase
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.entities.session_entity import SESSION_TIME_TO_LIVE
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.errors.invalid_credentials_error import InvalidCredentialsError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject

_EMAIL = "ana@example.com"
_PASSWORD = "supersecret"
_NOW = datetime(2026, 6, 26, tzinfo=UTC)


def _person(*, status: PersonStatus = PersonStatus.ACTIVE, password: str = f"hashed::{_PASSWORD}") -> PersonEntity:
    # The fake hasher stores `hashed::<plaintext>` and verifies against it.
    return PersonEntity(
        id="person-1",
        status=status,
        password=password,
        created_at=_NOW,
        name=NameValueObject("Ana"),
        email=EmailValueObject(_EMAIL),
    )


def _build(*people: PersonEntity, token: str = "session-token") -> tuple[SignInUseCase, FakeSessionRepository]:
    session_repository = FakeSessionRepository()
    use_case = SignInUseCase(
        clock=FakeClock(_NOW),
        hasher=FakePasswordHasher(),
        person_repository=FakePersonRepository(*people),
        identifier=FakeIdentifierProvider("session-id"),
        token_generator=FakeTokenGenerator(token),
        session_repository=session_repository,
    )
    return use_case, session_repository


def _sign_in(use_case: SignInUseCase, *, email: str = _EMAIL, password: str = _PASSWORD) -> SessionData:
    return asyncio.run(use_case.execute(SignInData(email=email, password=password)))


def test_correct_credential_issues_a_session_and_returns_it() -> None:
    use_case, session_repository = _build(_person(), token="opaque-abc")

    data = _sign_in(use_case)

    # The read-model carries the token, its expiry, and the nested person.
    assert data.token == "opaque-abc"
    assert data.expires_at == _NOW + SESSION_TIME_TO_LIVE
    assert data.person.id == "person-1"
    assert data.person.email == _EMAIL
    assert data.person.status == "active"
    # A session was persisted for that person, holding the issued token.
    assert len(session_repository.sessions) == 1
    stored = session_repository.sessions["session-id"]
    assert stored.token == "opaque-abc"
    assert stored.person_id == "person-1"
    assert stored.revoked_at is None


def test_wrong_password_is_rejected_and_issues_no_session() -> None:
    use_case, session_repository = _build(_person())

    with pytest.raises(InvalidCredentialsError):
        _sign_in(use_case, password="wrongpassword")

    assert session_repository.sessions == {}


def test_unknown_email_is_rejected_generically() -> None:
    use_case, session_repository = _build()  # empty repository

    with pytest.raises(InvalidCredentialsError):
        _sign_in(use_case)

    assert session_repository.sessions == {}


def test_malformed_email_is_rejected_as_invalid_credentials_not_invalid_email() -> None:
    # A malformed email must be indistinguishable from a wrong credential — never surface InvalidEmailError.
    use_case, _ = _build(_person())

    with pytest.raises(InvalidCredentialsError):
        _sign_in(use_case, email="not-an-email")


def test_too_short_password_is_rejected_as_invalid_credentials_not_weak_password() -> None:
    # Likewise a password that fails the policy collapses into the generic error, never WeakPasswordError.
    use_case, _ = _build(_person())

    with pytest.raises(InvalidCredentialsError):
        _sign_in(use_case, password="short")


def test_inactive_account_cannot_sign_in() -> None:
    # A deleted person is invisible to active reads, so its email resolves to nothing — generic rejection.
    use_case, _ = _build(_person(status=PersonStatus.DELETED))

    with pytest.raises(InvalidCredentialsError):
        _sign_in(use_case)


def test_all_failures_are_mutually_indistinguishable() -> None:
    # Same type, same message across every failure mode — no oracle reveals which factor was wrong.
    populated, _ = _build(_person())
    empty, _ = _build()
    messages = {
        str(_capture(lambda: _sign_in(populated, password="wrongpassword"))),
        str(_capture(lambda: _sign_in(empty))),
        str(_capture(lambda: _sign_in(populated, email="not-an-email"))),
        str(_capture(lambda: _sign_in(populated, password="short"))),
    }

    assert messages == {"E-mail ou senha inválidos."}


def test_not_found_path_still_verifies_once_against_the_decoy() -> None:
    # Timing equalization: even with no person, exactly one verify runs — against the decoy hash.
    hasher = FakeRecordingPasswordHasher()
    use_case = SignInUseCase(
        clock=FakeClock(_NOW),
        hasher=hasher,
        person_repository=FakePersonRepository(),
        identifier=FakeIdentifierProvider("session-id"),
        token_generator=FakeTokenGenerator(),
        session_repository=FakeSessionRepository(),
    )

    with pytest.raises(InvalidCredentialsError):
        _sign_in(use_case)

    assert hasher.verified_against == [_DECOY_HASH]


def _capture(action: object) -> InvalidCredentialsError:
    try:
        action()  # type: ignore[operator]
    except InvalidCredentialsError as error:
        return error
    raise AssertionError("expected InvalidCredentialsError")
