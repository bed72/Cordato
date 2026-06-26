from __future__ import annotations

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.expenses.application.data.delete_expense_data import DeleteExpenseData
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.domain.errors.expense_not_found_error import ExpenseNotFoundError


class DeleteExpenseUseCase:
    """Soft-delete one of the requester's own expenses: resolve it scoped to the owner, stamp ``deleted_at``.

    Authorization is the lookup — only a live expense the requester owns comes back, so an unknown id, a
    foreign owner, and an already-deleted expense all reject identically with ``ExpenseNotFoundError``,
    revealing nothing. Nothing but the target's ``deleted_at`` is touched: because expense→budget belonging
    is derived by date, the removal rewires no budget — the active-budget spend recomputes on the next read.
    """

    def __init__(
        self,
        clock: ClockInterface,
        repository: ExpenseRepositoryInterface,
    ) -> None:
        self._clock = clock
        self._repository = repository

    async def execute(self, data: DeleteExpenseData) -> None:
        # Authorization is the lookup: only a live expense the requester owns comes back. Guard first.
        expense = await self._repository.find_active_by_id(data.requester_id, data.expense_id)
        if expense is None:
            raise ExpenseNotFoundError()

        # Real data dependency (delete needs the resolved expense) — await sequentially, no gather.
        now = await self._clock.now()
        expense.delete(now)
        await self._repository.delete(expense)
