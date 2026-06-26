from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

# A session stays valid for thirty days after it is issued — long-lived, as a mobile app expects. This is a
# domain rule, fixed here and derived by `create`; the caller never supplies the expiry.
SESSION_TIME_TO_LIVE = timedelta(days=30)


@dataclass(eq=False, slots=True)
class SessionEntity:
    """A server-side session: the proof that a person signed in, presented as an opaque bearer token.

    Issued at sign-in, validated by token on each authenticated request, and revoked at sign-out. The
    ``token`` is an opaque CSPRNG secret (a plain ``str``, not a value object — no invariant, no behavior),
    deliberately distinct from the time-ordered ``id`` so the bearer credential is unguessable. ``expires_at``
    is fixed at ``SESSION_TIME_TO_LIVE`` past ``created_at`` by ``create``; ``revoked_at`` is null until a
    sign-out stamps it. A session is *live* when it is neither revoked nor past its expiry — validity is
    computed from these two facts, never stored as a flag.
    """

    id: str
    token: str  # opaque, unpredictable CSPRNG secret — the bearer credential, distinct from `id`
    person_id: str  # the owner's opaque id; the domain never inspects it
    created_at: datetime
    expires_at: datetime
    revoked_at: datetime | None  # null = live; no default — only `create(...)` may birth a live session

    @classmethod
    def create(
        cls,
        *,
        id: str,
        token: str,
        person_id: str,
        created_at: datetime,
    ) -> SessionEntity:
        """Issue a brand-new, live session — the only sanctioned way to be born.

        The expiry is derived from ``created_at`` plus the fixed time-to-live; the caller cannot influence it.
        """
        return cls(
            id=id,
            token=token,
            revoked_at=None,
            person_id=person_id,
            created_at=created_at,
            expires_at=created_at + SESSION_TIME_TO_LIVE,
        )

    def is_live(self, reference: datetime) -> bool:
        """Whether the session still authenticates at ``reference``: not revoked and not yet expired.

        ``expires_at`` itself counts as expired (the window is exclusive on the far end).
        """
        return self.revoked_at is None and reference < self.expires_at

    def revoke(self, at: datetime) -> None:
        """Stamp the revocation instant, ending the session. The only path out of the live state."""
        self.revoked_at = at

    # Identity equality: a session IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, SessionEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
