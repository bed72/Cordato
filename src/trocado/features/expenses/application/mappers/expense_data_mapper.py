from __future__ import annotations

from trocado.features.expenses.application.data.expense_data import ExpenseData
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity


class ExpenseDataMapper:
    """Maps an ExpenseEntity to its public read-model, unwrapping money to a plain Decimal."""

    @staticmethod
    def to_data(expense: ExpenseEntity) -> ExpenseData:
        return ExpenseData(
            id=expense.id,
            person_id=expense.person_id,
            amount=expense.amount.value,
            created_at=expense.created_at,
            occurred_on=expense.occurred_on,
            description=expense.description,
        )
