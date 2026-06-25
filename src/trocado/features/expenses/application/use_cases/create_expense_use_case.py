from __future__ import annotations

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.application.data.create_expense_data import CreateExpenseData
from trocado.features.expenses.application.data.expense_data import ExpenseData
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.application.mappers.expense_data_mapper import ExpenseDataMapper
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity


class CreateExpenseUseCase:
    """Record a new expense: build money, assign identity + timestamp, persist, return public data."""

    def __init__(
        self,
        clock: ClockInterface,
        repository: ExpenseRepositoryInterface,
        identifier: IdentifierProviderInterface,
    ) -> None:
        self._clock = clock
        self._repository = repository
        self._identifier = identifier

    async def execute(self, data: CreateExpenseData) -> ExpenseData:
        amount = MoneyValueObject(data.amount)

        id = await self._identifier.generate()
        created_at = await self._clock.now()

        expense = ExpenseEntity.create(
            id=id,
            amount=amount,
            date=data.date,
            created_at=created_at,
            person_id=data.person_id,
            description=data.description,
        )
        await self._repository.create(expense)

        return ExpenseDataMapper.to_data(expense)
