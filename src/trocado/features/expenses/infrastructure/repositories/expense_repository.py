from __future__ import annotations

from datetime import date

from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity


class ExpenseRepository(ExpenseRepositoryInterface):
    """In-memory expense store, keyed by id. A stand-in until an ORM-backed adapter replaces it."""

    def __init__(self) -> None:
        self._expenses: dict[str, ExpenseEntity] = {}

    async def create(self, expense: ExpenseEntity) -> None:
        self._expenses[expense.id] = expense

    async def find_in_range(self, person_id: str, start: date, end: date) -> list[ExpenseEntity]:
        return [
            expense
            for expense in self._expenses.values()
            if expense.person_id == person_id and expense.deleted_at is None and start <= expense.occurred_on <= end
        ]
