from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class CreateBudgetData:
    """Command input for registering a budget — raw values straight from the caller."""

    person_id: str
    end_date: date
    amount: Decimal
    start_date: date
    note: str | None
