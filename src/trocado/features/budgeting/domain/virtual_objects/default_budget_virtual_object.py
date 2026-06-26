from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject

_ZERO = Decimal("0")


@dataclass(frozen=True, slots=True)
class DefaultBudgetVirtualObject:
    """The "No budget" bucket — a read-time projection, never stored.

    A Virtual Object: neither entity (no identity of its own) nor value object (it composes the leftover
    spend and validates nothing). It groups the owner's live expenses that fall within no live budget's
    range — the complement of the real budgets over the ledger — and **derives** ``total_spent``, the
    exact-decimal sum of exactly those expenses' amounts, keeping the money math in the domain.

    Unlike ``ActiveBudgetVirtualObject`` it has **no ``amount`` (limit) and no ``remaining``**: a leftover
    bucket is not a real budget, so there is nothing to be left of. It carries only the leftover amounts;
    the selection of *which* expenses are leftover (date containment via ``BudgetEntity.covers``) is the
    use case's to apply, since it spans the budgets and the cross-context ledger.
    """

    expense_amounts: tuple[MoneyValueObject, ...]

    @property
    def total_spent(self) -> MoneyValueObject:
        """The exact-decimal sum of the bucket's expenses; zero when the bucket is empty."""
        return MoneyValueObject(sum((amount.value for amount in self.expense_amounts), _ZERO))
