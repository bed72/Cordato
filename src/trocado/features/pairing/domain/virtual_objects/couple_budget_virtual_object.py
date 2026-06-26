from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.pairing.domain.virtual_objects.partner_active_budget_virtual_object import (
    PartnerActiveBudgetVirtualObject,
)


@dataclass(frozen=True, slots=True)
class CoupleBudgetVirtualObject:
    """The couple budget — the combined panorama over both partners' active budgets, never stored.

    A Virtual Object: it composes the present partner active budgets (one or two — never empty) and
    derives the panorama: the spanned period ``[min(start), max(end)]`` and the summed ``amount`` /
    ``total_spent`` / ``remaining``. Deliberately approximate — a wide-angle lens whose exact figures live
    in each individual's own active budget. The span and money sums are the domain rule, so they live here
    rather than in a mapper or the use case.
    """

    budgets: tuple[PartnerActiveBudgetVirtualObject, ...]

    @property
    def period_start(self) -> date:
        """The earliest start across the present active budgets."""
        return min(budget.start_date for budget in self.budgets)

    @property
    def period_end(self) -> date:
        """The latest end across the present active budgets."""
        return max(budget.end_date for budget in self.budgets)

    @property
    def amount(self) -> MoneyValueObject:
        """The sum of the present active budgets' amounts."""
        return MoneyValueObject(sum((budget.amount.value for budget in self.budgets), Decimal(0)))

    @property
    def total_spent(self) -> MoneyValueObject:
        """The sum of the present active budgets' spends."""
        return MoneyValueObject(sum((budget.total_spent.value for budget in self.budgets), Decimal(0)))

    @property
    def remaining(self) -> MoneyValueObject:
        """What is left of the combined budget — ``amount − total_spent``; negative when overspent."""
        return MoneyValueObject(self.amount.value - self.total_spent.value)
