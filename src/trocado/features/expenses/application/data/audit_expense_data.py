from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class AuditExpenseData:
    """Audit read-model of an expense — the plain ``ExpenseData`` plus its ``deleted_at``.

    The only expense read-model that carries ``deleted_at`` (``null`` for a live expense, the soft-delete
    timestamp for a removed one): it is what makes a removed expense distinguishable from a live one within
    the same audit listing. Carries no budget reference of any kind — belonging stays a date-range derivation.
    """

    id: str
    person_id: str
    amount: Decimal
    occurred_on: date
    created_at: datetime
    description: str | None
    deleted_at: datetime | None
