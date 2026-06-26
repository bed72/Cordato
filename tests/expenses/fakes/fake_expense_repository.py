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

    async def list_live_for_person(self, person_id: str) -> list[ExpenseEntity]:
        return [expense for expense in self.expenses if expense.person_id == person_id and expense.deleted_at is None]

    async def find_active_by_id(self, person_id: str, expense_id: str) -> ExpenseEntity | None:
        for expense in self.expenses:
            if expense.id == expense_id and expense.person_id == person_id and expense.deleted_at is None:
                return expense
        return None

    async def delete(self, expense: ExpenseEntity) -> None:
        # The entity is the same object already held in the list; its stamped state is visible in place.
        if expense not in self.expenses:
            self.expenses.append(expense)

    async def list_including_removed(self, person_id: str) -> list[ExpenseEntity]:
        return [expense for expense in self.expenses if expense.person_id == person_id]

    async def erase_for_person(self, person_id: str) -> None:
        self.expenses = [expense for expense in self.expenses if expense.person_id != person_id]
