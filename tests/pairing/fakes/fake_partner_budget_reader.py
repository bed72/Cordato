from datetime import date

from trocado.features.pairing.application.data.partner_active_budget_data import (
    PartnerActiveBudgetData,
)
from trocado.features.pairing.application.interfaces.partner_budget_reader_interface import (
    PartnerBudgetReaderInterface,
)


class FakePartnerBudgetReader(PartnerBudgetReaderInterface):
    """Returns each person's active budget from a per-person map; unknown people read as `None`.

    Seed with `{person_id: PartnerActiveBudgetData}`. The active/live resolution is the real adapter's job,
    so a seeded entry is assumed to already be the person's active budget for the queried day.
    """

    def __init__(self, by_person: dict[str, PartnerActiveBudgetData] | None = None) -> None:
        self._by_person = by_person or {}
        self.queried: list[tuple[str, date]] = []

    async def active_for_person(self, person_id: str, day: date) -> PartnerActiveBudgetData | None:
        self.queried.append((person_id, day))
        return self._by_person.get(person_id)
