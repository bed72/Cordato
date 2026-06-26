from datetime import date

from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity


class FakeBudgetRepository(BudgetRepositoryInterface):
    """In-memory test double. Stores budgets in a list for assertions."""

    def __init__(self) -> None:
        self.budgets: list[BudgetEntity] = []

    async def create(self, budget: BudgetEntity) -> None:
        self.budgets.append(budget)

    async def list_live_for_person(self, person_id: str) -> list[BudgetEntity]:
        return [budget for budget in self.budgets if budget.person_id == person_id and budget.deleted_at is None]

    async def find_active_for_person(self, person_id: str, day: date) -> BudgetEntity | None:
        for budget in self.budgets:
            if (
                budget.person_id == person_id
                and budget.deleted_at is None
                and budget.start_date <= day <= budget.end_date
            ):
                return budget
        return None

    async def find_active_by_id(self, person_id: str, budget_id: str) -> BudgetEntity | None:
        for budget in self.budgets:
            if budget.id == budget_id and budget.person_id == person_id and budget.deleted_at is None:
                return budget
        return None

    async def update(self, budget: BudgetEntity) -> None:
        # Replace the stored budget of the same id with its edited form; append if it is not held yet.
        for index, existing in enumerate(self.budgets):
            if existing.id == budget.id:
                self.budgets[index] = budget
                return
        self.budgets.append(budget)

    async def delete(self, budget: BudgetEntity) -> None:
        # The entity is the same object already held in the list; its stamped state is visible in place.
        if budget not in self.budgets:
            self.budgets.append(budget)

    async def list_including_removed(self, person_id: str) -> list[BudgetEntity]:
        return [budget for budget in self.budgets if budget.person_id == person_id]

    async def erase_for_person(self, person_id: str) -> None:
        self.budgets = [budget for budget in self.budgets if budget.person_id != person_id]
