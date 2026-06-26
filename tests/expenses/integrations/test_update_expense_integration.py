import asyncio
from datetime import date
from decimal import Decimal

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.expenses.application.data.create_expense_data import CreateExpenseData
from trocado.features.expenses.application.data.update_expense_data import UpdateExpenseData
from trocado.features.expenses.application.use_cases.create_expense_use_case import (
    CreateExpenseUseCase,
)
from trocado.features.expenses.application.use_cases.update_expense_use_case import (
    UpdateExpenseUseCase,
)
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository

_IN_JUNE = date(2026, 6, 20)
_IN_JULY = date(2026, 7, 10)

# Two adjacent, non-overlapping budget windows. No budget row exists here — belonging is pure date math,
# so the test derives each budget's spend exactly as a budget would: sum the live expenses in its range.
_JUNE_END = date(2026, 6, 30)
_JULY_END = date(2026, 7, 31)
_JUNE_START = date(2026, 6, 1)
_JULY_START = date(2026, 7, 1)


def _record(use_case: CreateExpenseUseCase, *, person_id: str, amount: str, occurred_on: date) -> str:
    data = asyncio.run(
        use_case.execute(
            CreateExpenseData(person_id=person_id, amount=Decimal(amount), occurred_on=occurred_on, description=None)
        )
    )
    return data.id


def _spent(repository: ExpenseRepository, person_id: str, start: date, end: date) -> Decimal:
    found = asyncio.run(repository.find_in_range(person_id, start, end))
    return sum((expense.amount.value for expense in found), Decimal("0"))


def test_updating_an_expense_regroups_by_date_without_rewiring() -> None:
    repository = ExpenseRepository()
    update = UpdateExpenseUseCase(repository=repository)
    record = CreateExpenseUseCase(clock=Clock(), repository=repository, identifier=IdentifierProvider())

    moved = _record(record, person_id="person-1", amount="30.00", occurred_on=_IN_JUNE)

    # Starts under the June budget.
    assert _spent(repository, "person-1", _JULY_START, _JULY_END) == Decimal("0")
    assert _spent(repository, "person-1", _JUNE_START, _JUNE_END) == Decimal("30.00")

    # Move it into July's window and bump the amount — one update, no budget touched anywhere.
    asyncio.run(
        update.execute(
            UpdateExpenseData(
                expense_id=moved,
                description=None,
                occurred_on=_IN_JULY,
                amount=Decimal("45.00"),
                requester_id="person-1",
            )
        )
    )

    # The expense regrouped purely because find_in_range reads its new occurred_on — nothing was rewired.
    assert _spent(repository, "person-1", _JUNE_START, _JUNE_END) == Decimal("0")
    assert _spent(repository, "person-1", _JULY_START, _JULY_END) == Decimal("45.00")

    # Storage holds exactly one expense, the same id, now carrying the new day and amount.
    audited = asyncio.run(repository.list_including_removed("person-1"))
    assert len(audited) == 1
    assert audited[0].id == moved
    assert audited[0].occurred_on == _IN_JULY
    assert audited[0].amount.value == Decimal("45.00")
