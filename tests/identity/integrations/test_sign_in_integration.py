import asyncio

import pytest

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.identity.application.data.sign_in_data import SignInData
from trocado.features.identity.application.data.sign_up_data import SignUpData
from trocado.features.identity.application.use_cases.sign_in_use_case import SignInUseCase
from trocado.features.identity.application.use_cases.sign_up_use_case import SignUpUseCase
from trocado.features.identity.domain.errors.invalid_credentials_error import InvalidCredentialsError
from trocado.features.identity.infrastructure.gateways.password_hasher import PasswordHasher
from trocado.features.identity.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository
from trocado.features.identity.infrastructure.repositories.session_repository import SessionRepository

_EMAIL = "ana@example.com"
_PASSWORD = "supersecret"


def _build() -> tuple[SignInUseCase, SessionRepository]:
    clock = Clock()
    hasher = PasswordHasher()
    repository = PersonRepository()
    identifier = IdentifierProvider()
    session_repository = SessionRepository()
    register = SignUpUseCase(clock=clock, hasher=hasher, repository=repository, identifier=identifier)
    asyncio.run(register.execute(SignUpData(name="Ana", email=_EMAIL, password=_PASSWORD)))
    use_case = SignInUseCase(
        clock=clock,
        hasher=hasher,
        repository=repository,
        identifier=identifier,
        token_generator=TokenGenerator(),
        session_repository=session_repository,
    )
    return use_case, session_repository


def test_real_adapters_sign_in_issues_a_session() -> None:
    use_case, session_repository = _build()

    data = asyncio.run(use_case.execute(SignInData(email=_EMAIL, password=_PASSWORD)))

    # The credential verified against a real Argon2 hash; an opaque CSPRNG token was issued and is live.
    assert data.token
    assert data.person.email == _EMAIL
    assert data.person.status == "active"
    now = asyncio.run(Clock().now())
    assert asyncio.run(session_repository.find_valid_by_token(data.token, now)) is not None


def test_real_adapters_reject_a_wrong_password() -> None:
    use_case, _ = _build()

    with pytest.raises(InvalidCredentialsError):
        asyncio.run(use_case.execute(SignInData(email=_EMAIL, password="wrongpassword")))
