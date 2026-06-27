from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class AuditBudgetData:
    """Audit read-model of a budget — the plain ``BudgetData`` plus its ``deleted_at``.

    The only budget read-model that carries ``deleted_at`` (``null`` for a live budget, the soft-delete
    timestamp for a removed one): it is what makes a removed budget distinguishable from a live one within
    the same audit listing. Carries no spend — ``total_spent``/``remaining`` belong to the enriched
    active-budget read.
    """

    id: str
    person_id: str
    end_date: date
    amount: Decimal
    start_date: date
    note: str | None
    created_at: datetime
    deleted_at: datetime | None
