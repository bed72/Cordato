from __future__ import annotations

import asyncio

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.pairing.application.data.couple_expense_data import CoupleExpenseData
from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.application.interfaces.pair_repository_interface import (
    PairRepositoryInterface,
)
from trocado.features.pairing.application.interfaces.partner_expense_reader_interface import (
    PartnerExpenseReaderInterface,
)
from trocado.features.pairing.application.mappers.couple_expense_data_mapper import (
    CoupleExpenseDataMapper,
)
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError
from trocado.features.pairing.domain.virtual_objects.couple_expense_virtual_object import (
    CoupleExpenseVirtualObject,
)


class GetCoupleExpensesUseCase:
    """Derive the couple view: the union of both partners' live expenses, each marked mine/theirs."""

    def __init__(
        self,
        repository: PairRepositoryInterface,
        partner_expense_reader: PartnerExpenseReaderInterface,
    ) -> None:
        self._repository = repository
        self._partner_expense_reader = partner_expense_reader

    async def execute(self, reader_id: str) -> list[CoupleExpenseData]:
        # No live pair, no couple to look through — guard before any expense read.
        pair = await self._repository.find_active_by_person(reader_id)
        if pair is None:
            raise NotPairedError()

        partner_id = pair.person_b_id if reader_id == pair.person_a_id else pair.person_a_id

        # Both ledgers are read independently — issue them together.
        mine, theirs = await asyncio.gather(
            self._partner_expense_reader.list_for_person(reader_id),
            self._partner_expense_reader.list_for_person(partner_id),
        )

        virtual_objects = [self._to_virtual_object(expense, reader_id) for expense in (*mine, *theirs)]
        virtual_objects.sort(key=lambda item: (item.occurred_on, item.created_at), reverse=True)

        return [CoupleExpenseDataMapper.to_data(item) for item in virtual_objects]

    @staticmethod
    def _to_virtual_object(expense: PartnerExpenseData, reader_id: str) -> CoupleExpenseVirtualObject:
        return CoupleExpenseVirtualObject(
            reader_id=reader_id,
            expense_id=expense.id,
            owner_id=expense.person_id,
            created_at=expense.created_at,
            description=expense.description,
            occurred_on=expense.occurred_on,
            amount=MoneyValueObject(expense.amount),
        )
