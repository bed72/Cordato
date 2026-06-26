from __future__ import annotations

from trocado.features.pairing.application.data.couple_budget_data import CoupleBudgetData
from trocado.features.pairing.domain.virtual_objects.couple_budget_virtual_object import (
    CoupleBudgetVirtualObject,
)


class CoupleBudgetDataMapper:
    """Maps a CoupleBudgetVirtualObject to its public read-model.

    Reads the virtual object's derived span and sums, unwrapping each money to a plain Decimal and leaving
    the span/money derivation in the domain.
    """

    @staticmethod
    def to_data(virtual_object: CoupleBudgetVirtualObject) -> CoupleBudgetData:
        return CoupleBudgetData(
            amount=virtual_object.amount.value,
            period_end=virtual_object.period_end,
            period_start=virtual_object.period_start,
            remaining=virtual_object.remaining.value,
            total_spent=virtual_object.total_spent.value,
        )
