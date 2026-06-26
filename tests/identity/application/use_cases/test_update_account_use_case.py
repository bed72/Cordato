import asyncio
from datetime import UTC, datetime

import pytest

from tests.identity.fakes.fake_person_repository import FakePersonRepository
from trocado.features.identity.application.data.update_account_data import UpdateAccountData
from trocado.features.identity.application.use_cases.update_account_use_case import (
    UpdateAccountUseCase,
)
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError
from trocado.features.identity.domain.errors.invalid_name_error import InvalidNameError
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _person(person_id: str, email: str, name: str = "Ana", status: PersonStatus = PersonStatus.ACTIVE) -> PersonEntity:
    return PersonEntity(
        id=person_id,
        status=status,
        password="seed-hash",
        created_at=_FIXED_NOW,
        name=NameValueObject(name),
        email=EmailValueObject(email),
    )


def _build_use_case(*people: PersonEntity) -> tuple[UpdateAccountUseCase, FakePersonRepository]:
    repository = FakePersonRepository(*people)
    return UpdateAccountUseCase(repository=repository), repository


def test_updates_name_and_email_returns_public_data() -> None:
    use_case, repository = _build_use_case(_person("id-1", "ana@example.com"))

    data = asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="Bea", email="bea@example.com")))

    assert data.id == "id-1"
    assert data.name == "Bea"
    assert data.status == "active"
    assert not hasattr(data, "password")
    assert data.created_at == _FIXED_NOW
    assert data.email == "bea@example.com"
    assert not hasattr(data, "password_hash")
    assert repository.people[0].email == EmailValueObject("bea@example.com")


def test_name_only_change_resubmitting_own_email_is_accepted() -> None:
    use_case, repository = _build_use_case(_person("id-1", "ana@example.com"))

    data = asyncio.run(
        use_case.execute(UpdateAccountData(requester_id="id-1", name="Ana Maria", email="ana@example.com"))
    )

    assert data.name == "Ana Maria"
    assert data.email == "ana@example.com"


def test_email_change_to_a_free_email_succeeds() -> None:
    use_case, _ = _build_use_case(_person("id-1", "ana@example.com"))

    data = asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="Ana", email="  New@Example.COM ")))

    # The new email is normalized before storage.
    assert data.email == "new@example.com"


def test_email_held_by_another_active_person_is_rejected() -> None:
    use_case, repository = _build_use_case(
        _person("id-1", "ana@example.com"),
        _person("id-2", "bob@example.com", name="Bob"),
    )

    with pytest.raises(EmailAlreadyInUseError):
        asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="Ana", email="BOB@example.com")))
    # Nothing changed.
    assert repository.people[0].email == EmailValueObject("ana@example.com")


def test_resaving_own_email_does_not_self_collide() -> None:
    use_case, _ = _build_use_case(_person("id-1", "ana@example.com"))

    data = asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="Ana", email="ANA@example.com")))

    assert data.email == "ana@example.com"


def test_freed_email_from_a_deleted_account_can_be_claimed() -> None:
    use_case, _ = _build_use_case(
        _person("id-1", "ana@example.com"),
        _person("old", "free@example.com", status=PersonStatus.DELETED),
    )

    data = asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="Ana", email="free@example.com")))

    assert data.email == "free@example.com"


def test_malformed_email_is_rejected() -> None:
    use_case, repository = _build_use_case(_person("id-1", "ana@example.com"))

    with pytest.raises(InvalidEmailError):
        asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="Ana", email="nope")))
    assert repository.people[0].email == EmailValueObject("ana@example.com")


def test_blank_name_is_rejected() -> None:
    use_case, repository = _build_use_case(_person("id-1", "ana@example.com"))

    with pytest.raises(InvalidNameError):
        asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="   ", email="ana@example.com")))
    assert repository.people[0].name == NameValueObject("Ana")


def test_unknown_requester_is_rejected() -> None:
    use_case, _ = _build_use_case(_person("id-1", "ana@example.com"))

    with pytest.raises(InvalidSessionError):
        asyncio.run(use_case.execute(UpdateAccountData(requester_id="ghost", name="Ana", email="ana@example.com")))


def test_non_active_requester_is_rejected() -> None:
    use_case, _ = _build_use_case(_person("gone", "gone@example.com", status=PersonStatus.DELETED))

    with pytest.raises(InvalidSessionError):
        asyncio.run(use_case.execute(UpdateAccountData(requester_id="gone", name="Ana", email="new@example.com")))
