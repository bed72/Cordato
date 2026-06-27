import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.budgeting.fakes.fake_budget_repository import FakeBudgetRepository
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.features.budgeting.application.use_cases.audit_budgets_use_case import AuditBudgetsUseCase
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity

_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _budget(
    *,
    id: str,
    end_date: date,
    start_date: date,
    amount: str = "500.00",
    person_id: str = "person-1",
    created_at: datetime = _FIXED_NOW,
    deleted_at: datetime | None = None,
) -> BudgetEntity:
    budget = BudgetEntity.create(
        id=id,
        note=None,
        end_date=end_date,
        person_id=person_id,
        start_date=start_date,
        created_at=created_at,
        amount=MoneyValueObject(Decimal(amount)),
    )
    budget.deleted_at = deleted_at
    return budget


def _build(budgets: list[BudgetEntity]) -> AuditBudgetsUseCase:
    repository = FakeBudgetRepository()
    repository.budgets.extend(budgets)
    return AuditBudgetsUseCase(repository=repository)


def test_returns_both_live_and_soft_deleted_budgets_preserving_their_fields() -> None:
    use_case = _build(
        budgets=[
            _budget(id="live", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30), amount="500.00"),
            _budget(
                id="removed",
                amount="300.00",
                deleted_at=_FIXED_NOW,
                end_date=date(2026, 5, 31),
                start_date=date(2026, 5, 1),
            ),
        ]
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["live", "removed"]
    live = data[0]
    assert live.person_id == "person-1"
    assert live.created_at == _FIXED_NOW
    assert live.amount == Decimal("500.00")
    assert live.end_date == date(2026, 6, 30)
    assert live.start_date == date(2026, 6, 1)


def test_person_with_no_budgets_gets_an_empty_list() -> None:
    use_case = _build(budgets=[])

    assert asyncio.run(use_case.execute("person-1")) == []


def test_live_budget_carries_a_null_deletion_timestamp() -> None:
    use_case = _build(budgets=[_budget(id="live", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30))])

    data = asyncio.run(use_case.execute("person-1"))

    assert data[0].deleted_at is None


def test_soft_deleted_budget_carries_its_deletion_timestamp() -> None:
    removed_at = datetime(2026, 6, 20, tzinfo=UTC)
    use_case = _build(
        budgets=[
            _budget(
                id="removed",
                deleted_at=removed_at,
                end_date=date(2026, 6, 30),
                start_date=date(2026, 6, 1),
            )
        ]
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert data[0].deleted_at == removed_at


def test_ordered_most_recent_period_first_interleaving_live_and_removed() -> None:
    use_case = _build(
        budgets=[
            _budget(id="may-live", start_date=date(2026, 5, 1), end_date=date(2026, 5, 31)),
            _budget(
                id="july-removed",
                deleted_at=_FIXED_NOW,
                end_date=date(2026, 7, 31),
                start_date=date(2026, 7, 1),
            ),
            _budget(id="june-live", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30)),
        ]
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["july-removed", "june-live", "may-live"]


def test_same_start_date_breaks_tie_by_created_at_descending() -> None:
    use_case = _build(
        budgets=[
            _budget(
                id="older",
                end_date=date(2026, 6, 15),
                start_date=date(2026, 6, 1),
                created_at=datetime(2026, 6, 1, tzinfo=UTC),
            ),
            _budget(
                id="newer",
                deleted_at=_FIXED_NOW,
                end_date=date(2026, 6, 15),
                start_date=date(2026, 6, 1),
                created_at=datetime(2026, 6, 2, tzinfo=UTC),
            ),
        ]
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["newer", "older"]


def test_audits_only_the_requesters_own_budgets() -> None:
    use_case = _build(
        budgets=[
            _budget(id="mine-live", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30), person_id="person-1"),
            _budget(
                id="mine-removed",
                person_id="person-1",
                deleted_at=_FIXED_NOW,
                end_date=date(2026, 5, 31),
                start_date=date(2026, 5, 1),
            ),
            _budget(id="theirs", start_date=date(2026, 6, 1), end_date=date(2026, 6, 30), person_id="person-2"),
            _budget(
                id="theirs-removed",
                person_id="person-2",
                deleted_at=_FIXED_NOW,
                end_date=date(2026, 5, 31),
                start_date=date(2026, 5, 1),
            ),
        ]
    )

    data = asyncio.run(use_case.execute("person-1"))

    assert [item.id for item in data] == ["mine-live", "mine-removed"]
