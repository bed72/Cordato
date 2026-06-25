import asyncio

import pytest

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.identity.application.data.create_person_data import CreatePersonData
from trocado.features.identity.application.use_cases.create_person_use_case import (
    CreatePersonUseCase,
)
from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.infrastructure.gateways.password_hasher import PasswordHasher
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository


def _build() -> tuple[CreatePersonUseCase, PersonRepository]:
    repository = PersonRepository()
    use_case = CreatePersonUseCase(
        clock=Clock(),
        repository=repository,
        hasher=PasswordHasher(),
        identifier=IdentifierProvider(),
    )

    return use_case, repository


def test_real_adapters_create_a_person() -> None:
    use_case, repository = _build()

    data = asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="ana@example.com", password="supersecret")))

    # A real uuid7 string id (canonical 36-char form).
    assert len(data.id) == 36
    assert data.status == "active"
    assert data.email == "ana@example.com"

    stored = asyncio.run(repository.find_active_by_email(EmailValueObject("ana@example.com")))

    assert stored is not None
    assert "supersecret" not in stored.password
    # A real Argon2 hash — argon2 marker, never the plaintext.
    assert stored.password.startswith("$argon2")


def test_real_adapters_reject_duplicate_email() -> None:
    use_case, _ = _build()
    asyncio.run(use_case.execute(CreatePersonData(name="Ana", email="ana@example.com", password="supersecret")))

    with pytest.raises(EmailAlreadyInUseError):
        asyncio.run(use_case.execute(CreatePersonData(name="Bob", email="ANA@example.com", password="supersecret")))
