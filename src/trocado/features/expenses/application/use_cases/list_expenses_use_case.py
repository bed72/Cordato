from __future__ import annotations

from trocado.features.expenses.application.data.expense_data import ExpenseData
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.application.mappers.expense_data_mapper import ExpenseDataMapper


class ListExpensesUseCase:
    """List a person's own live expenses, most-recent-first. A read over only the requester's ledger."""

    def __init__(self, repository: ExpenseRepositoryInterface) -> None:
        self._repository = repository

    async def execute(self, person_id: str) -> list[ExpenseData]:
        expenses = await self._repository.list_live_for_person(person_id)
        expenses.sort(key=lambda expense: (expense.occurred_on, expense.created_at), reverse=True)
        return [ExpenseDataMapper.to_data(expense) for expense in expenses]
