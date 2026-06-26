import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from tests.budgeting.fakes.fake_budget_repository import FakeBudgetRepository
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.data.update_budget_data import UpdateBudgetData
from trocado.features.budgeting.application.use_cases.update_budget_use_case import UpdateBudgetUseCase
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.domain.errors.budget_not_found_error import BudgetNotFoundError
from trocado.features.budgeting.domain.errors.invalid_budget_amount_error import (
    InvalidBudgetAmountError,
)
from trocado.features.budgeting.domain.errors.invalid_budget_range_error import (
    InvalidBudgetRangeError,
)
from trocado.features.budgeting.domain.errors.overlapping_budget_error import OverlappingBudgetError

_END = date(2026, 6, 30)
_START = date(2026, 6, 1)
_CREATED_AT = datetime(2026, 6, 1, tzinfo=UTC)


def _a_budget(
    *,
    id: str = "budget-1",
    amount: str = "500.00",
    end_date: date = _END,
    start_date: date = _START,
    person_id: str = "person-1",
    note: str | None = "mercado",
    deleted_at: datetime | None = None,
) -> BudgetEntity:
    budget = BudgetEntity.create(
        id=id,
        note=note,
        end_date=end_date,
        person_id=person_id,
        start_date=start_date,
        created_at=_CREATED_AT,
        amount=MoneyValueObject(Decimal(amount)),
    )
    budget.deleted_at = deleted_at

    return budget


def _build_use_case(*budgets: BudgetEntity) -> tuple[UpdateBudgetUseCase, FakeBudgetRepository]:
    repository = FakeBudgetRepository()
    repository.budgets.extend(budgets)
    use_case = UpdateBudgetUseCase(repository=repository)

    return use_case, repository


def _command(
    *,
    amount: str = "900.00",
    budget_id: str = "budget-1",
    note: str | None = "aluguel",
    requester_id: str = "person-1",
    end_date: date = date(2026, 7, 31),
    start_date: date = date(2026, 7, 1),
) -> UpdateBudgetData:
    return UpdateBudgetData(
        note=note,
        end_date=end_date,
        budget_id=budget_id,
        start_date=start_date,
        amount=Decimal(amount),
        requester_id=requester_id,
    )


def test_owner_updates_own_live_budget_and_keeps_identity() -> None:
    use_case, repository = _build_use_case(_a_budget())

    data = asyncio.run(use_case.execute(_command()))

    assert data.id == "budget-1"
    assert data.note == "aluguel"
    assert data.person_id == "person-1"
    assert data.created_at == _CREATED_AT
    assert data.amount == Decimal("900.00")
    assert data.end_date == date(2026, 7, 31)
    assert data.start_date == date(2026, 7, 1)
    # The stored budget now reflects the new values, under the same id.
    stored = asyncio.run(repository.find_active_by_id("person-1", "budget-1"))
    assert stored is not None
    assert stored.start_date == date(2026, 7, 1)
    assert stored.amount.value == Decimal("900.00")


def test_blank_note_becomes_absent() -> None:
    use_case, _ = _build_use_case(_a_budget())

    data = asyncio.run(use_case.execute(_command(note="   ")))

    assert data.note is None


def test_unknown_id_is_rejected_and_changes_nothing() -> None:
    use_case, repository = _build_use_case(_a_budget())

    with pytest.raises(BudgetNotFoundError):
        asyncio.run(use_case.execute(_command(budget_id="ghost")))
    stored = repository.budgets[0]
    assert stored.start_date == _START
    assert stored.amount.value == Decimal("500.00")


def test_another_persons_budget_is_rejected_and_left_untouched() -> None:
    theirs = _a_budget(id="theirs", person_id="person-2")
    use_case, _ = _build_use_case(theirs)

    with pytest.raises(BudgetNotFoundError):
        asyncio.run(use_case.execute(_command(budget_id="theirs")))
    assert theirs.start_date == _START
    assert theirs.amount.value == Decimal("500.00")


def test_soft_deleted_budget_is_rejected() -> None:
    removed = _a_budget(deleted_at=datetime(2026, 6, 21, tzinfo=UTC))
    use_case, _ = _build_use_case(removed)

    with pytest.raises(BudgetNotFoundError):
        asyncio.run(use_case.execute(_command()))
    assert removed.start_date == _START


def test_updated_range_overlapping_another_live_budget_is_rejected() -> None:
    target = _a_budget(id="budget-1", start_date=_START, end_date=_END)
    other = _a_budget(id="other", start_date=date(2026, 7, 1), end_date=date(2026, 7, 31))
    use_case, _ = _build_use_case(target, other)

    with pytest.raises(OverlappingBudgetError):
        asyncio.run(use_case.execute(_command(start_date=date(2026, 7, 15), end_date=date(2026, 8, 15))))
    # Nothing changed: the target keeps its original range.
    assert target.end_date == _END
    assert target.start_date == _START


def test_shared_boundary_day_is_rejected() -> None:
    target = _a_budget(id="budget-1", start_date=_START, end_date=_END)
    other = _a_budget(id="other", start_date=date(2026, 7, 1), end_date=date(2026, 7, 31))
    use_case, _ = _build_use_case(target, other)

    with pytest.raises(OverlappingBudgetError):
        asyncio.run(use_case.execute(_command(start_date=date(2026, 6, 1), end_date=date(2026, 7, 1))))


def test_adjacent_range_is_allowed() -> None:
    target = _a_budget(id="budget-1", start_date=_START, end_date=_END)
    other = _a_budget(id="other", start_date=date(2026, 7, 1), end_date=date(2026, 7, 31))
    use_case, _ = _build_use_case(target, other)

    data = asyncio.run(use_case.execute(_command(start_date=date(2026, 8, 1), end_date=date(2026, 8, 31))))

    assert data.end_date == date(2026, 8, 31)
    assert data.start_date == date(2026, 8, 1)


def test_resaving_in_its_own_range_does_not_self_overlap() -> None:
    target = _a_budget(id="budget-1", start_date=_START, end_date=_END)
    use_case, _ = _build_use_case(target)

    data = asyncio.run(use_case.execute(_command(start_date=_START, end_date=_END, amount="750.00")))

    assert data.end_date == _END
    assert data.start_date == _START
    assert data.amount == Decimal("750.00")


def test_non_positive_amount_is_rejected_and_changes_nothing() -> None:
    use_case, repository = _build_use_case(_a_budget())

    with pytest.raises(InvalidBudgetAmountError):
        asyncio.run(use_case.execute(_command(amount="0.00")))
    assert repository.budgets[0].amount.value == Decimal("500.00")


def test_inverted_range_is_rejected_and_changes_nothing() -> None:
    use_case, repository = _build_use_case(_a_budget())

    with pytest.raises(InvalidBudgetRangeError):
        asyncio.run(use_case.execute(_command(start_date=date(2026, 7, 31), end_date=date(2026, 7, 1))))
    assert repository.budgets[0].start_date == _START
