from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class ActiveBudgetReadingData:
    """The slice of a partner's active budget ``BudgetReaderInterface`` returns, before ``SpendReader``
    fills in ``total_spent`` to build the full ``PartnerActiveBudgetData``."""

    end_date: date
    amount: Decimal
    start_date: date
