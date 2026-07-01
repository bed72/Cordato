from __future__ import annotations

from datetime import date

from trocado.features.pairing.application.data.active_budget_reading_data import ActiveBudgetReadingData
from trocado.features.pairing.application.interfaces.budget_reader_interface import BudgetReaderInterface
from trocado.features.pairing.infrastructure.gateways.rows.budget_row import BudgetRow


class BudgetReader(BudgetReaderInterface):
    """Duplicates the filter ``BudgetRepository.find_active_for_person`` applies (owner, live, containing
    the day) over pairing's own local rows instead of importing the budgeting module's entity or
    repository.

    Pre-ORM this store is never populated from real budget data — the same isolated behavior pairing
    already had via its own repository instance; the ORM replaces this with a real query against the
    shared table without ever reintroducing the cross-feature import.
    """

    def __init__(self) -> None:
        self._rows: dict[str, BudgetRow] = {}

    async def find_active_for_person(self, person_id: str, day: date) -> ActiveBudgetReadingData | None:
        for row in self._rows.values():
            if row.person_id == person_id and row.deleted_at is None and row.start_date <= day <= row.end_date:
                return ActiveBudgetReadingData(start_date=row.start_date, end_date=row.end_date, amount=row.amount)
        return None
