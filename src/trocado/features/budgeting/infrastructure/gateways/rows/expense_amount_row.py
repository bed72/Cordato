from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class ExpenseAmountRow:
    """``ExpenseAmountReader``'s own local storage row — not the expenses module's entity."""

    person_id: str
    amount: Decimal
    occurred_on: date
    deleted_at: datetime | None
