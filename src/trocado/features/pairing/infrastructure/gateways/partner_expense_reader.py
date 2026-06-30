from __future__ import annotations

from collections.abc import Awaitable, Callable

from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.application.interfaces.partner_expense_reader_interface import (
    PartnerExpenseReaderInterface,
)


class PartnerExpenseReader(PartnerExpenseReaderInterface):
    def __init__(self, list_expenses: Callable[[str], Awaitable[list[PartnerExpenseData]]]) -> None:
        self._list_expenses = list_expenses

    async def list_for_person(self, person_id: str) -> list[PartnerExpenseData]:
        return await self._list_expenses(person_id)
