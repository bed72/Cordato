from datetime import date
from decimal import Decimal

from trocado.features.budgeting.infrastructure.http.mappers.requests.create_budget_request_mapper import (
    CreateBudgetRequestMapper,
)
from trocado.features.budgeting.infrastructure.http.requests.create_budget_request import (
    CreateBudgetRequest,
)

_END = date(2026, 6, 30)
_START = date(2026, 6, 1)
_PERSON_ID = "person-abc"


def test_maps_request_into_command_with_the_given_person_id() -> None:
    request = CreateBudgetRequest(amount=Decimal("500.00"), start_date=_START, end_date=_END, note="mercado")

    data = CreateBudgetRequestMapper.to_data(request, _PERSON_ID)

    assert data.end_date == _END
    assert data.note == "mercado"
    assert data.start_date == _START
    assert data.person_id == _PERSON_ID
    assert data.amount == Decimal("500.00")


def test_absent_note_is_carried_through_as_none() -> None:
    request = CreateBudgetRequest(amount=Decimal("10.00"), start_date=_START, end_date=_END)

    data = CreateBudgetRequestMapper.to_data(request, _PERSON_ID)

    assert data.note is None
    assert data.person_id == _PERSON_ID
