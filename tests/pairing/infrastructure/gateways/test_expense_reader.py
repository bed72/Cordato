import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.infrastructure.gateways.expense_reader import ExpenseReader
from trocado.features.pairing.infrastructure.gateways.rows.expense_row import ExpenseRow

_CREATED_AT = datetime(2026, 6, 24, tzinfo=UTC)


def test_find_amounts_in_range_filters_by_person_range_and_soft_delete() -> None:
    reader = ExpenseReader()
    reader._rows = {
        "mine": ExpenseRow(
            id="mine",
            person_id="person-1",
            amount=Decimal("10.00"),
            occurred_on=date(2026, 6, 15),
            created_at=_CREATED_AT,
            description=None,
            deleted_at=None,
        ),
        "out-of-range": ExpenseRow(
            id="out-of-range",
            person_id="person-1",
            amount=Decimal("20.00"),
            occurred_on=date(2026, 7, 1),
            created_at=_CREATED_AT,
            description=None,
            deleted_at=None,
        ),
        "theirs": ExpenseRow(
            id="theirs",
            person_id="person-2",
            amount=Decimal("30.00"),
            occurred_on=date(2026, 6, 15),
            created_at=_CREATED_AT,
            description=None,
            deleted_at=None,
        ),
        "dead": ExpenseRow(
            id="dead",
            person_id="person-1",
            amount=Decimal("40.00"),
            occurred_on=date(2026, 6, 15),
            created_at=_CREATED_AT,
            description=None,
            deleted_at=_CREATED_AT,
        ),
    }

    result = asyncio.run(reader.find_amounts_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))

    assert result == [Decimal("10.00")]


def test_list_live_for_person_excludes_soft_deleted_and_other_people() -> None:
    reader = ExpenseReader()
    live = ExpenseRow(
        id="live",
        person_id="person-1",
        amount=Decimal("10.00"),
        occurred_on=date(2026, 6, 15),
        created_at=_CREATED_AT,
        description="mercado",
        deleted_at=None,
    )
    reader._rows = {
        "live": live,
        "dead": ExpenseRow(
            id="dead",
            person_id="person-1",
            amount=Decimal("40.00"),
            occurred_on=date(2026, 6, 15),
            created_at=_CREATED_AT,
            description=None,
            deleted_at=_CREATED_AT,
        ),
        "theirs": ExpenseRow(
            id="theirs",
            person_id="person-2",
            amount=Decimal("30.00"),
            occurred_on=date(2026, 6, 15),
            created_at=_CREATED_AT,
            description=None,
            deleted_at=None,
        ),
    }

    result = asyncio.run(reader.list_live_for_person("person-1"))

    assert result == [
        PartnerExpenseData(
            id="live",
            person_id="person-1",
            amount=Decimal("10.00"),
            occurred_on=date(2026, 6, 15),
            created_at=_CREATED_AT,
            description="mercado",
        )
    ]
