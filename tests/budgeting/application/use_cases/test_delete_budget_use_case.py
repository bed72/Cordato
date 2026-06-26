import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from tests.budgeting.fakes.fake_budget_repository import FakeBudgetRepository
from tests.core.fakes.fake_clock import FakeClock
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.data.delete_budget_data import DeleteBudgetData
from trocado.features.budgeting.application.use_cases.delete_budget_use_case import (
    DeleteBudgetUseCase,
)
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.domain.errors.budget_not_found_error import BudgetNotFoundError

_END = date(2026, 6, 30)
_START = date(2026, 6, 1)
_CREATED_AT = datetime(2026, 6, 1, tzinfo=UTC)
_DELETED_AT = datetime(2026, 6, 24, tzinfo=UTC)


def _a_budget(
    *,
    id: str = "budget-1",
    person_id: str = "person-1",
    deleted_at: datetime | None = None,
) -> BudgetEntity:
    budget = BudgetEntity.create(
        id=id,
        note="mercado",
        end_date=_END,
        start_date=_START,
        person_id=person_id,
        created_at=_CREATED_AT,
        amount=MoneyValueObject(Decimal("500.00")),
    )
    budget.deleted_at = deleted_at

    return budget


def _build_use_case(*budgets: BudgetEntity) -> tuple[DeleteBudgetUseCase, FakeBudgetRepository]:
    repository = FakeBudgetRepository()
    repository.budgets.extend(budgets)
    use_case = DeleteBudgetUseCase(clock=FakeClock(_DELETED_AT), repository=repository)

    return use_case, repository


def _command(requester_id: str = "person-1", budget_id: str = "budget-1") -> DeleteBudgetData:
    return DeleteBudgetData(requester_id=requester_id, budget_id=budget_id)


def test_owner_soft_deletes_own_live_budget() -> None:
    budget = _a_budget()
    use_case, repository = _build_use_case(budget)

    result = asyncio.run(use_case.execute(_command()))

    assert result is None
    assert budget.deleted_at == _DELETED_AT
    # Gone from normal reads, still present in the audit read.
    assert asyncio.run(repository.list_live_for_person("person-1")) == []
    assert asyncio.run(repository.list_including_removed("person-1")) == [budget]
    assert asyncio.run(repository.find_active_for_person("person-1", date(2026, 6, 15))) is None


def test_unknown_id_is_rejected_and_changes_nothing() -> None:
    use_case, repository = _build_use_case(_a_budget())

    with pytest.raises(BudgetNotFoundError):
        asyncio.run(use_case.execute(_command(budget_id="ghost")))
    assert repository.budgets[0].deleted_at is None


def test_another_persons_budget_is_rejected_and_left_untouched() -> None:
    theirs = _a_budget(id="theirs", person_id="person-2")
    use_case, _ = _build_use_case(theirs)

    with pytest.raises(BudgetNotFoundError):
        asyncio.run(use_case.execute(_command(budget_id="theirs")))
    assert theirs.deleted_at is None


def test_already_deleted_budget_is_rejected_without_overwriting() -> None:
    original = datetime(2026, 6, 21, tzinfo=UTC)
    removed = _a_budget(deleted_at=original)
    use_case, _ = _build_use_case(removed)

    with pytest.raises(BudgetNotFoundError):
        asyncio.run(use_case.execute(_command()))
    # The original removal instant is never moved by a second delete.
    assert removed.deleted_at == original
