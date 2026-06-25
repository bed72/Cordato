from datetime import date

from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity


class FakeExpenseRepository(ExpenseRepositoryInterface):
    """In-memory test double. Stores expenses in a list for assertions."""

    def __init__(self) -> None:
        self.expenses: list[ExpenseEntity] = []

    async def create(self, expense: ExpenseEntity) -> None:
        self.expenses.append(expense)

    async def find_in_range(self, person_id: str, start: date, end: date) -> list[ExpenseEntity]:
        return [
            expense
            for expense in self.expenses
            if expense.person_id == person_id and expense.deleted_at is None and start <= expense.occurred_on <= end
        ]
