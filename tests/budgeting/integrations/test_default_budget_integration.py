import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.budgeting.fakes.fake_expense_reader import FakeExpenseReader
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.data.ledger_expense_data import LedgerExpenseData
from trocado.features.budgeting.application.use_cases.get_default_budget_use_case import (
    GetDefaultBudgetUseCase,
)
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _expense(*, id: str, occurred_on: date, amount: str) -> LedgerExpenseData:
    return LedgerExpenseData(
        id=id,
        description=None,
        person_id="person-1",
        created_at=_FIXED_NOW,
        amount=Decimal(amount),
        occurred_on=occurred_on,
    )


def test_real_budget_repository_drives_the_default_bucket() -> None:
    repository = BudgetRepository()
    asyncio.run(
        repository.create(
            BudgetEntity.create(
                id="june",
                note=None,
                person_id="person-1",
                created_at=_FIXED_NOW,
                end_date=date(2026, 6, 30),
                start_date=date(2026, 6, 1),
                amount=MoneyValueObject(Decimal("500.00")),
            )
        )
    )

    reader = FakeExpenseReader(
        {
            "person-1": [
                _expense(id="covered", occurred_on=date(2026, 6, 15), amount="40.00"),
                _expense(id="leftover-july", occurred_on=date(2026, 7, 5), amount="12.00"),
                _expense(id="leftover-may", occurred_on=date(2026, 5, 20), amount="8.00"),
            ]
        }
    )

    use_case = GetDefaultBudgetUseCase(repository=repository, expense_reader=reader)

    data = asyncio.run(use_case.execute("person-1"))

    # Only the expenses outside June's range survive, newest-first, summed exactly. No limit, no remaining.
    assert data.total_spent == Decimal("20.00")
    assert [item.id for item in data.expenses] == ["leftover-july", "leftover-may"]
