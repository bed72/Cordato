from __future__ import annotations

from litestar.di import Provide

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider


def register_core_providers() -> dict[str, Provide]:
    """Contribute the shared-kernel gateway providers — once, for the whole application.

    The clock and identifier provider are **cross-cutting**: every feature (budgeting, identity, pairing,
    expenses) drives its entities' ``created_at`` and ``id`` through these same ports. They are stateless, so a
    single **app-scoped instance** serves every request — built here and closed over by its provider, so each
    request resolves the very same object. Returns the ``Provide`` mapping the composition root merges into the
    Litestar app's ``dependencies`` before any feature's; a feature factory never re-contributes the core ports.
    """
    clock = Clock()
    identifier = IdentifierProvider()

    async def provide_clock() -> ClockInterface:
        return clock

    async def provide_identifier() -> IdentifierProviderInterface:
        return identifier

    return {
        "clock": Provide(provide_clock),
        "identifier": Provide(provide_identifier),
    }
