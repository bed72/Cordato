import asyncio
from datetime import UTC, datetime

import pytest

from tests.identity.fakes.fake_person_repository import FakePersonRepository
from tests.identity.fakes.fake_recording_password_hasher import FakeRecordingPasswordHasher
from tests.identity.fakes.fake_session_repository import FakeSessionRepository
from trocado.features.identity.application.data.update_password_data import UpdatePasswordData
from trocado.features.identity.application.use_cases.update_password_use_case import UpdatePasswordUseCase
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.entities.session_entity import SessionEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError
from trocado.features.identity.domain.errors.weak_password_error import WeakPasswordError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject

_PERSON_ID = "person-1"
_CURRENT = "supersecret"
_NEW = "brandnewpass"
_ACTING_TOKEN = "token-acting"
_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _person(person_id: str = _PERSON_ID, password: str = f"hashed::{_CURRENT}") -> PersonEntity:
    # The fake hasher stores `hashed::<plaintext>` and verifies against it.
    return PersonEntity(
        id=person_id,
        status=PersonStatus.ACTIVE,
        password=password,
        created_at=_NOW,
        name=NameValueObject("Ana"),
        email=EmailValueObject("ana@example.com"),
    )


def _session(session_id: str, token: str, person_id: str = _PERSON_ID) -> SessionEntity:
    return SessionEntity.create(id=session_id, token=token, person_id=person_id, created_at=_NOW)


def _build(
    person: PersonEntity | None,
    *sessions: SessionEntity,
) -> tuple[UpdatePasswordUseCase, FakeRecordingPasswordHasher, FakePersonRepository, FakeSessionRepository]:
    hasher = FakeRecordingPasswordHasher()
    repository = FakePersonRepository(*([person] if person is not None else []))
    session_repository = FakeSessionRepository(*sessions)
    use_case = UpdatePasswordUseCase(hasher=hasher, person_repository=repository, session_repository=session_repository)
    return use_case, hasher, repository, session_repository


def _change(
    use_case: UpdatePasswordUseCase,
    *,
    new: str = _NEW,
    current: str = _CURRENT,
    token: str = _ACTING_TOKEN,
) -> None:
    data = UpdatePasswordData(
        requester_id=_PERSON_ID,
        current_session_token=token,
        new_password=PasswordValueObject(new),
        current_password=PasswordValueObject(current),
    )
    asyncio.run(use_case.execute(data))


def test_correct_current_password_swaps_the_hash_and_returns_none() -> None:
    person = _person()
    use_case, _, repository, _ = _build(person, _session("sess-acting", _ACTING_TOKEN))

    data = UpdatePasswordData(
        requester_id=_PERSON_ID,
        current_session_token=_ACTING_TOKEN,
        new_password=PasswordValueObject(_NEW),
        current_password=PasswordValueObject(_CURRENT),
    )
    assert asyncio.run(use_case.execute(data)) is None

    stored = repository.people[0]
    assert stored.password == f"hashed::{_NEW}"


def test_change_preserves_identity_status_name_and_email() -> None:
    person = _person()
    use_case, _, repository, _ = _build(person, _session("sess-acting", _ACTING_TOKEN))

    _change(use_case)

    stored = repository.people[0]
    assert stored.id == _PERSON_ID
    assert stored.created_at == _NOW
    assert stored.status is PersonStatus.ACTIVE
    assert stored.name == NameValueObject("Ana")
    assert stored.email == EmailValueObject("ana@example.com")


def test_wrong_current_password_is_rejected_and_changes_nothing() -> None:
    person = _person()
    use_case, hasher, repository, _ = _build(person, _session("sess-acting", _ACTING_TOKEN))

    with pytest.raises(IncorrectPasswordError):
        _change(use_case, current="wrongguess")

    # Stored hash is untouched and — crucially — no hashing was paid for past the rejected guard.
    assert hasher.hashed == []
    assert repository.people[0].password == f"hashed::{_CURRENT}"


def test_unresolved_requester_fails_identically_to_a_wrong_password() -> None:
    # No person seeded: the requester resolves to nothing. The error must be indistinguishable from a wrong
    # password (no oracle), and again no hashing happens.
    use_case, hasher, _, _ = _build(None, _session("sess-acting", _ACTING_TOKEN))

    with pytest.raises(IncorrectPasswordError):
        _change(use_case)

    assert hasher.hashed == []


def test_non_active_requester_fails_identically() -> None:
    deleted = _person()
    deleted.delete()
    use_case, hasher, _, _ = _build(deleted, _session("sess-acting", _ACTING_TOKEN))

    with pytest.raises(IncorrectPasswordError):
        _change(use_case)

    assert hasher.hashed == []


def test_too_short_new_password_is_rejected_before_any_call() -> None:
    person = _person()
    use_case, hasher, repository, _ = _build(person, _session("sess-acting", _ACTING_TOKEN))

    # The weak new password is rejected at PasswordValueObject construction, before the use case runs.
    with pytest.raises(WeakPasswordError):
        _change(use_case, new="short")

    assert repository.people[0].password == f"hashed::{_CURRENT}"
    assert hasher.hashed == []


def test_other_sessions_are_purged_and_the_acting_one_survives() -> None:
    person = _person()
    acting = _session("sess-acting", _ACTING_TOKEN)
    other = _session("sess-other", "token-other")
    use_case, _, _, session_repository = _build(person, acting, other)

    _change(use_case)

    remaining_tokens = {session.token for session in session_repository.sessions.values()}
    assert remaining_tokens == {_ACTING_TOKEN}


def test_another_persons_sessions_are_untouched() -> None:
    person = _person()
    acting = _session("sess-acting", _ACTING_TOKEN)
    stranger = _session("sess-stranger", "token-stranger", person_id="person-2")
    use_case, _, _, session_repository = _build(person, acting, stranger)

    _change(use_case)

    remaining_tokens = {session.token for session in session_repository.sessions.values()}
    assert remaining_tokens == {_ACTING_TOKEN, "token-stranger"}
