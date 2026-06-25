from datetime import date

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.interfaces.spend_reader_interface import (
    SpendReaderInterface,
)


class FakeSpendReader(SpendReaderInterface):
    """Returns a preconfigured total so the active-budget use case is tested in isolation."""

    def __init__(self, total: MoneyValueObject) -> None:
        self._total = total

    async def total_spent(self, person_id: str, start: date, end: date) -> MoneyValueObject:
        return self._total
