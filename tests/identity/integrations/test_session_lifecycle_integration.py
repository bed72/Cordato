import asyncio

import pytest

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.identity.application.data.sign_in_data import SignInData
from trocado.features.identity.application.data.sign_out_data import SignOutData
from trocado.features.identity.application.data.sign_up_data import SignUpData
from trocado.features.identity.application.use_cases.sign_in_use_case import SignInUseCase
from trocado.features.identity.application.use_cases.sign_out_use_case import SignOutUseCase
from trocado.features.identity.application.use_cases.sign_up_use_case import SignUpUseCase
from trocado.features.identity.application.use_cases.validate_session_use_case import (
    ValidateSessionUseCase,
)
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError
from trocado.features.identity.infrastructure.gateways.password_hasher import PasswordHasher
from trocado.features.identity.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository
from trocado.features.identity.infrastructure.repositories.session_repository import SessionRepository

_PASSWORD = "supersecret"
_EMAIL = "ana@example.com"


def _wiring() -> tuple[SignInUseCase, ValidateSessionUseCase, SignOutUseCase]:
    clock = Clock()
    hasher = PasswordHasher()
    identifier = IdentifierProvider()
    person_repository = PersonRepository()
    session_repository = SessionRepository()

    sign_up = SignUpUseCase(clock=clock, hasher=hasher, repository=person_repository, identifier=identifier)
    asyncio.run(sign_up.execute(SignUpData(name="Ana", email=_EMAIL, password=_PASSWORD)))

    sign_in = SignInUseCase(
        clock=clock,
        hasher=hasher,
        identifier=identifier,
        person_repository=person_repository,
        token_generator=TokenGenerator(),
        session_repository=session_repository,
    )
    validate = ValidateSessionUseCase(
        clock=clock,
        repository=person_repository,
        session_repository=session_repository,
    )
    sign_out = SignOutUseCase(clock=clock, session_repository=session_repository)
    return sign_in, validate, sign_out


def test_real_adapters_run_the_full_session_arc() -> None:
    sign_in, validate, sign_out = _wiring()

    # Sign in → a real, opaque CSPRNG token is issued.
    session = asyncio.run(sign_in.execute(SignInData(email=_EMAIL, password=_PASSWORD)))
    assert session.token
    assert session.person.email == _EMAIL

    # The token validates to the person.
    validated = asyncio.run(validate.execute(session.token))
    assert validated.email == _EMAIL

    # Sign out revokes it; the same token no longer validates.
    asyncio.run(sign_out.execute(SignOutData(token=session.token)))
    with pytest.raises(InvalidSessionError):
        asyncio.run(validate.execute(session.token))


def test_two_sign_ins_yield_distinct_tokens() -> None:
    sign_in, _, _ = _wiring()

    first = asyncio.run(sign_in.execute(SignInData(email=_EMAIL, password=_PASSWORD)))
    second = asyncio.run(sign_in.execute(SignInData(email=_EMAIL, password=_PASSWORD)))

    assert first.token != second.token
