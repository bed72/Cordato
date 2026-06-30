from http import HTTPStatus

from trocado.features.expenses.domain.errors.expense_not_found_error import ExpenseNotFoundError
from trocado.features.expenses.domain.errors.invalid_amount_error import InvalidAmountError
from trocado.features.expenses.infrastructure.http.errors.lookups.expenses_status_error import EXPENSES_STATUS_ERROR


def test_each_expense_error_maps_to_its_status() -> None:
    assert len(EXPENSES_STATUS_ERROR) == 2
    assert EXPENSES_STATUS_ERROR[ExpenseNotFoundError] == HTTPStatus.NOT_FOUND
    assert EXPENSES_STATUS_ERROR[InvalidAmountError] == HTTPStatus.UNPROCESSABLE_ENTITY


def test_the_reachable_errors_are_covered() -> None:
    """Totality over expenses-specific errors — cross-cutting core errors live in CORE_STATUS_ERROR at app layer."""
    for error in (ExpenseNotFoundError, InvalidAmountError):
        assert error in EXPENSES_STATUS_ERROR
