import asyncio
from datetime import date
from decimal import Decimal

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.core.infrastructure.gateways.spend_reader import SpendReader

_PERSON_ID = "person-1"
_OTHER_ID = "other-person"


def _make_reader(amounts_by_person: dict[str, list[tuple[date, Decimal]]]) -> SpendReader:
    async def fetch_amounts(person_id: str, start: date, end: date) -> list[Decimal]:
        return [amount for occurred_on, amount in amounts_by_person.get(person_id, []) if start <= occurred_on <= end]

    return SpendReader(fetch_amounts)


def test_total_spent_sums_amounts_in_range() -> None:
    reader = _make_reader({_PERSON_ID: [(date(2026, 6, 10), Decimal("100.00")), (date(2026, 6, 20), Decimal("50.50"))]})
    result = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))
    assert result == MoneyValueObject(Decimal("150.50"))


def test_total_spent_returns_zero_when_no_amounts() -> None:
    reader = _make_reader({})
    result = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))
    assert result == MoneyValueObject(Decimal("0.00"))


def test_total_spent_excludes_amounts_outside_range() -> None:
    reader = _make_reader(
        {
            _PERSON_ID: [
                (date(2026, 5, 31), Decimal("200.00")),
                (date(2026, 7, 1), Decimal("300.00")),
                (date(2026, 6, 15), Decimal("75.00")),
            ]
        }
    )
    result = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))
    assert result == MoneyValueObject(Decimal("75.00"))


def test_total_spent_includes_boundary_dates() -> None:
    reader = _make_reader({_PERSON_ID: [(date(2026, 6, 1), Decimal("10.00")), (date(2026, 6, 30), Decimal("20.00"))]})
    result = asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))
    assert result == MoneyValueObject(Decimal("30.00"))


def test_fetch_amounts_callable_is_called_with_correct_arguments() -> None:
    calls: list[tuple[str, date, date]] = []

    async def fetch_amounts(person_id: str, start: date, end: date) -> list[Decimal]:
        calls.append((person_id, start, end))
        return []

    reader = SpendReader(fetch_amounts)
    asyncio.run(reader.total_spent(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30)))

    assert calls == [(_PERSON_ID, date(2026, 6, 1), date(2026, 6, 30))]
