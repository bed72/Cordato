import asyncio
from datetime import UTC, datetime

import pytest

from tests.identity.fakes.fake_person_repository import FakePersonRepository
from tests.identity.fakes.fake_recording_password_hasher import FakeRecordingPasswordHasher
from tests.identity.fakes.fake_session_repository import FakeSessionRepository
from trocado.features.identity.application.data.update_email_data import UpdateEmailData
from trocado.features.identity.application.use_cases.update_email_use_case import UpdateEmailUseCase
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.entities.session_entity import SessionEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError
from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject

_PERSON_ID = "person-1"
_CURRENT = "supersecret"
_ACTING_TOKEN = "token-acting"
_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _person(
    name: str = "Ana",
    person_id: str = _PERSON_ID,
    email: str = "ana@example.com",
    password: str = f"hashed::{_CURRENT}",
    status: PersonStatus = PersonStatus.ACTIVE,
) -> PersonEntity:
    # The fake hasher stores `hashed::<plaintext>` and verifies against it.
    return PersonEntity(
        id=person_id,
        status=status,
        created_at=_NOW,
        password=password,
        name=NameValueObject(name),
        email=EmailValueObject(email),
    )


def _session(session_id: str, token: str, person_id: str = _PERSON_ID) -> SessionEntity:
    return SessionEntity.create(id=session_id, token=token, person_id=person_id, created_at=_NOW)


def _build(
    *people: PersonEntity,
    sessions: tuple[SessionEntity, ...] = (),
) -> tuple[UpdateEmailUseCase, FakeRecordingPasswordHasher, FakePersonRepository, FakeSessionRepository]:
    hasher = FakeRecordingPasswordHasher()
    repository = FakePersonRepository(*people)
    session_repository = FakeSessionRepository(*sessions)
    use_case = UpdateEmailUseCase(
        hasher=hasher,
        person_repository=repository,
        session_repository=session_repository,
    )
    return use_case, hasher, repository, session_repository


def _change(
    use_case: UpdateEmailUseCase,
    *,
    new_email: str,
    current: str = _CURRENT,
    token: str = _ACTING_TOKEN,
    requester_id: str = _PERSON_ID,
) -> None:
    data = UpdateEmailData(
        requester_id=requester_id,
        current_session_token=token,
        new_email=new_email,
        current_password=PasswordValueObject(current),
    )
    asyncio.run(use_case.execute(data))


def test_correct_password_swaps_email_and_returns_normalized_public_data() -> None:
    use_case, _, repository, _ = _build(_person(), sessions=(_session("sess-acting", _ACTING_TOKEN),))

    data = asyncio.run(
        use_case.execute(
            UpdateEmailData(
                requester_id=_PERSON_ID,
                new_email="  New@Example.COM ",
                current_session_token=_ACTING_TOKEN,
                current_password=PasswordValueObject(_CURRENT),
            )
        )
    )

    # The new email is normalized before storage and surfaced on the public read-model.
    assert not hasattr(data, "password")
    assert data.email == "new@example.com"
    assert repository.people[0].email == EmailValueObject("new@example.com")


def test_change_preserves_credentials_identity_name_and_status() -> None:
    use_case, _, repository, _ = _build(_person(), sessions=(_session("sess-acting", _ACTING_TOKEN),))

    _change(use_case, new_email="new@example.com")

    stored = repository.people[0]
    assert stored.id == _PERSON_ID
    assert stored.created_at == _NOW
    assert stored.status is PersonStatus.ACTIVE
    assert stored.name == NameValueObject("Ana")
    assert stored.password == f"hashed::{_CURRENT}"


def test_wrong_current_password_is_rejected_and_changes_nothing() -> None:
    use_case, _, repository, session_repository = _build(
        _person(), sessions=(_session("sess-acting", _ACTING_TOKEN), _session("sess-other", "token-other"))
    )

    with pytest.raises(IncorrectPasswordError):
        _change(use_case, new_email="new@example.com", current="wrongguess")

    # Email untouched and no session purged.
    assert repository.people[0].email == EmailValueObject("ana@example.com")
    assert {s.token for s in session_repository.sessions.values()} == {_ACTING_TOKEN, "token-other"}


def test_unresolved_requester_fails_identically_to_a_wrong_password() -> None:
    # No person seeded: the requester resolves to nothing. The error must be indistinguishable from a wrong
    # password (no oracle).
    use_case, _, _, _ = _build(sessions=(_session("sess-acting", _ACTING_TOKEN),))

    with pytest.raises(IncorrectPasswordError):
        _change(use_case, new_email="new@example.com")


def test_non_active_requester_fails_identically() -> None:
    deleted = _person()
    deleted.delete()
    use_case, _, _, _ = _build(deleted, sessions=(_session("sess-acting", _ACTING_TOKEN),))

    with pytest.raises(IncorrectPasswordError):
        _change(use_case, new_email="new@example.com")


def test_malformed_email_is_rejected_before_any_call() -> None:
    use_case, hasher, repository, _ = _build(_person(), sessions=(_session("sess-acting", _ACTING_TOKEN),))

    with pytest.raises(InvalidEmailError):
        _change(use_case, new_email="nope")

    # Rejected at EmailValueObject construction, before the guard — no verify paid for, email untouched.
    assert hasher.verified_against == []
    assert repository.people[0].email == EmailValueObject("ana@example.com")


def test_email_held_by_another_active_person_is_rejected() -> None:
    use_case, _, repository, _ = _build(
        _person(),
        _person(name="Bob", person_id="person-2", email="bob@example.com"),
        sessions=(_session("sess-acting", _ACTING_TOKEN),),
    )

    with pytest.raises(EmailAlreadyInUseError):
        _change(use_case, new_email="BOB@example.com")
    assert repository.people[0].email == EmailValueObject("ana@example.com")


def test_resaving_own_email_is_allowed() -> None:
    use_case, _, repository, _ = _build(_person(), sessions=(_session("sess-acting", _ACTING_TOKEN),))

    _change(use_case, new_email="ANA@example.com")

    assert repository.people[0].email == EmailValueObject("ana@example.com")


def test_freed_email_from_a_deleted_account_can_be_claimed() -> None:
    use_case, _, repository, _ = _build(
        _person(),
        _person(name="Old", person_id="old", email="free@example.com", status=PersonStatus.DELETED),
        sessions=(_session("sess-acting", _ACTING_TOKEN),),
    )

    _change(use_case, new_email="free@example.com")

    assert repository.people[0].email == EmailValueObject("free@example.com")


def test_other_sessions_are_purged_and_the_acting_one_survives() -> None:
    use_case, _, _, session_repository = _build(
        _person(),
        sessions=(_session("sess-acting", _ACTING_TOKEN), _session("sess-other", "token-other")),
    )

    _change(use_case, new_email="new@example.com")

    assert {s.token for s in session_repository.sessions.values()} == {_ACTING_TOKEN}


def test_another_persons_sessions_are_untouched() -> None:
    use_case, _, _, session_repository = _build(
        _person(),
        sessions=(_session("sess-acting", _ACTING_TOKEN), _session("sess-stranger", "token-stranger", "person-2")),
    )

    _change(use_case, new_email="new@example.com")

    assert {s.token for s in session_repository.sessions.values()} == {_ACTING_TOKEN, "token-stranger"}
