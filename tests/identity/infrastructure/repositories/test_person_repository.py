import asyncio
from datetime import UTC, datetime

from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.domain.value_objects.person_status import PersonStatus
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository

_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _person(person_id: str, email: str, status: PersonStatus = PersonStatus.ACTIVE) -> PersonEntity:
    return PersonEntity(
        id=person_id,
        created_at=_NOW,
        name=NameValueObject("Ana"),
        email=EmailValueObject(email),
        password="hash",
        status=status,
    )


def test_create_then_find_returns_the_same_person() -> None:
    repository = PersonRepository()
    person = _person("id-1", "ana@example.com")

    asyncio.run(repository.create(person))

    found = asyncio.run(repository.find_active_by_email(EmailValueObject("ana@example.com")))
    assert found is person


def test_find_returns_none_when_absent() -> None:
    repository = PersonRepository()
    assert asyncio.run(repository.find_active_by_email(EmailValueObject("ghost@example.com"))) is None


def test_find_ignores_non_active_accounts() -> None:
    repository = PersonRepository()
    asyncio.run(repository.create(_person("old", "ana@example.com", PersonStatus.DELETED)))

    # A deleted account holding the email must not be found — this is the repository's own responsibility.
    assert asyncio.run(repository.find_active_by_email(EmailValueObject("ana@example.com"))) is None


def test_find_matches_by_normalized_email() -> None:
    repository = PersonRepository()
    asyncio.run(repository.create(_person("id-1", "  Ana@Example.COM ")))

    found = asyncio.run(repository.find_active_by_email(EmailValueObject("ana@example.com")))
    assert found is not None
    assert found.id == "id-1"
