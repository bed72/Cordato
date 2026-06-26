from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date

from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity


class BudgetRepositoryInterface(ABC):
    """Port for persisting and reading budgets.

    Reads return only *live* budgets (soft-deleted rows excluded — that is the adapter's
    responsibility), because the non-overlap invariant and the active-budget derivation both reason
    over what currently exists, not over history.
    """

    @abstractmethod
    async def create(self, budget: BudgetEntity) -> None:
        """Persist a new budget."""
        raise NotImplementedError

    @abstractmethod
    async def list_live_for_person(self, person_id: str) -> list[BudgetEntity]:
        """Return the person's live budgets — the set the non-overlap check is run against."""
        raise NotImplementedError

    @abstractmethod
    async def find_active_for_person(self, person_id: str, day: date) -> BudgetEntity | None:
        """Return the person's live budget whose inclusive range contains ``day``, or ``None``.

        At most one can match, since a person's live budgets never overlap.
        """
        raise NotImplementedError

    @abstractmethod
    async def find_active_by_id(self, person_id: str, budget_id: str) -> BudgetEntity | None:
        """Resolve the requester's own *live* budget — matched by owner and id, excluding soft-deleted rows.

        The authorization lookup for deletion: a person can only ever reach a budget they own. An unknown
        id, a budget owned by another person, and an already soft-deleted budget are indistinguishable —
        all return ``None`` — so the caller can never probe whether someone else's budget exists.

        Distinct from ``find_active_for_person`` (which resolves the live budget *covering a given day*, the
        date-containment derivation): here ``active`` means *not soft-deleted*, matched by id, not by date.
        """
        raise NotImplementedError

    @abstractmethod
    async def update(self, budget: BudgetEntity) -> None:
        """Persist a budget in its mutated *live* state (its editable fields already overwritten).

        Distinct from ``create`` (introduce a new budget) and ``delete`` (persist a soft-deleted state):
        ``update`` saves an existing live budget after an edit. The eventual ORM adapter issues an UPDATE
        here, not an INSERT.
        """
        raise NotImplementedError

    @abstractmethod
    async def delete(self, budget: BudgetEntity) -> None:
        """Persist a budget in its soft-deleted state (its ``deleted_at`` already stamped)."""
        raise NotImplementedError

    @abstractmethod
    async def list_including_removed(self, person_id: str) -> list[BudgetEntity]:
        """Audit read: return all of the person's budgets, live and soft-deleted alike.

        The two-read contract: normal reads (``list_live_for_person``, ``find_active_for_person``,
        ``find_active_by_id``) exclude ``deleted_at != null``; only this explicit audit method sees
        everything.
        """
        raise NotImplementedError

    @abstractmethod
    async def erase_for_person(self, person_id: str) -> None:
        """**Physically** delete every budget the person owns — live and soft-deleted alike.

        The cascade primitive for account deletion (the domain's only hard delete), distinct from the
        day-to-day soft-delete: it leaves no row behind. Touches only the given person's budgets; a no-op
        when they own none.
        """
        raise NotImplementedError
