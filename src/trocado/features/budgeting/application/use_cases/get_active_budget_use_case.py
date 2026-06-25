from __future__ import annotations

from datetime import date

from trocado.features.budgeting.application.data.active_budget_data import ActiveBudgetData
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.interfaces.spend_reader_interface import (
    SpendReaderInterface,
)
from trocado.features.budgeting.application.mappers.active_budget_data_mapper import (
    ActiveBudgetDataMapper,
)
from trocado.features.budgeting.domain.virtual_objects.active_budget_virtual_object import (
    ActiveBudgetVirtualObject,
)


class GetActiveBudgetUseCase:
    """Derive a person's active budget for a day, enriched with spend read in budgeting's own terms."""

    def __init__(
        self,
        spend_reader: SpendReaderInterface,
        repository: BudgetRepositoryInterface,
    ) -> None:
        self._repository = repository
        self._spend_reader = spend_reader

    async def execute(self, person_id: str, day: date) -> ActiveBudgetData | None:
        budget = await self._repository.find_active_for_person(person_id, day)
        if budget is None:
            return None

        total_spent = await self._spend_reader.total_spent(person_id, budget.start_date, budget.end_date)

        active = ActiveBudgetVirtualObject(budget=budget, total_spent=total_spent)
        return ActiveBudgetDataMapper.to_data(active)
