import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _an_expense(
    *,
    id: str = "exp-1",
    person_id: str = "person-1",
    deleted_at: datetime | None = None,
    occurred_on: date = date(2026, 6, 20),
) -> ExpenseEntity:
    expense = ExpenseEntity.create(
        id=id,
        person_id=person_id,
        description="almoço",
        created_at=_FIXED_NOW,
        occurred_on=occurred_on,
        amount=MoneyValueObject(Decimal("10.00")),
    )
    expense.deleted_at = deleted_at

    return expense


def test_created_expense_is_stored_under_its_id() -> None:
    expense = _an_expense()
    repository = ExpenseRepository()

    asyncio.run(repository.create(expense))

    assert repository._expenses == {"exp-1": expense}


def _seed(*expenses: ExpenseEntity) -> ExpenseRepository:
    repository = ExpenseRepository()
    for expense in expenses:
        asyncio.run(repository.create(expense))
    return repository


def test_find_in_range_returns_only_expenses_within_the_inclusive_range() -> None:
    after = _an_expense(id="after", occurred_on=date(2026, 7, 1))
    before = _an_expense(id="before", occurred_on=date(2026, 5, 31))
    inside_end = _an_expense(id="end", occurred_on=date(2026, 6, 30))
    inside_start = _an_expense(id="start", occurred_on=date(2026, 6, 1))

    repository = _seed(inside_start, inside_end, before, after)

    found = asyncio.run(repository.find_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))

    assert {expense.id for expense in found} == {"start", "end"}


def test_find_in_range_excludes_other_people() -> None:
    mine = _an_expense(id="mine", person_id="person-1")
    theirs = _an_expense(id="theirs", person_id="person-2")
    repository = _seed(mine, theirs)

    found = asyncio.run(repository.find_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))

    assert [expense.id for expense in found] == ["mine"]


def test_find_in_range_excludes_soft_deleted() -> None:
    live = _an_expense(id="live")
    removed = _an_expense(id="removed", deleted_at=_FIXED_NOW)
    repository = _seed(live, removed)

    found = asyncio.run(repository.find_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))

    assert [expense.id for expense in found] == ["live"]


def test_find_active_by_id_returns_the_owners_live_expense() -> None:
    repository = _seed(_an_expense(id="mine"))

    found = asyncio.run(repository.find_active_by_id("person-1", "mine"))

    assert found is not None
    assert found.id == "mine"


def test_find_active_by_id_misses_unknown_id() -> None:
    repository = _seed(_an_expense(id="mine"))

    assert asyncio.run(repository.find_active_by_id("person-1", "ghost")) is None


def test_find_active_by_id_misses_another_persons_expense() -> None:
    repository = _seed(_an_expense(id="theirs", person_id="person-2"))

    # Foreign owner is indistinguishable from "does not exist" — no leak.
    assert asyncio.run(repository.find_active_by_id("person-1", "theirs")) is None


def test_find_active_by_id_misses_already_deleted_expense() -> None:
    repository = _seed(_an_expense(id="removed", deleted_at=_FIXED_NOW))

    assert asyncio.run(repository.find_active_by_id("person-1", "removed")) is None


def test_delete_persists_the_soft_deleted_state_and_drops_it_from_normal_reads() -> None:
    expense = _an_expense(id="exp-1")
    repository = _seed(expense)

    expense.delete(_FIXED_NOW)
    asyncio.run(repository.delete(expense))

    # The row stays (audit), but normal date-range reads no longer see it.
    assert repository._expenses["exp-1"].deleted_at == _FIXED_NOW
    found = asyncio.run(repository.find_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))
    assert found == []


def test_list_including_removed_sees_live_and_soft_deleted_for_that_person() -> None:
    repository = _seed(
        _an_expense(id="live"),
        _an_expense(id="removed", deleted_at=_FIXED_NOW),
        _an_expense(id="other", person_id="person-2"),
    )

    listed = asyncio.run(repository.list_including_removed("person-1"))

    assert {expense.id for expense in listed} == {"live", "removed"}


def test_erase_for_person_physically_removes_live_and_soft_deleted_only_for_that_person() -> None:
    repository = _seed(
        _an_expense(id="live"),
        _an_expense(id="removed", deleted_at=_FIXED_NOW),
        _an_expense(id="other", person_id="person-2"),
    )

    asyncio.run(repository.erase_for_person("person-1"))

    # Both the live and the soft-deleted expense are gone (physical cascade); the other person's stays.
    assert set(repository._expenses) == {"other"}
