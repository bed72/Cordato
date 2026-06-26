from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class PartnerExpenseData:
    """A partner's expense as read through pairing's own gateway port — its vocabulary, not expenses'.

    The cross-context read shape the `PartnerExpenseReader` returns: one live expense (soft-deleted ones
    are already excluded by the adapter). Pairing never imports the expenses module's entity; it speaks
    only this shape, so the dependency points at pairing's own abstraction.
    """

    id: str
    person_id: str
    amount: Decimal
    occurred_on: date
    created_at: datetime
    description: str | None
