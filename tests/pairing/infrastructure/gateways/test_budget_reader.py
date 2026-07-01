import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.features.pairing.application.data.active_budget_reading_data import ActiveBudgetReadingData
from trocado.features.pairing.infrastructure.gateways.budget_reader import BudgetReader
from trocado.features.pairing.infrastructure.gateways.rows.budget_row import BudgetRow

_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def test_find_active_for_person_returns_the_budget_containing_the_day() -> None:
    reader = BudgetReader()
    reader._rows = {
        "live": BudgetRow(
            person_id="person-1",
            amount=Decimal("500.00"),
            start_date=date(2026, 6, 1),
            end_date=date(2026, 6, 30),
            deleted_at=None,
        )
    }

    assert asyncio.run(reader.find_active_for_person("person-1", date(2026, 7, 1))) is None
    assert asyncio.run(reader.find_active_for_person("person-1", date(2026, 6, 15))) == ActiveBudgetReadingData(
        start_date=date(2026, 6, 1), end_date=date(2026, 6, 30), amount=Decimal("500.00")
    )


def test_find_active_for_person_ignores_other_people_and_soft_deleted() -> None:
    reader = BudgetReader()
    reader._rows = {
        "theirs": BudgetRow(
            person_id="person-2",
            amount=Decimal("500.00"),
            start_date=date(2026, 6, 1),
            end_date=date(2026, 6, 30),
            deleted_at=None,
        ),
        "dead": BudgetRow(
            person_id="person-1",
            amount=Decimal("500.00"),
            start_date=date(2026, 6, 1),
            end_date=date(2026, 6, 30),
            deleted_at=_NOW,
        ),
    }

    assert asyncio.run(reader.find_active_for_person("person-1", date(2026, 6, 15))) is None
