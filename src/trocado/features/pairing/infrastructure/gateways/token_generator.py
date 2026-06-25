from __future__ import annotations

import asyncio
import secrets

from trocado.features.pairing.application.interfaces.token_generator_interface import (
    TokenGeneratorInterface,
)

# Bytes of entropy per token. 8 bytes → a ~11-char URL-safe string: short enough to share, with 64 bits
# of entropy making collisions and guessing astronomically unlikely.
_ENTROPY_BYTES = 8


class TokenGenerator(TokenGeneratorInterface):
    """CSPRNG-backed token generator. The stdlib call is synchronous, so it runs off the event loop."""

    async def generate(self) -> str:
        return await asyncio.to_thread(secrets.token_urlsafe, _ENTROPY_BYTES)
