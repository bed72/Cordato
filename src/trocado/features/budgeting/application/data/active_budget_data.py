from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class ActiveBudgetData:
    """Read-model of a person's active budget for a day — the budget enriched with derived spend.

    ``total_spent`` and ``remaining`` are always present (never nullable): this read-model only exists
    when there is an active budget to enrich. Both are derived at read-time, never stored.
    """

    id: str
    end_date: date
    person_id: str
    amount: Decimal
    note: str | None
    start_date: date
    remaining: Decimal
    created_at: datetime
    total_spent: Decimal
