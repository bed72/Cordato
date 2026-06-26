from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.application.interfaces.partner_expense_reader_interface import (
    PartnerExpenseReaderInterface,
)


class FakePartnerExpenseReader(PartnerExpenseReaderInterface):
    """Returns each person's live expenses from a per-person map; unknown people read as empty.

    Seed with `{person_id: [PartnerExpenseData, ...]}`. Soft-delete filtering is the real adapter's job,
    so the seeded lists are assumed to already be live-only.
    """

    def __init__(self, by_person: dict[str, list[PartnerExpenseData]] | None = None) -> None:
        self._by_person = by_person or {}
        self.queried_ids: list[str] = []

    async def list_for_person(self, person_id: str) -> list[PartnerExpenseData]:
        self.queried_ids.append(person_id)
        return list(self._by_person.get(person_id, []))
