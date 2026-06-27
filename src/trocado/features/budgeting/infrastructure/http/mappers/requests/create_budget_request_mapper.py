from __future__ import annotations

from trocado.features.budgeting.application.data.create_budget_data import CreateBudgetData
from trocado.features.budgeting.infrastructure.http.requests.create_budget_request import (
    CreateBudgetRequest,
)


class CreateBudgetRequestMapper:
    """Maps the HTTP request body plus the acting person into the use case's command.

    Named after the *request* it governs, never ``DataMapper`` — ``application/mappers/BudgetDataMapper``
    (Entity → Data) already owns that name. The acting person is a second argument because identity is
    contextual to the request, not part of its body shape.
    """

    @staticmethod
    def to_data(request: CreateBudgetRequest) -> CreateBudgetData:
        return CreateBudgetData(
            note=request.note,
            person_id="person_id",
            amount=request.amount,
            end_date=request.end_date,
            start_date=request.start_date,
        )
