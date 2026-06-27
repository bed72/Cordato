import asyncio
from datetime import UTC, datetime

import pytest

from tests.identity.fakes.fake_person_repository import FakePersonRepository
from trocado.features.identity.application.data.update_name_data import UpdateNameData
from trocado.features.identity.application.use_cases.update_name_use_case import UpdateNameUseCase
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
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


def _build_use_case(*people: PersonEntity) -> tuple[UpdateNameUseCase, FakePersonRepository]:
    repository = FakePersonRepository(*people)
    return UpdateNameUseCase(repository=repository), repository


def test_updates_name_returns_public_data() -> None:
    use_case, repository = _build_use_case(_person("id-1", "ana@example.com"))

    data = asyncio.run(use_case.execute(UpdateNameData(requester_id="id-1", name="Bea")))

    assert data.id == "id-1"
    assert data.name == "Bea"
    assert data.status == "active"
    assert not hasattr(data, "password")
    assert data.created_at == _FIXED_NOW
    assert data.email == "ana@example.com"
    assert not hasattr(data, "password_hash")
    assert repository.people[0].name == NameValueObject("Bea")


def test_email_and_credentials_are_untouched() -> None:
    use_case, repository = _build_use_case(_person("id-1", "ana@example.com"))

    asyncio.run(use_case.execute(UpdateNameData(requester_id="id-1", name="Bea")))

    stored = repository.people[0]
    assert stored.password == "seed-hash"
    assert stored.email == EmailValueObject("ana@example.com")


def test_blank_name_is_rejected() -> None:
    use_case, repository = _build_use_case(_person("id-1", "ana@example.com"))

    with pytest.raises(InvalidNameError):
        asyncio.run(use_case.execute(UpdateNameData(requester_id="id-1", name="   ")))
    assert repository.people[0].name == NameValueObject("Ana")


def test_unknown_requester_is_rejected() -> None:
    use_case, _ = _build_use_case(_person("id-1", "ana@example.com"))

    with pytest.raises(InvalidSessionError):
        asyncio.run(use_case.execute(UpdateNameData(requester_id="ghost", name="Ana")))


def test_non_active_requester_is_rejected() -> None:
    use_case, _ = _build_use_case(_person("gone", "gone@example.com", status=PersonStatus.DELETED))

    with pytest.raises(InvalidSessionError):
        asyncio.run(use_case.execute(UpdateNameData(requester_id="gone", name="Ana")))
