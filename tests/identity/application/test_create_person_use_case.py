import asyncio
from datetime import UTC, datetime

import pytest

from tests.identity.fakes.fake_clock import FakeClock
from tests.identity.fakes.fake_identifier_provider import FakeIdentifierProvider
from tests.identity.fakes.fake_password_hasher import FakePasswordHasher
from tests.identity.fakes.fake_person_repository import FakePersonRepository
from trocado.features.identity.application.data.create_person_data import CreatePersonData
from trocado.features.identity.application.use_cases.create_person_use_case import (
    CreatePersonUseCase,
)
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError
from trocado.features.identity.domain.errors.invalid_name_error import InvalidNameError
from trocado.features.identity.domain.errors.weak_password_error import WeakPasswordError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.domain.value_objects.person_status import PersonStatus

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _build_use_case(
    repository: FakePersonRepository | None = None,
    identifier: str = "id-1",
) -> tuple[CreatePersonUseCase, FakePersonRepository]:
    repository = repository or FakePersonRepository()
    use_case = CreatePersonUseCase(
        repository=repository,
        hasher=FakePasswordHasher(),
        identifier_provider=FakeIdentifierProvider(identifier),
        clock=FakeClock(_FIXED_NOW),
    )
    return use_case, repository


def _seed(repository: FakePersonRepository, email: str, status: PersonStatus, person_id: str) -> None:
    repository.people.append(
        PersonEntity(
            id=person_id,
            created_at=_FIXED_NOW,
            name=NameValueObject("Seed"),
            email=EmailValueObject(email),
            password="seed-hash",
            status=status,
        )
    )


def test_successful_creation_returns_public_active_data() -> None:
    use_case, repository = _build_use_case(identifier="new-id")

    data = asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="ana@example.com", password="12345678")))

    assert data.id == "new-id"
    assert data.name == "Ana"
    assert data.email == "ana@example.com"
    assert data.status == "active"
    assert data.created_at == _FIXED_NOW
    # PersonData carries no password field at all.
    assert not hasattr(data, "password")
    assert not hasattr(data, "password_hash")
    assert len(repository.people) == 1


def test_stored_password_is_a_hash_not_plaintext() -> None:
    use_case, repository = _build_use_case()

    asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="ana@example.com", password="plaintext1")))

    stored = repository.people[0].password
    assert stored != "plaintext1"
    assert stored.startswith("hashed::")  # the fake hasher's marker


def test_duplicate_active_email_is_rejected() -> None:
    repository = FakePersonRepository()
    _seed(repository, "ana@example.com", PersonStatus.ACTIVE, "existing")
    use_case, _ = _build_use_case(repository)

    with pytest.raises(EmailAlreadyInUseError):
        asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="ANA@example.com", password="12345678")))
    assert len(repository.people) == 1


def test_freed_email_can_be_reused_as_new_person() -> None:
    repository = FakePersonRepository()
    _seed(repository, "ana@example.com", PersonStatus.DELETED, "old")
    use_case, _ = _build_use_case(repository, identifier="brand-new")

    data = asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="ana@example.com", password="12345678")))

    assert data.id == "brand-new"
    assert len(repository.people) == 2


def test_normalized_email_feeds_uniqueness_check() -> None:
    repository = FakePersonRepository()
    use_case, _ = _build_use_case(repository)

    asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="  Ana@Example.COM ", password="12345678")))
    with pytest.raises(EmailAlreadyInUseError):
        asyncio.run(use_case.execute(CreatePersonData(name="Bob", email="ana@example.com", password="12345678")))


def test_malformed_email_is_rejected() -> None:
    use_case, repository = _build_use_case()
    with pytest.raises(InvalidEmailError):
        asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="nope", password="12345678")))
    assert repository.people == []


def test_weak_password_is_rejected() -> None:
    use_case, repository = _build_use_case()
    with pytest.raises(WeakPasswordError):
        asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="ana@example.com", password="short")))
    assert repository.people == []


def test_blank_name_is_rejected() -> None:
    use_case, repository = _build_use_case()
    with pytest.raises(InvalidNameError):
        asyncio.run(use_case.execute(CreatePersonData(name="   ", email="ana@example.com", password="12345678")))
    assert repository.people == []
