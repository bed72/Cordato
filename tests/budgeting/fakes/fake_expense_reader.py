from trocado.features.budgeting.application.data.ledger_expense_data import LedgerExpenseData
from trocado.features.budgeting.application.interfaces.expense_reader_interface import (
    ExpenseReaderInterface,
)


class FakeExpenseReader(ExpenseReaderInterface):
    """Returns each person's live expenses from a per-person map; unknown people read as empty.

    Seed with `{person_id: [LedgerExpenseData, ...]}`. Soft-delete filtering is the real adapter's job,
    so the seeded lists are assumed to already be live-only.
    """

    def __init__(self, by_person: dict[str, list[LedgerExpenseData]] | None = None) -> None:
        self._by_person = by_person or {}
        self.queried_ids: list[str] = []

    async def list_for_person(self, person_id: str) -> list[LedgerExpenseData]:
        self.queried_ids.append(person_id)
        return list(self._by_person.get(person_id, []))
