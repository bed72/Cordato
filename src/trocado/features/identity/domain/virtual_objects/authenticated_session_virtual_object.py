from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.entities.session_entity import SessionEntity


@dataclass(frozen=True, slots=True)
class AuthenticatedSessionVirtualObject:
    """The result of a sign-in — a freshly issued session together with the person it authenticates.

    A Virtual Object: neither entity (no identity or lifecycle of its own) nor value object (it references
    entities and validates nothing). It exists to compose the two things a successful sign-in returns —
    the ``SessionEntity`` and its ``PersonEntity`` — into a single cohesive input, so the read-model mapper
    takes one argument instead of two loose ones. It derives nothing of its own; it surfaces the session's
    ``token`` and ``expires_at`` and holds the person for the mapper to project.
    """

    person: PersonEntity
    session: SessionEntity

    @property
    def token(self) -> str:
        """The opaque bearer token to hand back to the caller."""
        return self.session.token

    @property
    def expires_at(self) -> datetime:
        """When the issued session stops authenticating."""
        return self.session.expires_at
