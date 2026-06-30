from __future__ import annotations

from litestar.di import Provide

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.core.infrastructure.persistence.database import (
    AsyncSessionMaker,
    provide_database_session,
    session_factory,
)


def register_core_providers() -> dict[str, Provide]:
    """Contribute the shared-kernel gateway providers — once, for the whole application.

    The clock and identifier provider are **cross-cutting**: every feature (budgeting, identity, pairing,
    expenses) drives its entities' ``created_at`` and ``id`` through these same ports. They are stateless, so a
    single **app-scoped instance** serves every request — built here and closed over by its provider, so each
    request resolves the very same object. Returns the ``Provide`` mapping the composition root merges into the
    Litestar app's ``dependencies`` before any feature's; a feature factory never re-contributes the core ports.

    ``db_session_factory`` is the app-scoped ``async_sessionmaker`` singleton; ``db_session`` is the per-request
    ``AsyncSession`` provider that uses it — open for the duration of the request, closed automatically after.
    """
    clock = Clock()
    identifier = IdentifierProvider()

    async def provide_clock() -> ClockInterface:
        return clock

    async def provide_identifier() -> IdentifierProviderInterface:
        return identifier

    async def provide_session_factory() -> AsyncSessionMaker:
        return session_factory

    return {
        "clock": Provide(provide_clock),
        "identifier": Provide(provide_identifier),
        "db_session_factory": Provide(provide_session_factory),
        "db_session": Provide(provide_database_session),
    }
