from __future__ import annotations

from trocado.features.pairing.application.data.couple_expense_data import CoupleExpenseData
from trocado.features.pairing.domain.virtual_objects.couple_expense_virtual_object import (
    CoupleExpenseVirtualObject,
)


class CoupleExpenseDataMapper:
    """Maps a CoupleExpenseVirtualObject to its public read-model.

    Unwraps money to a plain Decimal and the perspective to its string value, leaving the point-of-view
    derivation in the domain.
    """

    @staticmethod
    def to_data(virtual_object: CoupleExpenseVirtualObject) -> CoupleExpenseData:
        return CoupleExpenseData(
            id=virtual_object.expense_id,
            person_id=virtual_object.owner_id,
            amount=virtual_object.amount.value,
            created_at=virtual_object.created_at,
            description=virtual_object.description,
            occurred_on=virtual_object.occurred_on,
            perspective=virtual_object.perspective.value,
        )
