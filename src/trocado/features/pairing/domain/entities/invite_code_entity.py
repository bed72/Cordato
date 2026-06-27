from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

# The single-use invite's time-to-live: a code is redeemable for one day after it is minted.
# This is a domain rule, fixed here — never supplied by the caller.
_TIME_TO_LIVE = timedelta(days=1)


@dataclass(eq=False, slots=True)
class InviteCodeEntity:
    """A single-use invite a person mints so a partner can later redeem it and form the pair.

    It owns no money and points only to its creator. The ``code`` is an opaque CSPRNG token (a plain
    ``str``, not a value object — it carries no invariant and no behavior). ``expires_at`` is fixed one
    day past ``created_at`` by ``create``; ``consumed_at`` is null until the code is redeemed (which is
    the accept-invite capability's job, not this one's). ``revoked_at`` is null until the creator kills the
    code (the revoke-invite capability) — a distinct exit from ``consumed_at``: consumed means a pair was
    formed, revoked means the creator cancelled it. The lifecycle is ``created → (consumed | revoked | expired)``.
    """

    id: str
    code: str  # opaque, unpredictable CSPRNG token
    creator_id: str  # the minter's opaque id; the domain never inspects it
    created_at: datetime
    expires_at: datetime
    revoked_at: datetime | None  # null = not revoked; stamped when the creator kills the code
    consumed_at: datetime | None  # null = unused; no default — only `create(...)` may birth a live code

    @classmethod
    def create(
        cls,
        *,
        id: str,
        code: str,
        creator_id: str,
        created_at: datetime,
    ) -> InviteCodeEntity:
        """Mint a brand-new, unconsumed invite code — the only sanctioned way to be born.

        The expiry is derived from ``created_at`` plus the fixed time-to-live; the caller cannot
        influence it.
        """
        return cls(
            id=id,
            code=code,
            revoked_at=None,
            consumed_at=None,
            creator_id=creator_id,
            created_at=created_at,
            expires_at=created_at + _TIME_TO_LIVE,
        )

    @property
    def is_consumed(self) -> bool:
        """Whether the code has already been redeemed — single-use is final."""
        return self.consumed_at is not None

    @property
    def is_revoked(self) -> bool:
        """Whether the creator has killed the code — a revoked code is no longer redeemable."""
        return self.revoked_at is not None

    def is_expired(self, reference: datetime) -> bool:
        """Whether the code is past its window at ``reference`` (``expires_at`` itself counts as expired)."""
        return reference >= self.expires_at

    def consume(self, at: datetime) -> None:
        """Stamp the redemption instant, marking the code spent. The only path out of the live state."""
        self.consumed_at = at

    def revoke(self, at: datetime) -> None:
        """Stamp the revocation instant, marking the code killed by its creator. Independent of ``consume``."""
        self.revoked_at = at

    # Identity equality: an invite code IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, InviteCodeEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
