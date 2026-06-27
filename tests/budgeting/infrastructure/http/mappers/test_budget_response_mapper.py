from datetime import UTC, date, datetime
from decimal import Decimal

from trocado.features.budgeting.application.data.budget_data import BudgetData
from trocado.features.budgeting.infrastructure.http.mappers.budget_response_mapper import (
    BudgetResponseMapper,
)

_START = date(2026, 6, 1)
_END = date(2026, 6, 30)
_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def test_maps_read_model_into_response_field_for_field() -> None:
    data = BudgetData(
        id="budget-1",
        end_date=_END,
        note="mercado",
        created_at=_NOW,
        start_date=_START,
        person_id="person-1",
        amount=Decimal("500.00"),
    )

    response = BudgetResponseMapper.to_response(data)

    assert response.end_date == _END
    assert response.id == "budget-1"
    assert response.note == "mercado"
    assert response.created_at == _NOW
    assert response.start_date == _START
    assert response.person_id == "person-1"
    assert response.amount == Decimal("500.00")


def test_absent_note_maps_to_none() -> None:
    data = BudgetData(
        note=None,
        id="budget-2",
        end_date=_END,
        created_at=_NOW,
        start_date=_START,
        person_id="person-1",
        amount=Decimal("10.00"),
    )

    response = BudgetResponseMapper.to_response(data)

    assert response.note is None
