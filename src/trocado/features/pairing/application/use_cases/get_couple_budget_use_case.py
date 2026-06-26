from __future__ import annotations

import asyncio
from datetime import date

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.pairing.application.data.couple_budget_data import CoupleBudgetData
from trocado.features.pairing.application.data.partner_active_budget_data import (
    PartnerActiveBudgetData,
)
from trocado.features.pairing.application.interfaces.pair_repository_interface import (
    PairRepositoryInterface,
)
from trocado.features.pairing.application.interfaces.partner_budget_reader_interface import (
    PartnerBudgetReaderInterface,
)
from trocado.features.pairing.application.mappers.couple_budget_data_mapper import (
    CoupleBudgetDataMapper,
)
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError
from trocado.features.pairing.domain.virtual_objects.couple_budget_virtual_object import (
    CoupleBudgetVirtualObject,
)
from trocado.features.pairing.domain.virtual_objects.partner_active_budget_virtual_object import (
    PartnerActiveBudgetVirtualObject,
)


class GetCoupleBudgetUseCase:
    """Derive the couple budget: the combined panorama over both partners' active budgets for a day."""

    def __init__(
        self,
        repository: PairRepositoryInterface,
        partner_budget_reader: PartnerBudgetReaderInterface,
    ) -> None:
        self._repository = repository
        self._partner_budget_reader = partner_budget_reader

    async def execute(self, reader_id: str, day: date) -> CoupleBudgetData | None:
        # No live pair, no couple to look through — guard before any budget read.
        pair = await self._repository.find_active_by_person(reader_id)
        if pair is None:
            raise NotPairedError()

        partner_id = pair.person_b_id if reader_id == pair.person_a_id else pair.person_a_id

        # Both partners' active budgets are read independently — issue them together.
        mine, theirs = await asyncio.gather(
            self._partner_budget_reader.active_for_person(reader_id, day),
            self._partner_budget_reader.active_for_person(partner_id, day),
        )

        # The panorama spans whoever has an active budget; with neither present there is none to view.
        present = [budget for budget in (mine, theirs) if budget is not None]
        if not present:
            return None

        view = CoupleBudgetVirtualObject(tuple(self._to_virtual_object(budget) for budget in present))
        return CoupleBudgetDataMapper.to_data(view)

    @staticmethod
    def _to_virtual_object(budget: PartnerActiveBudgetData) -> PartnerActiveBudgetVirtualObject:
        return PartnerActiveBudgetVirtualObject(
            end_date=budget.end_date,
            start_date=budget.start_date,
            amount=MoneyValueObject(budget.amount),
            total_spent=MoneyValueObject(budget.total_spent),
        )
