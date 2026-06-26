from __future__ import annotations

import asyncio

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.data.default_budget_data import DefaultBudgetData
from trocado.features.budgeting.application.data.ledger_expense_data import LedgerExpenseData
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.interfaces.expense_reader_interface import (
    ExpenseReaderInterface,
)
from trocado.features.budgeting.application.mappers.default_budget_data_mapper import (
    DefaultBudgetDataMapper,
)
from trocado.features.budgeting.domain.virtual_objects.default_budget_virtual_object import (
    DefaultBudgetVirtualObject,
)


class GetDefaultBudgetUseCase:
    """Derive a person's "No budget" bucket: the live expenses falling in none of their live budgets."""

    def __init__(
        self,
        repository: BudgetRepositoryInterface,
        expense_reader: ExpenseReaderInterface,
    ) -> None:
        self._repository = repository
        self._expense_reader = expense_reader

    async def execute(self, person_id: str) -> DefaultBudgetData:
        # Live budgets and the ledger are read independently — issue them together.
        expenses, budgets = await asyncio.gather(
            self._expense_reader.list_for_person(person_id),
            self._repository.list_live_for_person(person_id),
        )

        # An expense lands in the bucket exactly when no live budget covers its day (date containment).
        leftover = [
            expense for expense in expenses if not any(budget.covers(expense.occurred_on) for budget in budgets)
        ]
        leftover.sort(key=lambda expense: (expense.occurred_on, expense.created_at), reverse=True)

        bucket = self._to_virtual_object(leftover)
        return DefaultBudgetDataMapper.to_data(bucket, leftover)

    @staticmethod
    def _to_virtual_object(leftover: list[LedgerExpenseData]) -> DefaultBudgetVirtualObject:
        return DefaultBudgetVirtualObject(
            expense_amounts=tuple(MoneyValueObject(expense.amount) for expense in leftover),
        )
