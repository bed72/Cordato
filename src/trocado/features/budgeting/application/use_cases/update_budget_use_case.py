from __future__ import annotations

from dataclasses import replace

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.data.budget_data import BudgetData
from trocado.features.budgeting.application.data.update_budget_data import UpdateBudgetData
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.mappers.budget_data_mapper import BudgetDataMapper
from trocado.features.budgeting.domain.errors.budget_not_found_error import BudgetNotFoundError
from trocado.features.budgeting.domain.errors.overlapping_budget_error import OverlappingBudgetError


class UpdateBudgetUseCase:
    """Update one of the requester's own live budgets: resolve it scoped to the owner, apply the new values,
    re-assert the non-overlap invariant against the owner's *other* live budgets, persist.

    Authorization is the lookup — only a live budget the requester owns comes back, so an unknown id, a
    foreign owner, and an already-deleted budget all reject identically with ``BudgetNotFoundError``,
    revealing nothing. Every check runs against a throwaway copy before the real entity is persisted, so a
    rejected amount, range, or overlap changes nothing. No expense is touched: belonging is derived by date
    at read-time, so moving a budget's range only changes which expenses fall under it on the next read.
    """

    def __init__(self, repository: BudgetRepositoryInterface) -> None:
        self._repository = repository

    async def execute(self, data: UpdateBudgetData) -> BudgetData:
        # Authorization is the lookup: only a live budget the requester owns comes back. Guard first.
        budget = await self._repository.find_active_by_id(data.requester_id, data.budget_id)
        if budget is None:
            raise BudgetNotFoundError()

        # Apply the update to a throwaway copy: `update` re-validates amount then range there, and the
        # proposed range is tested for overlap — all before anything is persisted, so a rejection changes nothing.
        edited = replace(budget)
        edited.update(
            note=data.note,
            end_date=data.end_date,
            start_date=data.start_date,
            amount=MoneyValueObject(data.amount),
        )

        # Non-overlap against the owner's OTHER live budgets — the edited one is in this set and would
        # otherwise overlap itself, so it is excluded by id.
        others = await self._repository.list_live_for_person(data.requester_id)
        if any(other.id != edited.id and edited.overlaps(other) for other in others):
            raise OverlappingBudgetError()

        await self._repository.update(edited)

        return BudgetDataMapper.to_data(edited)
