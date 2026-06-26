from __future__ import annotations

from collections.abc import Sequence

from trocado.features.budgeting.application.data.default_budget_data import DefaultBudgetData
from trocado.features.budgeting.application.data.ledger_expense_data import LedgerExpenseData
from trocado.features.budgeting.domain.virtual_objects.default_budget_virtual_object import (
    DefaultBudgetVirtualObject,
)


class DefaultBudgetDataMapper:
    """Maps the default-budget bucket to its public read-model, unwrapping the derived money to a Decimal.

    Takes the Virtual Object — the domain home of the derived ``total_spent`` — together with the leftover
    expenses it groups: the bucket deliberately holds only its money in the domain (derive-don't-store),
    so the expenses that compose the read-model are passed alongside rather than stored on the VO.
    """

    @staticmethod
    def to_data(
        virtual_object: DefaultBudgetVirtualObject,
        expenses: Sequence[LedgerExpenseData],
    ) -> DefaultBudgetData:
        return DefaultBudgetData(
            expenses=tuple(expenses),
            total_spent=virtual_object.total_spent.value,
        )
