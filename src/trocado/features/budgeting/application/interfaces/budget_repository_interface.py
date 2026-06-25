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
