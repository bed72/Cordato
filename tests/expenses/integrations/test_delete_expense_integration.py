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
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository

_A_DAY = date(2026, 6, 20)
_RANGE_END = date(2026, 6, 30)
_RANGE_START = date(2026, 6, 1)


def _record(use_case: CreateExpenseUseCase, *, person_id: str, amount: str) -> str:
    data = asyncio.run(
        use_case.execute(
            CreateExpenseData(person_id=person_id, amount=Decimal(amount), occurred_on=_A_DAY, description=None)
        )
    )
    return data.id


def _spent(repository: ExpenseRepository, person_id: str) -> Decimal:
    # Exactly how a budget derives its spend: sum the owner's live expenses inside the range. No stored link.
    found = asyncio.run(repository.find_in_range(person_id, _RANGE_START, _RANGE_END))
    return sum((expense.amount.value for expense in found), Decimal("0"))


def test_deleting_an_expense_recomputes_spend_without_rewiring() -> None:
    repository = ExpenseRepository()
    delete = DeleteExpenseUseCase(clock=Clock(), repository=repository)
    record = CreateExpenseUseCase(clock=Clock(), repository=repository, identifier=IdentifierProvider())

    kept = _record(record, person_id="person-1", amount="30.00")
    others = _record(record, person_id="person-2", amount="99.00")
    removed = _record(record, person_id="person-1", amount="20.00")

    assert _spent(repository, "person-1") == Decimal("50.00")

    asyncio.run(delete.execute(DeleteExpenseData(requester_id="person-1", expense_id=removed)))

    # The covering budget's spend drops by the removed amount — purely because find_in_range omits it now.
    assert _spent(repository, "person-1") == Decimal("30.00")

    # The removed row survives for audit; the kept one and the other person's are untouched.
    audited = {expense.id: expense for expense in asyncio.run(repository.list_including_removed("person-1"))}
    assert audited.get(others) is None
    assert audited[kept].deleted_at is None
    assert audited[removed].deleted_at is not None
    assert _spent(repository, "person-2") == Decimal("99.00")
