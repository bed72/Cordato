from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class BudgetData:
    """Read-model of a budget for the caller — the plain create response.

    Carries no spend: ``total_spent``/``remaining`` belong to the enriched active-budget read, which has
    its own ``ActiveBudgetData``.
    """

    id: str
    person_id: str
    amount: Decimal
    start_date: date
    end_date: date
    note: str | None
    created_at: datetime
