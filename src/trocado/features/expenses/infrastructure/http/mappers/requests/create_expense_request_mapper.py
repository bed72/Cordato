from __future__ import annotations

from trocado.features.expenses.application.data.create_expense_data import CreateExpenseData
from trocado.features.expenses.infrastructure.http.requests.create_expense_request import CreateExpenseRequest


class CreateExpenseRequestMapper:
    """Maps the HTTP request body plus the acting person into the use case's command.

    Named after the request it governs, never ``DataMapper`` — ``application/mappers/ExpenseDataMapper``
    (Entity → Data) already owns that name. The acting person is a second argument because identity is
    contextual to the request, not part of its body shape.
    """

    @staticmethod
    def to_data(request: CreateExpenseRequest, person_id: str) -> CreateExpenseData:
        return CreateExpenseData(
            person_id=person_id,
            amount=request.amount,
            occurred_on=request.occurred_on,
            description=request.description,
        )
