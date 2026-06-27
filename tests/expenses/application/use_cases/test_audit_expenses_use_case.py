import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.expenses.fakes.fake_expense_repository import FakeExpenseRepository
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.application.use_cases.audit_expenses_use_case import AuditExpensesUseCase
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity

_FIXED_NOW = datetime(2026, 6, 24, 12, 0, tzinfo=UTC)


def _expense(
    *,
    id: str,
    amount: str = "10.00",
    person_id: str = "person-1",
    created_at: datetime = _FIXED_NOW,
    deleted_at: datetime | None = None,
    occurred_on: date = date(2026, 6, 20),
) -> ExpenseEntity:
    expense = ExpenseEntity.create(
        id=id,
        description=None,
        person_id=person_id,
        created_at=created_at,
        occurred_on=occurred_on,
        amount=MoneyValueObject(Decimal(amount)),
    )
    expense.deleted_at = deleted_at
    return expense


def _build(*expenses: ExpenseEntity) -> AuditExpensesUseCase:
    repository = FakeExpenseRepository()
    repository.expenses.extend(expenses)
    return AuditExpensesUseCase(repository=repository)


def test_returns_both_live_and_soft_deleted_expenses_preserving_their_fields() -> None:
    use_case = _build(
        _expense(id="live", amount="10.00", occurred_on=date(2026, 6, 20)),
        _expense(id="removed", amount="30.00", occurred_on=date(2026, 6, 10), deleted_at=_FIXED_NOW),
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["live", "removed"]
    live = data[0]
    assert live.person_id == "person-1"
    assert live.created_at == _FIXED_NOW
    assert live.amount == Decimal("10.00")
    assert live.occurred_on == date(2026, 6, 20)


def test_person_with_no_expenses_gets_an_empty_list() -> None:
    use_case = _build()

    assert asyncio.run(use_case.execute("person-1")) == []


def test_live_expense_carries_a_null_deletion_timestamp() -> None:
    use_case = _build(_expense(id="live"))

    data = asyncio.run(use_case.execute("person-1"))

    assert data[0].deleted_at is None


def test_soft_deleted_expense_carries_its_deletion_timestamp() -> None:
    removed_at = datetime(2026, 6, 22, tzinfo=UTC)
    use_case = _build(_expense(id="removed", deleted_at=removed_at))

    data = asyncio.run(use_case.execute("person-1"))

    assert data[0].deleted_at == removed_at


def test_ordered_most_recent_first_interleaving_live_and_removed() -> None:
    use_case = _build(
        _expense(id="oldest-live", occurred_on=date(2026, 6, 1)),
        _expense(id="newest-removed", occurred_on=date(2026, 6, 30), deleted_at=_FIXED_NOW),
        _expense(id="middle-live", occurred_on=date(2026, 6, 15)),
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["newest-removed", "middle-live", "oldest-live"]


def test_same_day_breaks_tie_by_created_at_descending() -> None:
    use_case = _build(
        _expense(id="older", occurred_on=date(2026, 6, 20), created_at=datetime(2026, 6, 20, tzinfo=UTC)),
        _expense(
            id="newer",
            deleted_at=_FIXED_NOW,
            occurred_on=date(2026, 6, 20),
            created_at=datetime(2026, 6, 21, tzinfo=UTC),
        ),
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["newer", "older"]


def test_audits_only_the_requesters_own_expenses() -> None:
    use_case = _build(
        _expense(id="mine-live", person_id="person-1"),
        _expense(id="mine-removed", person_id="person-1", deleted_at=_FIXED_NOW),
        _expense(id="theirs-live", person_id="person-2"),
        _expense(id="theirs-removed", person_id="person-2", deleted_at=_FIXED_NOW),
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert sorted(item.id for item in data) == ["mine-live", "mine-removed"]
