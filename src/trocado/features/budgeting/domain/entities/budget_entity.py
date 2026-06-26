from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.domain.errors.invalid_budget_amount_error import (
    InvalidBudgetAmountError,
)
from trocado.features.budgeting.domain.errors.invalid_budget_range_error import (
    InvalidBudgetRangeError,
)

_ZERO = Decimal("0")


@dataclass(eq=False, slots=True)
class BudgetEntity:
    """A budget — a planned ceiling over an inclusive date range, owned by one person.

    Holds no list of expenses: spend is derived at read-time by date containment, never stored.
    """

    id: str
    end_date: date  # inclusive upper bound — no time
    person_id: str  # the owner's opaque id; the domain never inspects it
    note: str | None
    start_date: date  # inclusive lower bound — no time
    created_at: datetime
    amount: MoneyValueObject
    deleted_at: datetime | None  # soft-delete; no default — only `create(...)` may birth a live budget

    @classmethod
    def create(
        cls,
        *,
        id: str,
        person_id: str,
        note: str | None,
        end_date: date,
        start_date: date,
        created_at: datetime,
        amount: MoneyValueObject,
    ) -> BudgetEntity:
        """Create a brand-new, live budget — the only sanctioned way to be born."""
        if amount.value <= _ZERO:
            raise InvalidBudgetAmountError()
        if start_date > end_date:
            raise InvalidBudgetRangeError()
        trimmed = note.strip() if note else None
        return cls(
            id=id,
            amount=amount,
            deleted_at=None,
            end_date=end_date,
            person_id=person_id,
            note=trimmed or None,
            created_at=created_at,
            start_date=start_date,
        )

    def update(
        self,
        *,
        note: str | None,
        end_date: date,
        start_date: date,
        amount: MoneyValueObject,
    ) -> None:
        """Overwrite the editable fields in place, re-running the same invariants ``create`` enforces.

        A full replacement of the four editable fields — amount, range, and note — keeping ``id``,
        ``person_id``, ``created_at`` and ``deleted_at`` untouched: an update corrects a budget, it never
        changes its identity nor its lifecycle position. The non-overlap invariant is *not* checked here
        (it needs the person's other live budgets, which only the repository can supply) — it stays in the
        use case, exactly as at creation.
        """
        if amount.value <= _ZERO:
            raise InvalidBudgetAmountError()
        if start_date > end_date:
            raise InvalidBudgetRangeError()
        trimmed = note.strip() if note else None
        self.amount = amount
        self.end_date = end_date
        self.start_date = start_date
        self.note = trimmed or None

    def delete(self, at: datetime) -> None:
        """Stamp the removal instant, retiring the budget from every normal read. The only path out of the
        live state — soft-delete, the row stays for audit. Frees the date range: the non-overlap check sees
        only live budgets, so a new budget may then occupy these dates with no rewiring."""
        self.deleted_at = at

    def overlaps(self, other: BudgetEntity) -> bool:
        """Whether this budget shares any date with another, treating both ends as inclusive.

        Two inclusive ranges overlap iff each starts on or before the other ends — so a shared
        boundary day counts as overlap, while merely adjacent ranges (one ends the day before the
        other starts) do not.
        """
        return self.start_date <= other.end_date and other.start_date <= self.end_date

    def covers(self, day: date) -> bool:
        """Whether ``day`` falls within this budget's inclusive range — the single-day sibling of
        ``overlaps``. Both ends count: a day equal to ``start_date`` or ``end_date`` is covered. This is
        the date-containment rule behind budget belonging — an expense belongs to a budget when its day
        is covered, with no stored link.
        """
        return self.start_date <= day <= self.end_date

    # Identity equality: a budget IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, BudgetEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
