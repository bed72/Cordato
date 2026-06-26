from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.domain.errors.invalid_amount_error import InvalidAmountError

_ZERO = Decimal("0")


@dataclass(eq=False, slots=True)
class ExpenseEntity:
    """An expense — the domain's atomic fact: who spent, how much, on what day. Points to no budget."""

    id: str
    person_id: str  # the owner's opaque id; the domain never inspects it
    occurred_on: date  # the day the spend happened — no time; the sole basis for budget belonging
    created_at: datetime
    description: str | None
    amount: MoneyValueObject
    deleted_at: datetime | None  # soft-delete; no default — only `create(...)` may birth a live expense

    @classmethod
    def create(
        cls,
        *,
        id: str,
        person_id: str,
        occurred_on: date,
        created_at: datetime,
        description: str | None,
        amount: MoneyValueObject,
    ) -> ExpenseEntity:
        """Create a brand-new, live expense — the only sanctioned way to be born."""
        if amount.value <= _ZERO:
            raise InvalidAmountError()
        trimmed = description.strip() if description else None
        return cls(
            id=id,
            amount=amount,
            deleted_at=None,
            person_id=person_id,
            created_at=created_at,
            occurred_on=occurred_on,
            description=trimmed or None,
        )

    def edit(self, *, amount: MoneyValueObject, occurred_on: date, description: str | None) -> None:
        """Overwrite the editable fields in place — amount, day, description — keeping identity and
        lifecycle untouched. Re-runs the same guard as ``create``: the amount must be positive, and the
        description is normalized (blank/whitespace → absent). ``id``, ``person_id``, ``created_at`` and
        ``deleted_at`` are left exactly as they were."""
        if amount.value <= _ZERO:
            raise InvalidAmountError()
        trimmed = description.strip() if description else None
        self.amount = amount
        self.occurred_on = occurred_on
        self.description = trimmed or None

    def delete(self, at: datetime) -> None:
        """Stamp the removal instant, retiring the expense from every normal read. The only path out of the
        live state — soft-delete, the row stays for audit."""
        self.deleted_at = at

    # Identity equality: an expense IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, ExpenseEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
