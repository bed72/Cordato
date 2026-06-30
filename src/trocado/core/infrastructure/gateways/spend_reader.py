from __future__ import annotations

from collections.abc import Awaitable, Callable
from datetime import date
from decimal import Decimal

from trocado.core.application.interfaces.spend_reader_interface import SpendReaderInterface
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject


class SpendReader(SpendReaderInterface):
    def __init__(self, fetch_amounts: Callable[[str, date, date], Awaitable[list[Decimal]]]) -> None:
        self._fetch_amounts = fetch_amounts

    async def total_spent(self, person_id: str, start: date, end: date) -> MoneyValueObject:
        amounts = await self._fetch_amounts(person_id, start, end)
        return MoneyValueObject(sum(amounts, Decimal("0.00")))
