from __future__ import annotations

from trocado.features.expenses.application.data.audit_expense_data import AuditExpenseData
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.application.mappers.audit_expense_data_mapper import AuditExpenseDataMapper


class AuditExpensesUseCase:
    """Audit a person's expenses — live and soft-deleted alike, most-recent-first, read-only.

    The reader for the audit trail the soft-delete promises: it calls ``list_including_removed`` (the only
    expense read that crosses the two-read contract and surfaces ``deleted_at != null``, owner-scoped in the
    adapter). Ordering mirrors the live ``list-expenses``; ``deleted_at`` does not reorder anything, so a
    removed expense sits exactly where its date places it.
    """

    def __init__(self, repository: ExpenseRepositoryInterface) -> None:
        self._repository = repository

    async def execute(self, person_id: str) -> list[AuditExpenseData]:
        expenses = await self._repository.list_including_removed(person_id)
        expenses.sort(key=lambda expense: (expense.occurred_on, expense.created_at), reverse=True)
        return [AuditExpenseDataMapper.to_data(expense) for expense in expenses]
