import asyncio
from datetime import date
from decimal import Decimal

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.expenses.application.data.create_expense_data import CreateExpenseData
from trocado.features.expenses.application.use_cases.create_expense_use_case import (
    CreateExpenseUseCase,
)
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository


def _build() -> tuple[CreateExpenseUseCase, ExpenseRepository]:
    repository = ExpenseRepository()
    use_case = CreateExpenseUseCase(
        clock=Clock(),
        repository=repository,
        identifier=IdentifierProvider(),
    )

    return use_case, repository


def test_real_adapters_record_an_expense() -> None:
    use_case, _ = _build()

    data = asyncio.run(
        use_case.execute(
            CreateExpenseData(
                person_id="person-1",
                amount=Decimal("19.90"),
                description="  almoço  ",
                occurred_on=date(2026, 6, 20),
            )
        )
    )

    # A real uuid7 string id (canonical 36-char form) and a timezone-aware timestamp.
    assert len(data.id) == 36
    assert data.person_id == "person-1"
    assert data.description == "almoço"
    assert data.amount == Decimal("19.90")
    assert data.created_at.tzinfo is not None
