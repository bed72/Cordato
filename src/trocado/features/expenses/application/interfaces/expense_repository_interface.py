from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date

from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity


class ExpenseRepositoryInterface(ABC):
    """Port for persisting and reading expenses.

    ``find_in_range`` is the date-range query that *derives* expense→budget belonging with no foreign
    key: a budget's spend is the sum of its owner's expenses whose date falls within the budget's
    inclusive range. Soft-deleted rows are excluded from normal reads — the adapter's responsibility.
    """

    @abstractmethod
    async def create(self, expense: ExpenseEntity) -> None:
        """Persist a new expense."""
        raise NotImplementedError

    @abstractmethod
    async def find_in_range(self, person_id: str, start: date, end: date) -> list[ExpenseEntity]:
        """Return the person's live expenses whose date lies within ``[start, end]`` (inclusive)."""
        raise NotImplementedError
