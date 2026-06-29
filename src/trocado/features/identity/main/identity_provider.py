from __future__ import annotations

from litestar import Request
from litestar.di import NamedDependency, Provide

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.identity.application.interfaces.person_repository_interface import PersonRepositoryInterface
from trocado.features.identity.application.interfaces.session_repository_interface import SessionRepositoryInterface
from trocado.features.identity.application.use_cases.validate_session_use_case import ValidateSessionUseCase
from trocado.features.identity.infrastructure.http.providers.current_person_provider import CurrentPersonProvider
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository
from trocado.features.identity.infrastructure.repositories.session_repository import SessionRepository


def register_identity_providers() -> dict[str, Provide]:
    """Build the cross-cutting auth DI providers to register at the /v1 router level.

    ``CurrentPersonProvider`` (also registered at /v1) calls ``ValidateSessionUseCase``, which needs
    ``person_repository`` and ``session_repository``. Those must therefore be visible in the /v1 DI scope
    (not just inside the identity router) so any protected route can resolve ``current_person_provider``
    correctly.

    The identity router's use cases inherit the repositories from this /v1-level scope via DI — no direct
    hand-off needed. A fresh call to this function (e.g. inside ``build()``) produces fresh singletons,
    keeping each ``build()`` call fully isolated (test-friendly).
    """
    person_repository = PersonRepository()
    session_repository = SessionRepository()

    async def provide_person_repository() -> PersonRepositoryInterface:
        return person_repository

    async def provide_session_repository() -> SessionRepositoryInterface:
        return session_repository

    async def provide_validate_session(
        clock: NamedDependency[ClockInterface],
        person_repository: NamedDependency[PersonRepositoryInterface],
        session_repository: NamedDependency[SessionRepositoryInterface],
    ) -> ValidateSessionUseCase:
        return ValidateSessionUseCase(
            clock=clock,
            repository=person_repository,
            session_repository=session_repository,
        )

    async def provide_current_person(
        request: Request,  # type: ignore[type-arg]
        validate_session: NamedDependency[ValidateSessionUseCase],
    ) -> CurrentPersonProvider:
        return CurrentPersonProvider(request, validate_session)

    return {
        "validate_session": Provide(provide_validate_session),
        "person_repository": Provide(provide_person_repository),
        "session_repository": Provide(provide_session_repository),
        "current_person_provider": Provide(provide_current_person),
    }
