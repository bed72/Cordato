from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject


@dataclass(frozen=True, slots=True)
class PartnerActiveBudgetVirtualObject:
    """One partner's active budget as seen by the couple view — a read-time projection, never stored.

    A Virtual Object: neither entity (no identity of its own) nor value object (it composes a partner's
    active budget and validates nothing). It is pairing's own projection of "a partner's active budget"
    (the anti-corruption counterpart of budgeting's `ActiveBudgetVirtualObject`, which pairing may not
    import). Money stays exact-decimal (`MoneyValueObject`) across the boundary, and `remaining` is derived
    here — keeping that money rule in the domain rather than in a mapper.
    """

    end_date: date
    start_date: date
    amount: MoneyValueObject
    total_spent: MoneyValueObject

    @property
    def remaining(self) -> MoneyValueObject:
        """What is left of this partner's budget — ``amount − total_spent``; negative when overspent."""
        return MoneyValueObject(self.amount.value - self.total_spent.value)
