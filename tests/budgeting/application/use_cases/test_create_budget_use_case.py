import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from tests.budgeting.fakes.fake_budget_repository import FakeBudgetRepository
from tests.core.fakes.fake_clock import FakeClock
from tests.core.fakes.fake_identifier_provider import FakeIdentifierProvider
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.data.create_budget_data import CreateBudgetData
from trocado.features.budgeting.application.use_cases.create_budget_use_case import (
    CreateBudgetUseCase,
)
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.domain.errors.invalid_budget_amount_error import (
    InvalidBudgetAmountError,
)
from trocado.features.budgeting.domain.errors.invalid_budget_range_error import (
    InvalidBudgetRangeError,
)
from trocado.features.budgeting.domain.errors.overlapping_budget_error import OverlappingBudgetError

_END = date(2026, 6, 30)
_START = date(2026, 6, 1)
_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _build_use_case(
    identifier: str = "budget-1",
    repository: FakeBudgetRepository | None = None,
) -> tuple[CreateBudgetUseCase, FakeBudgetRepository]:
    repository = repository or FakeBudgetRepository()
    use_case = CreateBudgetUseCase(
        repository=repository,
        clock=FakeClock(_FIXED_NOW),
        identifier=FakeIdentifierProvider(identifier),
    )

    return use_case, repository


def _command(
    *,
    amount: str = "500.00",
    start_date: date = _START,
    end_date: date = _END,
    note: str | None = "mercado",
    person_id: str = "person-1",
) -> CreateBudgetData:
    return CreateBudgetData(
        person_id=person_id,
        amount=Decimal(amount),
        start_date=start_date,
        end_date=end_date,
        note=note,
    )


def _live_budget(
    *,
    end_date: date,
    start_date: date,
    id: str = "existing",
    person_id: str = "person-1",
    deleted_at: datetime | None = None,
) -> BudgetEntity:
    budget = BudgetEntity.create(
        id=id,
        note=None,
        end_date=end_date,
        person_id=person_id,
        created_at=_FIXED_NOW,
        start_date=start_date,
        amount=MoneyValueObject(Decimal("100.00")),
    )
    budget.deleted_at = deleted_at

    return budget


def test_successful_registration_returns_public_data() -> None:
    use_case, repository = _build_use_case(identifier="new-id")

    data = asyncio.run(use_case.execute(_command()))

    assert data.id == "new-id"
    assert data.end_date == _END
    assert data.note == "mercado"
    assert data.start_date == _START
    assert data.person_id == "person-1"
    assert len(repository.budgets) == 1
    assert data.created_at == _FIXED_NOW
    assert data.amount == Decimal("500.00")


def test_id_and_created_at_come_from_ports() -> None:
    use_case, repository = _build_use_case(identifier="from-port")

    data = asyncio.run(use_case.execute(_command()))

    assert data.id == "from-port"
    assert data.created_at == _FIXED_NOW
    assert repository.budgets[0].id == "from-port"


def test_adjacent_budget_is_allowed() -> None:
    repository = FakeBudgetRepository()
    repository.budgets.append(_live_budget(start_date=date(2026, 5, 1), end_date=date(2026, 5, 31)))
    use_case, _ = _build_use_case(repository=repository)

    data = asyncio.run(use_case.execute(_command(start_date=date(2026, 6, 1), end_date=date(2026, 6, 30))))

    assert data.id == "budget-1"
    assert len(repository.budgets) == 2


def test_overlapping_budget_is_rejected() -> None:
    repository = FakeBudgetRepository()
    repository.budgets.append(_live_budget(start_date=date(2026, 6, 10), end_date=date(2026, 6, 20)))
    use_case, _ = _build_use_case(repository=repository)

    with pytest.raises(OverlappingBudgetError):
        asyncio.run(use_case.execute(_command(start_date=_START, end_date=_END)))
    assert len(repository.budgets) == 1


def test_shared_boundary_day_is_rejected() -> None:
    repository = FakeBudgetRepository()
    repository.budgets.append(_live_budget(start_date=date(2026, 5, 1), end_date=date(2026, 6, 1)))
    use_case, _ = _build_use_case(repository=repository)

    with pytest.raises(OverlappingBudgetError):
        asyncio.run(use_case.execute(_command(start_date=date(2026, 6, 1), end_date=_END)))
    assert len(repository.budgets) == 1


def test_soft_deleted_budget_does_not_block() -> None:
    repository = FakeBudgetRepository()
    repository.budgets.append(_live_budget(start_date=_START, end_date=_END, deleted_at=_FIXED_NOW))
    use_case, _ = _build_use_case(repository=repository)

    data = asyncio.run(use_case.execute(_command(start_date=_START, end_date=_END)))

    assert data.id == "budget-1"
    assert len(repository.budgets) == 2


def test_other_persons_budget_does_not_block() -> None:
    repository = FakeBudgetRepository()
    repository.budgets.append(_live_budget(start_date=_START, end_date=_END, person_id="person-2"))
    use_case, _ = _build_use_case(repository=repository)

    data = asyncio.run(use_case.execute(_command(start_date=_START, end_date=_END)))

    assert data.id == "budget-1"
    assert len(repository.budgets) == 2


def test_start_after_end_is_rejected() -> None:
    use_case, repository = _build_use_case()

    with pytest.raises(InvalidBudgetRangeError):
        asyncio.run(use_case.execute(_command(start_date=_END, end_date=_START)))
    assert repository.budgets == []


@pytest.mark.parametrize("amount", ["0", "0.00", "-5.00"])
def test_non_positive_amount_is_rejected(amount: str) -> None:
    use_case, repository = _build_use_case()

    with pytest.raises(InvalidBudgetAmountError):
        asyncio.run(use_case.execute(_command(amount=amount)))
    assert repository.budgets == []


def test_blank_note_becomes_absent() -> None:
    use_case, _ = _build_use_case()

    data = asyncio.run(use_case.execute(_command(note="   ")))

    assert data.note is None
