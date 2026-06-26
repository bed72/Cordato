from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from trocado.features.pairing.domain.entities.pair_entity import PairEntity


@dataclass(frozen=True, slots=True)
class CurrentPairVirtualObject:
    """The reader's current pair, seen from their own side — a read-time projection, never stored.

    A Virtual Object: neither entity (no identity of its own) nor value object (it composes the stored
    `PairEntity` with the partner's resolved identity and validates nothing). It carries the live pair plus
    the reader-relative partner (`partner_id` / `partner_name`, "the member who is not the reader") and
    derives the pair's `pair_id` / `paired_since` — keeping that point-of-view rule in the domain rather
    than in a mapper.

    The partner is supplied by the use case (which resolved it from the pair); the Virtual Object asserts
    the pairing is internally consistent — the partner must be a member of the pair and must not be the
    reader — so an inconsistent projection can never be built.
    """

    reader_id: str
    partner_id: str
    pair: PairEntity
    partner_name: str

    def __post_init__(self) -> None:
        members = (self.pair.person_a_id, self.pair.person_b_id)
        if self.reader_id not in members:
            raise ValueError("O leitor não é membro do par.")
        if self.partner_id == self.reader_id or self.partner_id not in members:
            raise ValueError("O parceiro deve ser o outro membro do par.")

    @property
    def pair_id(self) -> str:
        """The identity of the live pair."""
        return self.pair.id

    @property
    def paired_since(self) -> datetime:
        """When the pair was formed — the pair's `created_at`."""
        return self.pair.created_at
