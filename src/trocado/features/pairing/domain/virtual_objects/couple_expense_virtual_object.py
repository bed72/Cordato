from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.pairing.domain.enums.perspective import Perspective


@dataclass(frozen=True, slots=True)
class CoupleExpenseVirtualObject:
    """One expense in the couple view — a read-time projection, never stored.

    A Virtual Object: neither entity (no identity of its own) nor value object (it composes a partner's
    expense and validates nothing). It carries the expense as read from either partner's ledger plus the
    `reader_id`, and derives the reader-relative `perspective` — keeping that point-of-view rule in the
    domain rather than in a mapper. Money stays exact-decimal (`MoneyValueObject`) across the boundary.
    """

    owner_id: str
    reader_id: str
    expense_id: str
    occurred_on: date
    created_at: datetime
    description: str | None
    amount: MoneyValueObject

    @property
    def perspective(self) -> Perspective:
        """`MINE` when the reader owns this expense, `THEIRS` when the partner does."""
        return Perspective.MINE if self.owner_id == self.reader_id else Perspective.THEIRS
