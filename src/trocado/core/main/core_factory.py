from __future__ import annotations

from rodi import Container

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider


def register_core(container: Container) -> None:
    """Wire the shared-kernel gateways into the Rodi container — once, for the whole application.

    The clock and identifier provider are **cross-cutting**: every feature (budgeting, identity, pairing,
    expenses) drives its entities' ``created_at`` and ``id`` through these same ports. They are stateless, so a
    single **app-scoped instance** serves every request of every feature. Registering them here — called once at
    the composition root before any feature factory — keeps that registration in one place: a feature factory
    owns only its own object graph and never re-registers core ports (which would duplicate the binding).
    """
    container.add_instance(Clock(), ClockInterface)
    container.add_instance(IdentifierProvider(), IdentifierProviderInterface)
