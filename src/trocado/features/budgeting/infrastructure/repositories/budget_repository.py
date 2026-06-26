from __future__ import annotations

from datetime import date

from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity


class BudgetRepository(BudgetRepositoryInterface):
    """In-memory budget store, keyed by id. A stand-in until an ORM-backed adapter replaces it."""

    def __init__(self) -> None:
        self._budgets: dict[str, BudgetEntity] = {}

    async def create(self, budget: BudgetEntity) -> None:
        self._budgets[budget.id] = budget

    async def list_live_for_person(self, person_id: str) -> list[BudgetEntity]:
        return [
            budget for budget in self._budgets.values() if budget.person_id == person_id and budget.deleted_at is None
        ]

    async def find_active_for_person(self, person_id: str, day: date) -> BudgetEntity | None:
        for budget in self._budgets.values():
            if (
                budget.person_id == person_id
                and budget.deleted_at is None
                and budget.start_date <= day <= budget.end_date
            ):
                return budget
        return None

    async def find_active_by_id(self, person_id: str, budget_id: str) -> BudgetEntity | None:
        budget = self._budgets.get(budget_id)
        if budget is None or budget.person_id != person_id or budget.deleted_at is not None:
            return None
        return budget

    async def update(self, budget: BudgetEntity) -> None:
        self._budgets[budget.id] = budget

    async def delete(self, budget: BudgetEntity) -> None:
        self._budgets[budget.id] = budget

    async def list_including_removed(self, person_id: str) -> list[BudgetEntity]:
        return [budget for budget in self._budgets.values() if budget.person_id == person_id]

    async def erase_for_person(self, person_id: str) -> None:
        self._budgets = {id: budget for id, budget in self._budgets.items() if budget.person_id != person_id}
