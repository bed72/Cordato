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

    @abstractmethod
    async def erase_for_person(self, person_id: str) -> None:
        """**Physically** delete every expense the person owns — live and soft-deleted alike.

        The cascade primitive for account deletion (the domain's only hard delete), distinct from the
        day-to-day soft-delete: it leaves no row behind. Touches only the given person's expenses; a no-op
        when they own none.
        """
        raise NotImplementedError
