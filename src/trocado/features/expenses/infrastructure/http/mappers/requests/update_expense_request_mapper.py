from __future__ import annotations

from trocado.features.expenses.application.data.update_expense_data import UpdateExpenseData
from trocado.features.expenses.infrastructure.http.requests.update_expense_request import UpdateExpenseRequest


class UpdateExpenseRequestMapper:
    """Maps the HTTP request body, acting person, and path parameter into the use case's command."""

    @staticmethod
    def to_data(request: UpdateExpenseRequest, person_id: str, expense_id: str) -> UpdateExpenseData:
        return UpdateExpenseData(
            amount=request.amount,
            expense_id=expense_id,
            requester_id=person_id,
            occurred_on=request.occurred_on,
            description=request.description,
        )
