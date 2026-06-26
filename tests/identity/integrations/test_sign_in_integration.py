import asyncio

import pytest

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.identity.application.data.create_person_data import CreatePersonData
from trocado.features.identity.application.data.sign_in_data import SignInData
from trocado.features.identity.application.use_cases.create_person_use_case import CreatePersonUseCase
from trocado.features.identity.application.use_cases.sign_in_use_case import SignInUseCase
from trocado.features.identity.domain.errors.invalid_credentials_error import InvalidCredentialsError
from trocado.features.identity.infrastructure.gateways.password_hasher import PasswordHasher
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository

_EMAIL = "ana@example.com"
_PASSWORD = "supersecret"


def _build() -> tuple[SignInUseCase, PersonRepository]:
    repository = PersonRepository()
    hasher = PasswordHasher()
    register = CreatePersonUseCase(
        clock=Clock(),
        repository=repository,
        hasher=hasher,
        identifier=IdentifierProvider(),
    )
    asyncio.run(register.execute(CreatePersonData(name="Ana", email=_EMAIL, password=_PASSWORD)))
    return SignInUseCase(hasher=hasher, repository=repository), repository


def test_real_adapters_sign_in_a_registered_person() -> None:
    use_case, _ = _build()

    data = asyncio.run(use_case.execute(SignInData(email=_EMAIL, password=_PASSWORD)))

    # The credential verified against a real Argon2 hash and returned the public read-model (no password field).
    assert len(data.id) == 36
    assert data.email == _EMAIL
    assert data.status == "active"


def test_real_adapters_reject_a_wrong_password() -> None:
    use_case, _ = _build()

    with pytest.raises(InvalidCredentialsError):
        asyncio.run(use_case.execute(SignInData(email=_EMAIL, password="wrongpassword")))
