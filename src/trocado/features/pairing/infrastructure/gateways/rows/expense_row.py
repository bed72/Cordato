from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class ExpenseRow:
    """``ExpenseReader``'s own local storage row — not the expenses module's entity."""

    id: str
    person_id: str
    amount: Decimal
    occurred_on: date
    created_at: datetime
    description: str | None
    deleted_at: datetime | None
