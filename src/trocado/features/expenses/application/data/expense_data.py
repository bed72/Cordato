from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class ExpenseData:
    """Read-model of an expense for the caller. Carries no budget reference of any kind."""

    id: str
    person_id: str
    amount: Decimal
    occurred_on: date
    created_at: datetime
    description: str | None
