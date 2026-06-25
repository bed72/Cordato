from __future__ import annotations

import datetime as dt
from dataclasses import dataclass
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.domain.errors.invalid_amount_error import InvalidAmountError

_ZERO = Decimal("0")


@dataclass(eq=False, slots=True)
class ExpenseEntity:
    """An expense — the domain's atomic fact: who spent, how much, on what day. Points to no budget."""

    id: str
    created_at: dt.datetime
    person_id: str  # the owner's opaque id; the domain never inspects it
    amount: MoneyValueObject
    date: dt.date  # the day the spend happened — no time; the sole basis for budget belonging
    description: str | None
    deleted_at: dt.datetime | None  # soft-delete; no default — only `create(...)` may birth a live expense

    @classmethod
    def create(
        cls,
        *,
        id: str,
        created_at: dt.datetime,
        person_id: str,
        amount: MoneyValueObject,
        date: dt.date,
        description: str | None,
    ) -> ExpenseEntity:
        """Create a brand-new, live expense — the only sanctioned way to be born."""
        if amount.value <= _ZERO:
            raise InvalidAmountError()
        trimmed = description.strip() if description else None
        return cls(
            id=id,
            created_at=created_at,
            person_id=person_id,
            amount=amount,
            date=date,
            description=trimmed or None,
            deleted_at=None,
        )

    # Identity equality: an expense IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, ExpenseEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
