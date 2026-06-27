import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.expenses.application.use_cases.audit_expenses_use_case import AuditExpensesUseCase
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)
_REMOVED_AT = datetime(2026, 6, 25, 12, tzinfo=UTC)


def _expense(*, id: str, occurred_on: date, person_id: str = "person-1") -> ExpenseEntity:
    return ExpenseEntity.create(
        id=id,
        description=None,
        person_id=person_id,
        created_at=_FIXED_NOW,
        occurred_on=occurred_on,
        amount=MoneyValueObject(Decimal("10.00")),
    )


def test_real_expense_repository_drives_the_audit_listing() -> None:
    repository = ExpenseRepository()

    async def scenario() -> None:
        await repository.create(_expense(id="oldest-live", occurred_on=date(2026, 6, 1)))
        await repository.create(_expense(id="middle-live", occurred_on=date(2026, 6, 15)))
        # A different person's expense must never surface in person-1's audit.
        await repository.create(_expense(id="theirs", occurred_on=date(2026, 6, 30), person_id="person-2"))

        newest_removed = _expense(id="newest-removed", occurred_on=date(2026, 6, 30))
        newest_removed.delete(_REMOVED_AT)
        await repository.create(newest_removed)
        await repository.delete(newest_removed)

        use_case = AuditExpensesUseCase(repository=repository)
        data = await use_case.execute("person-1")

        # Most-recent-first, soft-deleted included and flagged, owner-scoped.
        assert [item.id for item in data] == ["newest-removed", "middle-live", "oldest-live"]
        assert data[0].deleted_at == _REMOVED_AT
        assert data[1].deleted_at is None
        assert data[2].deleted_at is None

    asyncio.run(scenario())
