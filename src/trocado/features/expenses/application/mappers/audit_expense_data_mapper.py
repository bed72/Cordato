from __future__ import annotations

from trocado.features.expenses.application.data.audit_expense_data import AuditExpenseData
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity


class AuditExpenseDataMapper:
    """Maps an ExpenseEntity to its audit read-model, unwrapping money to a plain Decimal and surfacing
    ``deleted_at`` (which the plain ``ExpenseDataMapper`` deliberately drops)."""

    @staticmethod
    def to_data(expense: ExpenseEntity) -> AuditExpenseData:
        return AuditExpenseData(
            id=expense.id,
            person_id=expense.person_id,
            amount=expense.amount.value,
            created_at=expense.created_at,
            deleted_at=expense.deleted_at,
            occurred_on=expense.occurred_on,
            description=expense.description,
        )
