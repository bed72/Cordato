from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class CoupleExpenseData:
    """Read-model of one expense in the couple view, told from the reader's perspective.

    `perspective` is the plain string `"mine"` / `"theirs"` (the `Perspective` enum's value), derived at
    read-time from who owns the expense relative to the reader — never stored.
    """

    id: str
    person_id: str
    amount: Decimal
    occurred_on: date
    created_at: datetime
    description: str | None
    perspective: str
