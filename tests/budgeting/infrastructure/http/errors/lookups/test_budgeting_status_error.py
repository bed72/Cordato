from http import HTTPStatus

from trocado.features.budgeting.domain.errors.budget_not_found_error import BudgetNotFoundError
from trocado.features.budgeting.domain.errors.invalid_budget_amount_error import InvalidBudgetAmountError
from trocado.features.budgeting.domain.errors.invalid_budget_range_error import InvalidBudgetRangeError
from trocado.features.budgeting.domain.errors.overlapping_budget_error import OverlappingBudgetError
from trocado.features.budgeting.infrastructure.http.errors.lookups.budgeting_status_error import BUDGETING_STATUS_ERROR


def test_each_budgeting_error_maps_to_its_status() -> None:
    assert len(BUDGETING_STATUS_ERROR) == 4
    assert BUDGETING_STATUS_ERROR[BudgetNotFoundError] == HTTPStatus.NOT_FOUND
    assert BUDGETING_STATUS_ERROR[OverlappingBudgetError] == HTTPStatus.CONFLICT
    assert BUDGETING_STATUS_ERROR[InvalidBudgetRangeError] == HTTPStatus.UNPROCESSABLE_ENTITY
    assert BUDGETING_STATUS_ERROR[InvalidBudgetAmountError] == HTTPStatus.UNPROCESSABLE_ENTITY


def test_the_create_budget_reachable_errors_are_covered() -> None:
    """Totality over the budgeting errors POST /v1/budgets can raise — none would fall through to a 500."""
    for error in (InvalidBudgetAmountError, InvalidBudgetRangeError, OverlappingBudgetError):
        assert error in BUDGETING_STATUS_ERROR
