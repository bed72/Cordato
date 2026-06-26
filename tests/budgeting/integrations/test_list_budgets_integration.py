import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.use_cases.list_budgets_use_case import ListBudgetsUseCase
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _budget(
    *,
    id: str,
    end_date: date,
    start_date: date,
    person_id: str = "person-1",
    created_at: datetime = _FIXED_NOW,
) -> BudgetEntity:
    return BudgetEntity.create(
        id=id,
        note=None,
        end_date=end_date,
        person_id=person_id,
        start_date=start_date,
        created_at=created_at,
        amount=MoneyValueObject(Decimal("500.00")),
    )


def test_real_repository_drives_the_ordered_owner_scoped_live_list() -> None:
    repository = BudgetRepository()
    use_case = ListBudgetsUseCase(repository=repository)

    async def scenario() -> list[str]:
        await repository.create(_budget(id="may", start_date=date(2026, 5, 1), end_date=date(2026, 5, 31)))
        await repository.create(_budget(id="july", start_date=date(2026, 7, 1), end_date=date(2026, 7, 31)))
        await repository.create(_budget(id="june", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30)))
        await repository.create(
            _budget(id="theirs", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30), person_id="person-2")
        )

        removed = _budget(id="removed", start_date=date(2026, 4, 1), end_date=date(2026, 4, 30))
        await repository.create(removed)
        removed.delete(_FIXED_NOW)
        await repository.delete(removed)

        data = await use_case.execute("person-1")
        return [item.id for item in data]

    # Most-recent-period-first, the soft-deleted budget gone, person-2's budget never seen.
    assert asyncio.run(scenario()) == ["july", "june", "may"]
