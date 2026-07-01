from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class BudgetRow:
    """``BudgetReader``'s own local storage row — not the budgeting module's entity."""

    person_id: str
    end_date: date
    amount: Decimal
    start_date: date
    deleted_at: datetime | None
