import asyncio
from datetime import date
from decimal import Decimal

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.expenses.application.data.create_expense_data import CreateExpenseData
from trocado.features.expenses.application.data.delete_expense_data import DeleteExpenseData
from trocado.features.expenses.application.use_cases.create_expense_use_case import (
    CreateExpenseUseCase,
)
from trocado.features.expenses.application.use_cases.delete_expense_use_case import (
    DeleteExpenseUseCase,
)
from trocado.features.expenses.application.use_cases.list_expenses_use_case import ListExpensesUseCase
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository


def _record(use_case: CreateExpenseUseCase, *, person_id: str, amount: str, occurred_on: date) -> str:
    data = asyncio.run(
        use_case.execute(
            CreateExpenseData(
                description=None,
                person_id=person_id,
                amount=Decimal(amount),
                occurred_on=occurred_on,
            )
        )
    )
    return data.id


def test_real_repository_lists_only_the_owners_live_expenses_most_recent_first() -> None:
    repository = ExpenseRepository()
    record = CreateExpenseUseCase(clock=Clock(), repository=repository, identifier=IdentifierProvider())
    delete = DeleteExpenseUseCase(clock=Clock(), repository=repository)
    listing = ListExpensesUseCase(repository=repository)

    older = _record(record, person_id="person-1", amount="10.00", occurred_on=date(2026, 6, 10))
    newer = _record(record, person_id="person-1", amount="20.00", occurred_on=date(2026, 6, 20))
    removed = _record(record, person_id="person-1", amount="99.00", occurred_on=date(2026, 6, 25))
    _record(record, person_id="person-2", amount="50.00", occurred_on=date(2026, 6, 21))

    asyncio.run(delete.execute(DeleteExpenseData(requester_id="person-1", expense_id=removed)))

    data = asyncio.run(listing.execute("person-1"))

    # Soft-deleted and the other person's expenses are gone; the rest is newest-first.
    assert [item.id for item in data] == [newer, older]
    assert [item.amount for item in data] == [Decimal("20.00"), Decimal("10.00")]
