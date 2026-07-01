from __future__ import annotations

from datetime import date
from decimal import Decimal

from trocado.features.budgeting.application.interfaces.expense_amount_reader_interface import (
    ExpenseAmountReaderInterface,
)
from trocado.features.budgeting.infrastructure.gateways.rows.expense_amount_row import ExpenseAmountRow


class ExpenseAmountReader(ExpenseAmountReaderInterface):
    """Duplicates the filter ``ExpenseRepository.find_in_range`` applies (owner, live, within range) over
    budgeting's own local rows instead of importing the expenses module's entity or repository.

    Pre-ORM this store is never populated from real expense data — the same isolated behavior budgeting
    already had via its own repository instance; the ORM replaces this with a real query against the
    shared table without ever reintroducing the cross-feature import.
    """

    def __init__(self) -> None:
        self._rows: dict[str, ExpenseAmountRow] = {}

    async def find_amounts_in_range(self, person_id: str, start: date, end: date) -> list[Decimal]:
        return [
            row.amount
            for row in self._rows.values()
            if row.person_id == person_id and row.deleted_at is None and start <= row.occurred_on <= end
        ]
