from __future__ import annotations

import asyncio
import secrets

from trocado.features.identity.application.interfaces.token_generator_interface import (
    TokenGeneratorInterface,
)

# Bytes of entropy per session token. 32 bytes → a ~43-char URL-safe string with 256 bits of entropy: a
# long-lived bearer secret should be far harder to guess than a short, single-use invite code.
_ENTROPY_BYTES = 32


class TokenGenerator(TokenGeneratorInterface):
    """CSPRNG-backed session-token generator. The stdlib call is synchronous, so it runs off the event loop."""

    async def generate(self) -> str:
        return await asyncio.to_thread(secrets.token_urlsafe, _ENTROPY_BYTES)
