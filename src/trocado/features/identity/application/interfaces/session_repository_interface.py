from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime

from trocado.features.identity.domain.entities.session_entity import SessionEntity


class SessionRepositoryInterface(ABC):
    """Persistence port for sessions — issue, look up the live one by token, and revoke.

    Validity is the repository's responsibility, exactly as soft-delete/active filtering is elsewhere: a
    normal read surfaces only a *live* session (not revoked, not expired), so the use cases never re-filter
    revoked or expired rows. The expiry boundary is evaluated against a ``now`` passed in by the caller (from
    the clock port) rather than read inside the adapter, keeping the adapter deterministic under test.

    Async **by contract**: the in-memory adapter does no I/O today, but the contract is async so the ORM-backed
    adapter slots in behind it with no ripple inward.
    """

    @abstractmethod
    async def create(self, session: SessionEntity) -> None:
        """Persist a newly issued session."""
        raise NotImplementedError

    @abstractmethod
    async def find_valid_by_token(self, token: str, now: datetime) -> SessionEntity | None:
        """Return the live session matching ``token`` at ``now``, or ``None``.

        Live means the token matches, ``revoked_at`` is null, and ``now`` is before ``expires_at``. An
        unknown, revoked, or expired token all return ``None`` — the caller cannot tell which.
        """
        raise NotImplementedError

    @abstractmethod
    async def revoke(self, session: SessionEntity) -> None:
        """Persist the revoked state of a session (its ``revoked_at`` was just stamped)."""
        raise NotImplementedError

    @abstractmethod
    async def purge_for_person(self, person_id: str) -> None:
        """Physically remove **all** of the person's sessions, irrespective of validity.

        Used by account deletion to ensure no token issued before the deletion keeps resolving. Unlike
        ``find_valid_by_token``, it ignores revoked/expired state and clears live and dead rows alike, so it
        needs no ``now``. It is **idempotent**: a person with no sessions is a no-op, never an error.
        """
        raise NotImplementedError

    @abstractmethod
    async def purge_for_person_except(self, person_id: str, keep_token: str) -> None:
        """Physically remove **all** of the person's sessions **except** the one bearing ``keep_token``.

        The all-except-one sibling of ``purge_for_person``: used by a password change to drop every other
        token (any pre-rotation or stolen credential stops resolving) while the acting session — the one the
        request was made on — stays live. Like ``purge_for_person``, it ignores validity (live, revoked, or
        expired alike) and needs no ``now``, touches only this person's sessions, and is **idempotent**: a
        person whose only session is the kept one is a valid no-op.
        """
        raise NotImplementedError
