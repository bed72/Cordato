from __future__ import annotations

from trocado.features.budgeting.application.data.update_budget_data import UpdateBudgetData
from trocado.features.budgeting.infrastructure.http.requests.update_budget_request import UpdateBudgetRequest


class UpdateBudgetRequestMapper:
    """Maps the HTTP request body plus the acting person and target id into the use case's command."""

    @staticmethod
    def to_data(request: UpdateBudgetRequest, person_id: str, budget_id: str) -> UpdateBudgetData:
        return UpdateBudgetData(
            note=request.note,
            budget_id=budget_id,
            amount=request.amount,
            requester_id=person_id,
            end_date=request.end_date,
            start_date=request.start_date,
        )
