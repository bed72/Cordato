import asyncio
from datetime import UTC, datetime

from trocado.features.identity.application.data.update_account_data import UpdateAccountData
from trocado.features.identity.application.use_cases.update_account_use_case import (
    UpdateAccountUseCase,
)
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _build() -> tuple[UpdateAccountUseCase, PersonRepository]:
    repository = PersonRepository()
    person = PersonEntity.create(
        id="id-1",
        password="hash",
        created_at=_FIXED_NOW,
        name=NameValueObject("Ana"),
        email=EmailValueObject("ana@example.com"),
    )
    asyncio.run(repository.create(person))

    return UpdateAccountUseCase(repository=repository), repository


def test_email_change_is_reflected_and_old_address_freed() -> None:
    use_case, repository = _build()

    data = asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="Ana", email="new@example.com")))

    assert data.email == "new@example.com"

    by_new = asyncio.run(repository.find_active_by_email(EmailValueObject("new@example.com")))
    by_old = asyncio.run(repository.find_active_by_email(EmailValueObject("ana@example.com")))

    # The new address resolves to the same person; the old one now reads as available.
    assert by_new is not None
    assert by_new.id == "id-1"
    assert by_old is None


def test_identity_and_hash_survive_a_account_update() -> None:
    use_case, repository = _build()

    asyncio.run(use_case.execute(UpdateAccountData(requester_id="id-1", name="Bea", email="bea@example.com")))

    stored = asyncio.run(repository.find_active_by_id("id-1"))

    assert stored is not None
    assert stored.password == "hash"
    assert stored.created_at == _FIXED_NOW
    assert stored.name == NameValueObject("Bea")
