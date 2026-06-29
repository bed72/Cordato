from __future__ import annotations

from litestar import Router
from litestar.di import NamedDependency, Provide

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import IdentifierProviderInterface
from trocado.core.infrastructure.http.errors.handlers.exception_handlers import build_domain_exception_handlers
from trocado.core.infrastructure.http.errors.lookups.core_status_error import CORE_STATUS_ERROR
from trocado.features.identity.application.interfaces.password_hasher_interface import PasswordHasherInterface
from trocado.features.identity.application.interfaces.person_repository_interface import PersonRepositoryInterface
from trocado.features.identity.application.interfaces.session_repository_interface import SessionRepositoryInterface
from trocado.features.identity.application.interfaces.token_generator_interface import TokenGeneratorInterface
from trocado.features.identity.application.use_cases.sign_in_use_case import SignInUseCase
from trocado.features.identity.application.use_cases.sign_out_use_case import SignOutUseCase
from trocado.features.identity.application.use_cases.sign_up_use_case import SignUpUseCase
from trocado.features.identity.infrastructure.gateways.password_hasher import PasswordHasher
from trocado.features.identity.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.identity.infrastructure.http.controllers.authentication_controller import (
    AuthenticationController,
)
from trocado.features.identity.infrastructure.http.errors.lookups.identity_status_error import IDENTITY_STATUS_ERROR


def register_identity_router() -> Router:
    """Build identity's web slice — authentication routes with their scoped DI providers.

    The repositories (``person_repository``, ``session_repository``) are inherited from the /v1 parent scope
    via DI (registered by ``register_identity_providers``), so the sign-up/sign-in/sign-out use cases operate
    on the same in-memory stores that ``validate_session`` reads from. This avoids a split-brain where two
    separate singletons serve different paths of the same request.

    Only the identity-specific gateways (``PasswordHasher``, ``TokenGenerator``) and use cases are scoped to
    this router; the repositories and ``validate_session`` are inherited from the /v1 parent scope.
    """
    password_hasher = PasswordHasher()
    token_generator = TokenGenerator()

    async def provide_password_hasher() -> PasswordHasherInterface:
        return password_hasher

    async def provide_token_generator() -> TokenGeneratorInterface:
        return token_generator

    async def provide_sign_up_use_case(
        clock: NamedDependency[ClockInterface],
        identifier: NamedDependency[IdentifierProviderInterface],
        password_hasher: NamedDependency[PasswordHasherInterface],
        person_repository: NamedDependency[PersonRepositoryInterface],
    ) -> SignUpUseCase:
        return SignUpUseCase(
            clock=clock,
            identifier=identifier,
            hasher=password_hasher,
            repository=person_repository,
        )

    async def provide_sign_in_use_case(
        clock: NamedDependency[ClockInterface],
        identifier: NamedDependency[IdentifierProviderInterface],
        password_hasher: NamedDependency[PasswordHasherInterface],
        token_generator: NamedDependency[TokenGeneratorInterface],
        person_repository: NamedDependency[PersonRepositoryInterface],
        session_repository: NamedDependency[SessionRepositoryInterface],
    ) -> SignInUseCase:
        return SignInUseCase(
            clock=clock,
            identifier=identifier,
            hasher=password_hasher,
            token_generator=token_generator,
            person_repository=person_repository,
            session_repository=session_repository,
        )

    async def provide_sign_out_use_case(
        clock: NamedDependency[ClockInterface],
        session_repository: NamedDependency[SessionRepositoryInterface],
    ) -> SignOutUseCase:
        return SignOutUseCase(clock=clock, session_repository=session_repository)

    return Router(
        path="/",
        route_handlers=[AuthenticationController],
        dependencies={
            "password_hasher": Provide(provide_password_hasher),
            "token_generator": Provide(provide_token_generator),
            "sign_up_use_case": Provide(provide_sign_up_use_case),
            "sign_in_use_case": Provide(provide_sign_in_use_case),
            "sign_out_use_case": Provide(provide_sign_out_use_case),
        },
        exception_handlers=build_domain_exception_handlers({**CORE_STATUS_ERROR, **IDENTITY_STATUS_ERROR}),
    )
