from __future__ import annotations

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.application.data.expense_data import ExpenseData
from trocado.features.expenses.application.data.update_expense_data import UpdateExpenseData
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.application.mappers.expense_data_mapper import ExpenseDataMapper
from trocado.features.expenses.domain.errors.expense_not_found_error import ExpenseNotFoundError


class UpdateExpenseUseCase:
    """Update one of the requester's own expenses in place: resolve it scoped to the owner, overwrite its
    amount, day and description, persist the mutated live row.

    Authorization is the lookup — only a live expense the requester owns comes back, so an unknown id, a
    foreign owner, and an already-deleted expense all reject identically with ``ExpenseNotFoundError``,
    revealing nothing. The guard runs before any mutation. No budget is touched: because expense→budget
    belonging is derived by ``occurred_on``, moving the day or changing the amount rewires no budget — the
    grouping and spend recompute on the next read. No clock is needed; nothing carries an ``updated_at``.
    """

    def __init__(self, repository: ExpenseRepositoryInterface) -> None:
        self._repository = repository

    async def execute(self, data: UpdateExpenseData) -> ExpenseData:
        # Authorization is the lookup: only a live expense the requester owns comes back. Guard first.
        expense = await self._repository.find_active_by_id(data.requester_id, data.expense_id)
        if expense is None:
            raise ExpenseNotFoundError()

        expense.update(
            occurred_on=data.occurred_on,
            description=data.description,
            amount=MoneyValueObject(data.amount),
        )
        await self._repository.update(expense)

        return ExpenseDataMapper.to_data(expense)
