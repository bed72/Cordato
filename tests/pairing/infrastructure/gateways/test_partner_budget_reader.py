import asyncio
from datetime import date
from decimal import Decimal

from trocado.features.pairing.application.data.partner_active_budget_data import PartnerActiveBudgetData
from trocado.features.pairing.infrastructure.gateways.partner_budget_reader import PartnerBudgetReader

_BUDGET = PartnerActiveBudgetData(
    person_id="person-1",
    start_date=date(2026, 6, 1),
    end_date=date(2026, 6, 30),
    amount=Decimal("1500.00"),
    total_spent=Decimal("300.00"),
)


async def _find_active(person_id: str, day: date) -> PartnerActiveBudgetData | None:
    if person_id == "person-1" and _BUDGET.start_date <= day <= _BUDGET.end_date:
        return _BUDGET
    return None


def test_active_for_person_returns_budget_when_found() -> None:
    reader = PartnerBudgetReader(_find_active)
    result = asyncio.run(reader.active_for_person("person-1", date(2026, 6, 15)))
    assert result == _BUDGET


def test_active_for_person_returns_none_when_not_found() -> None:
    reader = PartnerBudgetReader(_find_active)
    assert asyncio.run(reader.active_for_person("other-person", date(2026, 6, 15))) is None


def test_active_for_person_returns_none_outside_budget_range() -> None:
    reader = PartnerBudgetReader(_find_active)
    assert asyncio.run(reader.active_for_person("person-1", date(2026, 7, 1))) is None


def test_find_active_budget_callable_receives_correct_arguments() -> None:
    calls: list[tuple[str, date]] = []

    async def fake_find(person_id: str, day: date) -> PartnerActiveBudgetData | None:
        calls.append((person_id, day))
        return None

    reader = PartnerBudgetReader(fake_find)
    asyncio.run(reader.active_for_person("person-42", date(2026, 6, 15)))
    assert calls == [("person-42", date(2026, 6, 15))]
