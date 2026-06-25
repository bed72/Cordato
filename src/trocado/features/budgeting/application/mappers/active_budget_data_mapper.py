from __future__ import annotations

from trocado.features.budgeting.application.data.active_budget_data import ActiveBudgetData
from trocado.features.budgeting.domain.virtual_objects.active_budget_virtual_object import (
    ActiveBudgetVirtualObject,
)


class ActiveBudgetDataMapper:
    """Maps an ActiveBudgetVirtualObject to its public read-model, unwrapping money to plain Decimals."""

    @staticmethod
    def to_data(active: ActiveBudgetVirtualObject) -> ActiveBudgetData:
        budget = active.budget
        return ActiveBudgetData(
            id=budget.id,
            note=budget.note,
            end_date=budget.end_date,
            amount=budget.amount.value,
            person_id=budget.person_id,
            start_date=budget.start_date,
            created_at=budget.created_at,
            remaining=active.remaining.value,
            total_spent=active.total_spent.value,
        )
