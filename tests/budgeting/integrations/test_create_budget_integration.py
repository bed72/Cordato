import asyncio
from datetime import date
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.budgeting.application.data.create_budget_data import CreateBudgetData
from trocado.features.budgeting.application.interfaces.spend_reader_interface import (
    SpendReaderInterface,
)
from trocado.features.budgeting.application.use_cases.create_budget_use_case import (
    CreateBudgetUseCase,
)
from trocado.features.budgeting.application.use_cases.get_active_budget_use_case import (
    GetActiveBudgetUseCase,
)
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository
from trocado.features.expenses.application.data.create_expense_data import CreateExpenseData
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.application.use_cases.create_expense_use_case import (
    CreateExpenseUseCase,
)
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository

_ZERO = Decimal("0.00")
_END = date(2026, 6, 30)
_START = date(2026, 6, 1)


class _ExpenseLedgerSpendReader(SpendReaderInterface):
    """Composition-root bridge: satisfies budgeting's SpendReader by summing the expenses ledger.

    Only the wiring layer — which legitimately knows both modules — depends on `expenses`. Budgeting's
    own domain/application never do. When the ORM lands this is replaced by a gateway querying the
    shared expenses table directly.
    """

    def __init__(self, expenses: ExpenseRepositoryInterface) -> None:
        self._expenses = expenses

    async def total_spent(self, person_id: str, start: date, end: date) -> MoneyValueObject:
        spent = await self._expenses.find_in_range(person_id, start, end)
        return MoneyValueObject(sum((expense.amount.value for expense in spent), _ZERO))


def test_real_adapters_create_a_budget_and_derive_its_spend() -> None:
    clock = Clock()
    identifier = IdentifierProvider()
    budget_repository = BudgetRepository()
    expense_repository = ExpenseRepository()

    create_budget = CreateBudgetUseCase(clock=clock, repository=budget_repository, identifier=identifier)
    create_expense = CreateExpenseUseCase(clock=clock, repository=expense_repository, identifier=identifier)
    get_active = GetActiveBudgetUseCase(
        repository=budget_repository,
        spend_reader=_ExpenseLedgerSpendReader(expense_repository),
    )

    created = asyncio.run(
        create_budget.execute(
            CreateBudgetData(
                end_date=_END,
                start_date=_START,
                note="  mercado  ",
                person_id="person-1",
                amount=Decimal("500.00"),
            )
        )
    )

    asyncio.run(
        create_expense.execute(
            CreateExpenseData(
                description="feira",
                person_id="person-1",
                amount=Decimal("120.00"),
                occurred_on=date(2026, 6, 10),
            )
        )
    )

    # A real uuid7 string id (canonical 36-char form), trimmed note. The create response carries no spend.
    assert len(created.id) == 36
    assert created.note == "mercado"
    assert created.amount == Decimal("500.00")
    assert not hasattr(created, "total_spent")

    active = asyncio.run(get_active.execute("person-1", date(2026, 6, 15)))

    assert active is not None
    assert active.id == created.id
    assert active.remaining == Decimal("380.00")
    assert active.total_spent == Decimal("120.00")
