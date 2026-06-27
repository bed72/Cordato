from __future__ import annotations

from trocado.features.budgeting.application.data.budget_data import BudgetData
from trocado.features.budgeting.infrastructure.http.responses.budget_response import BudgetResponse


class BudgetResponseMapper:
    """Maps the budget read-model into its HTTP response body — a straight, lossless field copy."""

    @staticmethod
    def to_response(data: BudgetData) -> BudgetResponse:
        return BudgetResponse(
            id=data.id,
            note=data.note,
            amount=data.amount,
            end_date=data.end_date,
            person_id=data.person_id,
            start_date=data.start_date,
            created_at=data.created_at,
        )
