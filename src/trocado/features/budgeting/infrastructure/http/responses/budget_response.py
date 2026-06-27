from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel


class BudgetResponse(BaseModel):
    """Response body for a created budget — the budget read-model serialized for the client.

    Carries no spend (``total_spent``/``remaining`` belong to the enriched active-budget read), mirroring
    ``BudgetData``: this is the plain create response.
    """

    id: str
    person_id: str
    end_date: date
    amount: Decimal
    start_date: date
    note: str | None
    created_at: datetime
