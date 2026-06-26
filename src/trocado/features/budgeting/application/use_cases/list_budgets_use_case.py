from __future__ import annotations

from trocado.features.budgeting.application.data.budget_data import BudgetData
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.mappers.budget_data_mapper import BudgetDataMapper


class ListBudgetsUseCase:
    """List a person's live budgets, most-recent-period-first — read-only, no spend.

    Reuses ``list_live_for_person`` (soft-deleted excluded, owner-scoped in the adapter); ordering is a
    presentation rule applied here, not in persistence. Carries no ``total_spent``/``remaining`` — that
    enrichment belongs to the active-budget read.
    """

    def __init__(self, repository: BudgetRepositoryInterface) -> None:
        self._repository = repository

    async def execute(self, person_id: str) -> list[BudgetData]:
        budgets = await self._repository.list_live_for_person(person_id)
        budgets.sort(key=lambda budget: (budget.start_date, budget.created_at), reverse=True)
        return [BudgetDataMapper.to_data(budget) for budget in budgets]
