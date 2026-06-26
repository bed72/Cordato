from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class PartnerActiveBudgetData:
    """A partner's active budget as read through pairing's own gateway port — its vocabulary, not budgeting's.

    The cross-context read shape the `PartnerBudgetReader` returns for a person who has an active budget on
    the requested day (the reader returns nothing when there is none). Pairing never imports the budgeting
    module's `ActiveBudgetVirtualObject`; it speaks only this shape, so the dependency points at pairing's
    own abstraction.
    """

    person_id: str
    start_date: date
    end_date: date
    amount: Decimal
    total_spent: Decimal
