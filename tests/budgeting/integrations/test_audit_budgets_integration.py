import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.use_cases.audit_budgets_use_case import AuditBudgetsUseCase
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)
_REMOVED_AT = datetime(2026, 6, 25, 12, tzinfo=UTC)


def _budget(*, id: str, start_date: date, end_date: date, person_id: str = "person-1") -> BudgetEntity:
    return BudgetEntity.create(
        id=id,
        note=None,
        end_date=end_date,
        person_id=person_id,
        start_date=start_date,
        created_at=_FIXED_NOW,
        amount=MoneyValueObject(Decimal("500.00")),
    )


def test_real_budget_repository_drives_the_audit_listing() -> None:
    repository = BudgetRepository()

    async def scenario() -> list[str]:
        await repository.create(_budget(id="may-live", start_date=date(2026, 5, 1), end_date=date(2026, 5, 31)))
        await repository.create(_budget(id="june-live", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30)))
        # A different person's budget must never surface in person-1's audit.
        await repository.create(
            _budget(id="theirs", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30), person_id="person-2")
        )

        july_removed = _budget(id="july-removed", start_date=date(2026, 7, 1), end_date=date(2026, 7, 31))
        july_removed.delete(_REMOVED_AT)
        await repository.create(july_removed)
        await repository.delete(july_removed)

        use_case = AuditBudgetsUseCase(repository=repository)
        data = await use_case.execute("person-1")

        # Most-recent-period-first, soft-deleted included and flagged, owner-scoped.
        assert data[2].deleted_at is None
        assert data[1].deleted_at is None
        assert data[0].deleted_at == _REMOVED_AT
        assert [item.id for item in data] == ["july-removed", "june-live", "may-live"]
        return [item.id for item in data]

    asyncio.run(scenario())
