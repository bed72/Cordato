from __future__ import annotations

from abc import ABC, abstractmethod


class TokenGeneratorInterface(ABC):
    """Port for minting the invite code's short, unpredictable token.

    Why it exists: the token must come from a cryptographically secure source (a CSPRNG), and the pure
    domain must never reach for such a source directly — that would make entities non-deterministic and
    untestable. A use case obtains the token from this port and passes it into the entity factory; tests
    inject a fake that yields a known token, production injects the CSPRNG-backed adapter.

    Async **by contract**: the in-process adapter does no I/O today, but declaring it async honors the
    async-maybe-I/O contract of the project's ports, so the day this becomes a genuine external token
    service it slots in behind the same contract with no ripple inward.

    Implementors (adapters in ``infrastructure/gateways/``):
        - MUST draw from a CSPRNG — never a predictable, sequential, or time-derived source.
        - MUST return a short, URL-safe ``str``; each call yields a freshly generated token.
    """

    @abstractmethod
    async def generate(self) -> str:
        """Return a fresh, short, URL-safe token drawn from a cryptographic source."""
        raise NotImplementedError
