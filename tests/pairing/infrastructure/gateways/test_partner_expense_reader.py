import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.infrastructure.gateways.partner_expense_reader import PartnerExpenseReader

_EXPENSE = PartnerExpenseData(
    id="exp-1",
    person_id="person-1",
    amount=Decimal("100.00"),
    occurred_on=date(2026, 6, 15),
    created_at=datetime(2026, 6, 15, tzinfo=UTC),
    description=None,
)


async def _list_one(person_id: str) -> list[PartnerExpenseData]:
    return [_EXPENSE] if person_id == "person-1" else []


def test_list_for_person_delegates_to_callable() -> None:
    reader = PartnerExpenseReader(_list_one)
    result = asyncio.run(reader.list_for_person("person-1"))
    assert result == [_EXPENSE]


def test_list_for_person_returns_empty_list_when_callable_returns_empty() -> None:
    reader = PartnerExpenseReader(_list_one)
    assert asyncio.run(reader.list_for_person("other-person")) == []


def test_list_expenses_callable_receives_correct_person_id() -> None:
    calls: list[str] = []

    async def fake_list(person_id: str) -> list[PartnerExpenseData]:
        calls.append(person_id)
        return []

    reader = PartnerExpenseReader(fake_list)
    asyncio.run(reader.list_for_person("person-99"))
    assert calls == ["person-99"]
