from __future__ import annotations

from trocado.features.budgeting.application.data.active_budget_data import ActiveBudgetData
from trocado.features.budgeting.infrastructure.http.responses.active_budget_response import ActiveBudgetResponse


class ActiveBudgetResponseMapper:
    """Maps the enriched active-budget read-model into its HTTP response body."""

    @staticmethod
    def to_response(data: ActiveBudgetData) -> ActiveBudgetResponse:
        return ActiveBudgetResponse(
            id=data.id,
            note=data.note,
            amount=data.amount,
            end_date=data.end_date,
            person_id=data.person_id,
            remaining=data.remaining,
            start_date=data.start_date,
            created_at=data.created_at,
            total_spent=data.total_spent,
        )
