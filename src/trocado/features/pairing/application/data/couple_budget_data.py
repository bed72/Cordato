from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class CoupleBudgetData:
    """Read-model of the couple budget — the combined panorama over both partners' active budgets.

    The period spans `[period_start, period_end]` = `[min(start), max(end)]` of the present active budgets;
    `amount`, `total_spent`, and `remaining` are their sums (and `amount − total_spent`). All are derived
    at read-time, never stored — a deliberately approximate lens whose exact figures live in each person's
    own active budget.
    """

    period_start: date
    period_end: date
    amount: Decimal
    total_spent: Decimal
    remaining: Decimal
