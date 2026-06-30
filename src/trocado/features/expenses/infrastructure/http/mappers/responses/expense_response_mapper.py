from __future__ import annotations

from trocado.features.expenses.application.data.expense_data import ExpenseData
from trocado.features.expenses.infrastructure.http.responses.expense_response import ExpenseResponse


class ExpenseResponseMapper:
    """Maps the expense read-model into its HTTP response body — a straight, lossless field copy."""

    @staticmethod
    def to_response(data: ExpenseData) -> ExpenseResponse:
        return ExpenseResponse(
            id=data.id,
            amount=data.amount,
            person_id=data.person_id,
            created_at=data.created_at,
            occurred_on=data.occurred_on,
            description=data.description,
        )
