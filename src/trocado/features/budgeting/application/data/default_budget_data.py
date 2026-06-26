from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from trocado.features.budgeting.application.data.ledger_expense_data import LedgerExpenseData


@dataclass(frozen=True, slots=True)
class DefaultBudgetData:
    """Read-model of the "No budget" bucket — the leftover expenses plus their derived total.

    Carries no ``amount`` and no ``remaining``: a leftover bucket has no limit. ``total_spent`` is derived
    at read-time (exact to the cent) and the expenses are exactly those falling in no live budget — the one
    place they are retrievable, since no single date range spans the gaps between budgets.
    """

    total_spent: Decimal
    expenses: tuple[LedgerExpenseData, ...]
