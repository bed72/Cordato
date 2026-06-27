from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import BaseModel


class CreateBudgetRequest(BaseModel):
    """Request body for ``POST /budgets``.

    Validates only the *structural* shape — that the fields are present and of the right type (a valid
    decimal amount, ISO dates, an optional note). The domain rules (amount greater than zero, start no
    later than end, centavo precision) stay in the value objects and entity and are deliberately **not**
    duplicated here: a single source of truth, enforced once.
    """

    end_date: date
    amount: Decimal
    start_date: date
    note: str | None = None
