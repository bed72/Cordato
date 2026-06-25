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
    the accept-invite capability's job, not this one's).
    """

    id: str
    code: str  # opaque, unpredictable CSPRNG token
    creator_id: str  # the minter's opaque id; the domain never inspects it
    created_at: datetime
    expires_at: datetime
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
            consumed_at=None,
            creator_id=creator_id,
            created_at=created_at,
            expires_at=created_at + _TIME_TO_LIVE,
        )

    # Identity equality: an invite code IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, InviteCodeEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
