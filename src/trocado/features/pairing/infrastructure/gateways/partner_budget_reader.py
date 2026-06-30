from __future__ import annotations

from collections.abc import Awaitable, Callable
from datetime import date

from trocado.features.pairing.application.data.partner_active_budget_data import PartnerActiveBudgetData
from trocado.features.pairing.application.interfaces.partner_budget_reader_interface import (
    PartnerBudgetReaderInterface,
)


class PartnerBudgetReader(PartnerBudgetReaderInterface):
    def __init__(self, find_active_budget: Callable[[str, date], Awaitable[PartnerActiveBudgetData | None]]) -> None:
        self._find_active_budget = find_active_budget

    async def active_for_person(self, person_id: str, day: date) -> PartnerActiveBudgetData | None:
        return await self._find_active_budget(person_id, day)
