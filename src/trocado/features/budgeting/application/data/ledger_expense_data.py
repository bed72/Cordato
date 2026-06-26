from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class LedgerExpenseData:
    """An expense as read through budgeting's own gateway port — its vocabulary, not the expenses module's.

    The cross-context read shape the ``ExpenseReader`` returns: one live expense (soft-deleted ones are
    already excluded by the adapter). Budgeting never imports the expenses module's entity; it speaks only
    this shape, so the dependency points at budgeting's own abstraction.
    """

    id: str
    person_id: str
    amount: Decimal
    occurred_on: date
    created_at: datetime
    description: str | None
