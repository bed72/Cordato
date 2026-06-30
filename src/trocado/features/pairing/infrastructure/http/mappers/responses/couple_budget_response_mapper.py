from __future__ import annotations

from trocado.features.pairing.application.data.couple_budget_data import CoupleBudgetData
from trocado.features.pairing.infrastructure.http.responses.couple_budget_response import CoupleBudgetResponse


class CoupleBudgetResponseMapper:
    @staticmethod
    def to_response(data: CoupleBudgetData) -> CoupleBudgetResponse:
        return CoupleBudgetResponse(
            amount=data.amount,
            end_date=data.period_end,
            remaining=data.remaining,
            start_date=data.period_start,
            total_spent=data.total_spent,
        )
