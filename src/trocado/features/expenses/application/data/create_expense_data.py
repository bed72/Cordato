from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class CreateExpenseData:
    """Command input for recording an expense — raw values straight from the caller."""

    person_id: str
    amount: Decimal
    occurred_on: date
    description: str | None
