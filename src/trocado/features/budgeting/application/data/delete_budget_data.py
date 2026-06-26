from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class DeleteBudgetData:
    """Command input for soft-deleting a budget — the requester and the budget they want to remove."""

    budget_id: str
    requester_id: str
