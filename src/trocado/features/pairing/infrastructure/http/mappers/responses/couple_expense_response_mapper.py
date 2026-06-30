from __future__ import annotations

from trocado.features.pairing.application.data.couple_expense_data import CoupleExpenseData
from trocado.features.pairing.infrastructure.http.responses.couple_expense_response import CoupleExpenseResponse


class CoupleExpenseResponseMapper:
    @staticmethod
    def to_response(data: CoupleExpenseData) -> CoupleExpenseResponse:
        return CoupleExpenseResponse(
            id=data.id,
            amount=data.amount,
            person_id=data.person_id,
            created_at=data.created_at,
            occurred_on=data.occurred_on,
            description=data.description,
            perspective=data.perspective,
        )
