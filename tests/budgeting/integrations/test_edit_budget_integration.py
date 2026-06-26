import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.budgeting.fakes.fake_expense_reader import FakeExpenseReader
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.budgeting.application.data.create_budget_data import CreateBudgetData
from trocado.features.budgeting.application.data.edit_budget_data import EditBudgetData
from trocado.features.budgeting.application.data.ledger_expense_data import LedgerExpenseData
from trocado.features.budgeting.application.use_cases.create_budget_use_case import (
    CreateBudgetUseCase,
)
from trocado.features.budgeting.application.use_cases.edit_budget_use_case import EditBudgetUseCase
from trocado.features.budgeting.application.use_cases.get_default_budget_use_case import (
    GetDefaultBudgetUseCase,
)
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


def _snapshot(reader: FakeExpenseReader) -> list[tuple[str, date, Decimal]]:
    expenses = asyncio.run(reader.list_for_person("person-1"))
    return [(item.id, item.occurred_on, item.amount) for item in expenses]


def test_editing_the_range_regroups_expenses_without_touching_them() -> None:
    repository = BudgetRepository()
    create = CreateBudgetUseCase(clock=Clock(), repository=repository, identifier=IdentifierProvider())
    edit = EditBudgetUseCase(repository=repository)

    reader = FakeExpenseReader(
        {
            "person-1": [
                _expense(id="mid-june", occurred_on=date(2026, 6, 20), amount="40.00"),
                _expense(id="july", occurred_on=date(2026, 7, 5), amount="12.00"),
            ]
        }
    )
    default = GetDefaultBudgetUseCase(repository=repository, expense_reader=reader)

    before_edit = _snapshot(reader)

    budget = asyncio.run(
        create.execute(
            CreateBudgetData(
                note=None,
                person_id="person-1",
                amount=Decimal("500.00"),
                end_date=date(2026, 6, 30),
                start_date=date(2026, 6, 1),
            )
        )
    )

    # June covers the mid-June spend, so only July falls into the default bucket.
    covering = asyncio.run(default.execute("person-1"))
    assert covering.total_spent == Decimal("12.00")
    assert [item.id for item in covering.expenses] == ["july"]

    # Narrow the budget so it no longer covers June 20 — a pure date edit, no expense referenced.
    asyncio.run(
        edit.execute(
            EditBudgetData(
                note=None,
                budget_id=budget.id,
                requester_id="person-1",
                amount=Decimal("500.00"),
                end_date=date(2026, 6, 10),
                start_date=date(2026, 6, 1),
            )
        )
    )

    # The mid-June spend now belongs to no live budget: it falls to the default bucket on the next read.
    narrowed = asyncio.run(default.execute("person-1"))
    assert narrowed.total_spent == Decimal("52.00")
    assert [item.id for item in narrowed.expenses] == ["july", "mid-june"]

    # Widen it back to cover June 20 again — the grouping flips back, still with no stored rewiring.
    asyncio.run(
        edit.execute(
            EditBudgetData(
                note=None,
                budget_id=budget.id,
                requester_id="person-1",
                amount=Decimal("500.00"),
                end_date=date(2026, 6, 30),
                start_date=date(2026, 6, 1),
            )
        )
    )
    widened = asyncio.run(default.execute("person-1"))
    assert widened.total_spent == Decimal("12.00")
    assert [item.id for item in widened.expenses] == ["july"]

    # Through every range edit, not a single expense was modified, relinked, or deleted.
    assert _snapshot(reader) == before_edit
