from __future__ import annotations

import asyncio

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.data.budget_data import BudgetData
from trocado.features.budgeting.application.data.create_budget_data import CreateBudgetData
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.mappers.budget_data_mapper import BudgetDataMapper
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.domain.errors.overlapping_budget_error import OverlappingBudgetError


class CreateBudgetUseCase:
    """Register a budget: build it, assert it overlaps none of the person's live budgets, persist."""

    def __init__(
        self,
        clock: ClockInterface,
        repository: BudgetRepositoryInterface,
        identifier: IdentifierProviderInterface,
    ) -> None:
        self._clock = clock
        self._repository = repository
        self._identifier = identifier

    async def execute(self, data: CreateBudgetData) -> BudgetData:
        amount = MoneyValueObject(data.amount)

        created_at, id = await asyncio.gather(
            self._clock.now(),
            self._identifier.generate(),
        )

        budget = BudgetEntity.create(
            id=id,
            amount=amount,
            note=data.note,
            created_at=created_at,
            end_date=data.end_date,
            person_id=data.person_id,
            start_date=data.start_date,
        )

        existing = await self._repository.list_live_for_person(data.person_id)
        if any(budget.overlaps(other) for other in existing):
            raise OverlappingBudgetError()

        await self._repository.create(budget)

        return BudgetDataMapper.to_data(budget)
