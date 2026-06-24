from __future__ import annotations

from uuid import uuid7

from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)


class IdentifierProvider(IdentifierProviderInterface):
    """Generates time-ordered UUIDv7 identifiers (stdlib, Python 3.14) for good index locality."""

    async def generate(self) -> str:
        return str(uuid7())
