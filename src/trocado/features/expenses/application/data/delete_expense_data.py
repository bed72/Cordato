from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class DeleteExpenseData:
    """Command input for soft-deleting an expense — the requester and the expense they want to remove."""

    expense_id: str
    requester_id: str
