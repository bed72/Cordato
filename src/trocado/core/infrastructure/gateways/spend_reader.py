from __future__ import annotations

from datetime import date
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.interfaces.spend_reader_interface import SpendReaderInterface
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)


class SpendReader(SpendReaderInterface):
    """Cross-feature bridge: derives total spend for a date range from the expenses ledger.

    Lives in core/infrastructure because it is the only layer (the composition root) that may
    import from two feature packages simultaneously. Constructed by app.py and injected into
    the budgeting router as SpendReaderInterface — budgeting itself never imports expenses.
    Pre-ORM: replaced by a shared-database query once the ORM lands.
    """

    def __init__(self, expense_repository: ExpenseRepositoryInterface) -> None:
        self._expense_repository = expense_repository

    async def total_spent(self, person_id: str, start: date, end: date) -> MoneyValueObject:
        expenses = await self._expense_repository.find_in_range(person_id, start, end)
        total = sum((expense.amount.value for expense in expenses), Decimal("0.00"))
        return MoneyValueObject(total)
