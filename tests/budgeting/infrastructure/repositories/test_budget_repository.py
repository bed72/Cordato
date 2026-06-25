import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _budget(
    *,
    id: str = "budget-1",
    person_id: str = "person-1",
    end_date: date = date(2026, 6, 30),
    deleted_at: datetime | None = None,
    start_date: date = date(2026, 6, 1),
) -> BudgetEntity:
    budget = BudgetEntity.create(
        id=id,
        note=None,
        end_date=end_date,
        person_id=person_id,
        created_at=_FIXED_NOW,
        start_date=start_date,
        amount=MoneyValueObject(Decimal("500.00")),
    )
    budget.deleted_at = deleted_at

    return budget


def test_created_budget_is_stored_under_its_id() -> None:
    budget = _budget()
    repository = BudgetRepository()

    asyncio.run(repository.create(budget))

    assert repository._budgets == {"budget-1": budget}


def test_list_live_excludes_soft_deleted_and_other_people() -> None:
    repository = BudgetRepository()
    live = _budget(id="live")
    asyncio.run(repository.create(live))
    asyncio.run(repository.create(_budget(id="dead", deleted_at=_FIXED_NOW)))
    asyncio.run(repository.create(_budget(id="other", person_id="person-2")))

    result = asyncio.run(repository.list_live_for_person("person-1"))

    assert result == [live]


def test_find_active_returns_budget_containing_the_day() -> None:
    repository = BudgetRepository()
    budget = _budget(start_date=date(2026, 6, 1), end_date=date(2026, 6, 30))
    asyncio.run(repository.create(budget))

    assert asyncio.run(repository.find_active_for_person("person-1", date(2026, 7, 1))) is None
    assert asyncio.run(repository.find_active_for_person("person-1", date(2026, 6, 15))) == budget
