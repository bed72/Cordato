from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(eq=False, slots=True)
class PairEntity:
    """The shared lens between two individuals — a couple is a point of view, not an owner.

    A thin link: it owns no money, no budget, no expense. ``person_a_id`` is the invite's creator,
    ``person_b_id`` the accepter. ``deleted_at`` null = live; a stamped value means the pair was
    dissolved (soft-delete) — ``dissolve`` is the only transition into that state. Born live only through
    ``create``; the bare constructor is reserved for rehydration of a stored pair with its persisted
    ``deleted_at``.
    """

    id: str
    person_a_id: str  # the invite's creator
    person_b_id: str  # the accepter
    created_at: datetime
    deleted_at: datetime | None  # null = live; no default — only `create(...)` may birth a live pair

    @classmethod
    def create(
        cls,
        *,
        id: str,
        person_a_id: str,
        person_b_id: str,
        created_at: datetime,
    ) -> PairEntity:
        """Form a brand-new, live pair — the only sanctioned way to be born."""
        return cls(
            id=id,
            deleted_at=None,
            created_at=created_at,
            person_a_id=person_a_id,
            person_b_id=person_b_id,
        )

    def dissolve(self, at: datetime) -> None:
        """Stamp the dissolution instant, taking the shared view down. The only path out of the live state."""
        self.deleted_at = at

    # Identity equality: a pair IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, PairEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
