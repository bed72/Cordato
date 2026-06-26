from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class EditBudgetData:
    """Command input for editing a budget — the requester, the target, and the full editable field set.

    A full replacement (not a patch): every editable field is supplied and overwrites the stored value.
    """

    budget_id: str
    end_date: date
    amount: Decimal
    note: str | None
    start_date: date
    requester_id: str
