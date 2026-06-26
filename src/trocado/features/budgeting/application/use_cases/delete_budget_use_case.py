from __future__ import annotations

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.budgeting.application.data.delete_budget_data import DeleteBudgetData
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.domain.errors.budget_not_found_error import BudgetNotFoundError


class DeleteBudgetUseCase:
    """Soft-delete one of the requester's own budgets: resolve it scoped to the owner, stamp ``deleted_at``.

    Authorization is the lookup — only a live budget the requester owns comes back, so an unknown id, a
    foreign owner, and an already-deleted budget all reject identically with ``BudgetNotFoundError``,
    revealing nothing. Nothing but the target's ``deleted_at`` is touched: because budget belonging is
    derived by date and the active-budget/non-overlap derivations read only live budgets, the removal
    rewires nothing — the freed range reopens and the covered expenses fall to the default bucket on the
    next read.
    """

    def __init__(
        self,
        clock: ClockInterface,
        repository: BudgetRepositoryInterface,
    ) -> None:
        self._clock = clock
        self._repository = repository

    async def execute(self, data: DeleteBudgetData) -> None:
        # Authorization is the lookup: only a live budget the requester owns comes back. Guard first.
        budget = await self._repository.find_active_by_id(data.requester_id, data.budget_id)
        if budget is None:
            raise BudgetNotFoundError()

        # Real data dependency (delete needs the resolved budget) — await sequentially, no gather.
        now = await self._clock.now()
        budget.delete(now)
        await self._repository.delete(budget)
