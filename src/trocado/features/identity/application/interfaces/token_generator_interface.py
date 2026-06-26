from __future__ import annotations

from abc import ABC, abstractmethod


class TokenGeneratorInterface(ABC):
    """Port for minting a session's opaque bearer token.

    Why it exists: the token must come from a cryptographically secure source (a CSPRNG), and the pure domain
    must never reach for such a source directly — that would make entities non-deterministic and untestable.
    The sign-in use case obtains the token from this port and passes it into the session factory; tests inject
    a fake that yields a known token, production injects the CSPRNG-backed adapter.

    Identity owns its own token generator — there is no ``shared/``; the ``pairing`` context has a sibling port
    for its invite codes, mirrored here rather than imported across contexts.

    Async **by contract**: the in-process adapter does no I/O today, but declaring it async honors the
    async-maybe-I/O contract so a future external token service slots in behind the same contract.

    Implementors (adapters in ``infrastructure/gateways/``):
        - MUST draw from a CSPRNG — never a predictable, sequential, or time-derived source.
        - MUST return a URL-safe ``str``; each call yields a freshly generated token.
    """

    @abstractmethod
    async def generate(self) -> str:
        """Return a fresh, URL-safe token drawn from a cryptographic source."""
        raise NotImplementedError
