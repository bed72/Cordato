from datetime import date
from decimal import Decimal

from trocado.features.budgeting.infrastructure.http.mappers.create_budget_request_mapper import (
    CreateBudgetRequestMapper,
)
from trocado.features.budgeting.infrastructure.http.requests.create_budget_request import (
    CreateBudgetRequest,
)

_END = date(2026, 6, 30)
_START = date(2026, 6, 1)


def test_maps_request_and_acting_person_into_command() -> None:
    request = CreateBudgetRequest(amount=Decimal("500.00"), start_date=_START, end_date=_END, note="mercado")

    data = CreateBudgetRequestMapper.to_data(request)

    assert data.end_date == _END
    assert data.note == "mercado"
    assert data.start_date == _START
    assert data.person_id == "person-1"
    assert data.amount == Decimal("500.00")


def test_absent_note_is_carried_through_as_none() -> None:
    request = CreateBudgetRequest(amount=Decimal("10.00"), start_date=_START, end_date=_END)

    data = CreateBudgetRequestMapper.to_data(request)

    assert data.note is None
    assert data.person_id == "person-2"
