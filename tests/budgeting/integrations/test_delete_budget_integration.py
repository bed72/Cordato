import asyncio
from datetime import date
from decimal import Decimal

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.budgeting.application.data.create_budget_data import CreateBudgetData
from trocado.features.budgeting.application.data.delete_budget_data import DeleteBudgetData
from trocado.features.budgeting.application.use_cases.create_budget_use_case import (
    CreateBudgetUseCase,
)
from trocado.features.budgeting.application.use_cases.delete_budget_use_case import (
    DeleteBudgetUseCase,
)
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository

_END = date(2026, 6, 30)
_START = date(2026, 6, 1)


def _create(use_case: CreateBudgetUseCase, *, person_id: str, amount: str = "500.00") -> str:
    data = asyncio.run(
        use_case.execute(
            CreateBudgetData(
                note=None,
                end_date=_END,
                start_date=_START,
                person_id=person_id,
                amount=Decimal(amount),
            )
        )
    )
    return data.id


def test_deleting_a_budget_frees_its_range_without_rewiring() -> None:
    repository = BudgetRepository()
    create = CreateBudgetUseCase(clock=Clock(), repository=repository, identifier=IdentifierProvider())
    delete = DeleteBudgetUseCase(clock=Clock(), repository=repository)

    others = _create(create, person_id="person-2")
    removed = _create(create, person_id="person-1")

    asyncio.run(delete.execute(DeleteBudgetData(requester_id="person-1", budget_id=removed)))

    # The deleted budget drops out of every live read: its day no longer has an active budget.
    assert asyncio.run(repository.list_live_for_person("person-1")) == []
    assert asyncio.run(repository.find_active_for_person("person-1", date(2026, 6, 15))) is None

    # The freed range reopens: a fresh budget over the very same dates is created with no overlap error.
    replacement = _create(create, person_id="person-1", amount="700.00")
    active = asyncio.run(repository.find_active_for_person("person-1", date(2026, 6, 15)))
    assert active is not None
    assert active.id != removed
    assert active.id == replacement

    # The removed row survives for audit; the other person's budget is untouched and still live.
    audited = {budget.id: budget for budget in asyncio.run(repository.list_including_removed("person-1"))}
    assert audited.get(others) is None
    assert audited[removed].deleted_at is not None
    assert asyncio.run(repository.find_active_for_person("person-2", date(2026, 6, 15))) is not None
