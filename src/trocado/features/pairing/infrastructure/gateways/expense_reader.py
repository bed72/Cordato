from __future__ import annotations

from datetime import date
from decimal import Decimal

from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.application.interfaces.expense_reader_interface import ExpenseReaderInterface
from trocado.features.pairing.infrastructure.gateways.rows.expense_row import ExpenseRow


class ExpenseReader(ExpenseReaderInterface):
    """Duplicates the filters ``ExpenseRepository.find_in_range`` and
    ``ExpenseRepository.list_live_for_person`` apply, over pairing's own local rows instead of
    importing the expenses module's entity or repository.

    Pre-ORM this store is never populated from real expense data — the same isolated behavior pairing
    already had via its own repository instance; the ORM replaces this with a real query against the
    shared table without ever reintroducing the cross-feature import.
    """

    def __init__(self) -> None:
        self._rows: dict[str, ExpenseRow] = {}

    async def find_amounts_in_range(self, person_id: str, start: date, end: date) -> list[Decimal]:
        return [
            row.amount
            for row in self._rows.values()
            if row.person_id == person_id and row.deleted_at is None and start <= row.occurred_on <= end
        ]

    async def list_live_for_person(self, person_id: str) -> list[PartnerExpenseData]:
        return [
            PartnerExpenseData(
                id=row.id,
                amount=row.amount,
                person_id=row.person_id,
                created_at=row.created_at,
                description=row.description,
                occurred_on=row.occurred_on,
            )
            for row in self._rows.values()
            if row.person_id == person_id and row.deleted_at is None
        ]
