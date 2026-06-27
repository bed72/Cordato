import asyncio
from datetime import UTC, datetime

from trocado.features.identity.application.data.update_name_data import UpdateNameData
from trocado.features.identity.application.use_cases.update_name_use_case import UpdateNameUseCase
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _build() -> tuple[UpdateNameUseCase, PersonRepository]:
    repository = PersonRepository()
    person = PersonEntity.create(
        id="id-1",
        password="hash",
        created_at=_FIXED_NOW,
        name=NameValueObject("Ana"),
        email=EmailValueObject("ana@example.com"),
    )
    asyncio.run(repository.create(person))

    return UpdateNameUseCase(repository=repository), repository


def test_name_change_is_reflected() -> None:
    use_case, repository = _build()

    data = asyncio.run(use_case.execute(UpdateNameData(requester_id="id-1", name="Bea")))

    assert data.name == "Bea"

    stored = asyncio.run(repository.find_active_by_id("id-1"))
    assert stored is not None
    assert stored.name == NameValueObject("Bea")


def test_identity_email_and_hash_survive_a_name_update() -> None:
    use_case, repository = _build()

    asyncio.run(use_case.execute(UpdateNameData(requester_id="id-1", name="Bea")))

    stored = asyncio.run(repository.find_active_by_id("id-1"))

    assert stored is not None
    assert stored.password == "hash"
    assert stored.created_at == _FIXED_NOW
    assert stored.email == EmailValueObject("ana@example.com")
