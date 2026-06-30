from __future__ import annotations

from datetime import date

from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.interfaces.spend_reader_interface import SpendReaderInterface
from trocado.features.pairing.application.data.partner_active_budget_data import PartnerActiveBudgetData
from trocado.features.pairing.application.interfaces.partner_budget_reader_interface import (
    PartnerBudgetReaderInterface,
)


class PartnerBudgetReader(PartnerBudgetReaderInterface):
    """Cross-feature bridge: reads a person's active budget for the pairing context.

    Lives in core/infrastructure because it imports from two feature packages simultaneously.
    Pre-ORM: replaced by a shared-database query once persistence lands.
    """

    def __init__(
        self,
        budget_repository: BudgetRepositoryInterface,
        spend_reader: SpendReaderInterface,
    ) -> None:
        self._budget_repository = budget_repository
        self._spend_reader = spend_reader

    async def active_for_person(self, person_id: str, day: date) -> PartnerActiveBudgetData | None:
        budget = await self._budget_repository.find_active_for_person(person_id, day)
        if budget is None:
            return None

        total_spent = await self._spend_reader.total_spent(person_id, budget.start_date, budget.end_date)

        return PartnerActiveBudgetData(
            person_id=person_id,
            start_date=budget.start_date,
            end_date=budget.end_date,
            amount=budget.amount.value,
            total_spent=total_spent.value,
        )
