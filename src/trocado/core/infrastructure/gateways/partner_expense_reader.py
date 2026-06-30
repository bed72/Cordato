from __future__ import annotations

from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.application.interfaces.partner_expense_reader_interface import (
    PartnerExpenseReaderInterface,
)


class PartnerExpenseReader(PartnerExpenseReaderInterface):
    """Cross-feature bridge: reads a person's live expenses for the pairing context.

    Lives in core/infrastructure because it imports from two feature packages simultaneously.
    Pre-ORM: replaced by a shared-database query once persistence lands.
    """

    def __init__(self, expense_repository: ExpenseRepositoryInterface) -> None:
        self._expense_repository = expense_repository

    async def list_for_person(self, person_id: str) -> list[PartnerExpenseData]:
        expenses = await self._expense_repository.list_live_for_person(person_id)
        return [
            PartnerExpenseData(
                id=expense.id,
                person_id=expense.person_id,
                amount=expense.amount.value,
                occurred_on=expense.occurred_on,
                created_at=expense.created_at,
                description=expense.description,
            )
            for expense in expenses
        ]
