from __future__ import annotations

from trocado.features.budgeting.application.data.audit_budget_data import AuditBudgetData
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.mappers.audit_budget_data_mapper import AuditBudgetDataMapper


class AuditBudgetsUseCase:
    """Audit a person's budgets — live and soft-deleted alike, most-recent-period-first, read-only.

    The reader for the audit trail the soft-delete promises: it calls ``list_including_removed`` (the only
    budget read that crosses the two-read contract and surfaces ``deleted_at != null``, owner-scoped in the
    adapter). Ordering mirrors the live ``list-budgets``; ``deleted_at`` does not reorder anything, so a
    removed budget sits exactly where its period places it.
    """

    def __init__(self, repository: BudgetRepositoryInterface) -> None:
        self._repository = repository

    async def execute(self, person_id: str) -> list[AuditBudgetData]:
        budgets = await self._repository.list_including_removed(person_id)
        budgets.sort(key=lambda budget: (budget.start_date, budget.created_at), reverse=True)
        return [AuditBudgetDataMapper.to_data(budget) for budget in budgets]
