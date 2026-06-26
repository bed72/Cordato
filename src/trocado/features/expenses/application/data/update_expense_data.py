from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class UpdateExpenseData:
    """Command input for updating an expense — the requester, the target, and the full editable field set.

    Full-replacement (not patch): every editable field is supplied and overwrites the stored value.
    """

    expense_id: str
    amount: Decimal
    occurred_on: date
    requester_id: str
    description: str | None
