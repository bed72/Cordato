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

    async def list_live_for_person(self, person_id: str) -> list[ExpenseEntity]:
        return [
            expense
            for expense in self._expenses.values()
            if expense.person_id == person_id and expense.deleted_at is None
        ]

    async def find_active_by_id(self, person_id: str, expense_id: str) -> ExpenseEntity | None:
        expense = self._expenses.get(expense_id)
        if expense is None or expense.person_id != person_id or expense.deleted_at is not None:
            return None
        return expense

    async def update(self, expense: ExpenseEntity) -> None:
        self._expenses[expense.id] = expense

    async def delete(self, expense: ExpenseEntity) -> None:
        self._expenses[expense.id] = expense

    async def list_including_removed(self, person_id: str) -> list[ExpenseEntity]:
        return [expense for expense in self._expenses.values() if expense.person_id == person_id]

    async def erase_for_person(self, person_id: str) -> None:
        self._expenses = {id: expense for id, expense in self._expenses.items() if expense.person_id != person_id}
