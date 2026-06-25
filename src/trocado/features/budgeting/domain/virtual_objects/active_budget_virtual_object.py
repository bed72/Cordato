from __future__ import annotations

from dataclasses import dataclass

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity


@dataclass(frozen=True, slots=True)
class ActiveBudgetVirtualObject:
    """The enriched active budget — a read-time projection, never stored.

    A Virtual Object: neither entity (no identity of its own) nor value object (it references an
    entity and validates nothing). It composes a live ``BudgetEntity`` with the spend summed from that
    owner's expenses in the budget's range, and derives ``remaining`` — keeping the money math in the
    domain rather than in a mapper.
    """

    budget: BudgetEntity
    total_spent: MoneyValueObject

    @property
    def remaining(self) -> MoneyValueObject:
        """What is left of the budget — ``amount − total_spent``; negative when overspent."""
        return MoneyValueObject(self.budget.amount.value - self.total_spent.value)
