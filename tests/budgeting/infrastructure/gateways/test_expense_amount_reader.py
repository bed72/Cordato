import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.features.budgeting.infrastructure.gateways.expense_amount_reader import ExpenseAmountReader
from trocado.features.budgeting.infrastructure.gateways.rows.expense_amount_row import ExpenseAmountRow


def test_find_amounts_in_range_filters_by_person_range_and_soft_delete() -> None:
    reader = ExpenseAmountReader()
    reader._rows = {
        "in-range": ExpenseAmountRow(
            person_id="person-1", amount=Decimal("10.00"), occurred_on=date(2026, 6, 15), deleted_at=None
        ),
        "out-of-range": ExpenseAmountRow(
            person_id="person-1", amount=Decimal("20.00"), occurred_on=date(2026, 7, 1), deleted_at=None
        ),
        "other-person": ExpenseAmountRow(
            person_id="person-2", amount=Decimal("30.00"), occurred_on=date(2026, 6, 15), deleted_at=None
        ),
        "soft-deleted": ExpenseAmountRow(
            person_id="person-1",
            amount=Decimal("40.00"),
            occurred_on=date(2026, 6, 15),
            deleted_at=datetime(2026, 6, 20, tzinfo=UTC),
        ),
    }

    data = asyncio.run(reader.find_amounts_in_range("person-1", date(2026, 6, 1), date(2026, 6, 30)))

    assert data == [Decimal("10.00")]
