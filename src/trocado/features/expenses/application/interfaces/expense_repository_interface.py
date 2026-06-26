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
    async def list_live_for_person(self, person_id: str) -> list[ExpenseEntity]:
        """Return all of the person's live expenses — every date, soft-deleted rows excluded.

        The all-live, no-range read that sits between ``find_in_range`` (range-scoped) and
        ``list_including_removed`` (audit, sees everything): the ledger read behind listing a person's
        expenses. Honors the two-read contract — normal reads never surface ``deleted_at != null``.
        """
        raise NotImplementedError

    @abstractmethod
    async def find_active_by_id(self, person_id: str, expense_id: str) -> ExpenseEntity | None:
        """Resolve the requester's own *live* expense — matched by owner and id, excluding soft-deleted rows.

        The authorization lookup for deletion: a person can only ever reach an expense they own. An unknown
        id, an expense owned by another person, and an already soft-deleted expense are indistinguishable —
        all return ``None`` — so the caller can never probe whether someone else's expense exists.
        """
        raise NotImplementedError

    @abstractmethod
    async def delete(self, expense: ExpenseEntity) -> None:
        """Persist an expense in its soft-deleted state (its ``deleted_at`` already stamped)."""
        raise NotImplementedError

    @abstractmethod
    async def list_including_removed(self, person_id: str) -> list[ExpenseEntity]:
        """Audit read: return all of the person's expenses, live and soft-deleted alike.

        The two-read contract: normal reads (``find_in_range``, ``find_active_by_id``) exclude
        ``deleted_at != null``; only this explicit audit method sees everything.
        """
        raise NotImplementedError

    @abstractmethod
    async def erase_for_person(self, person_id: str) -> None:
        """**Physically** delete every expense the person owns — live and soft-deleted alike.

        The cascade primitive for account deletion (the domain's only hard delete), distinct from the
        day-to-day soft-delete: it leaves no row behind. Touches only the given person's expenses; a no-op
        when they own none.
        """
        raise NotImplementedError
