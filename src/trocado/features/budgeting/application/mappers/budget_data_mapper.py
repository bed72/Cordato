from __future__ import annotations

from trocado.features.budgeting.application.data.budget_data import BudgetData
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity


class BudgetDataMapper:
    """Maps a BudgetEntity to its public read-model, unwrapping money to a plain Decimal."""

    @staticmethod
    def to_data(budget: BudgetEntity) -> BudgetData:
        return BudgetData(
            id=budget.id,
            note=budget.note,
            end_date=budget.end_date,
            amount=budget.amount.value,
            person_id=budget.person_id,
            start_date=budget.start_date,
            created_at=budget.created_at,
        )
