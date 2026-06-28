from litestar.exceptions import NotFoundException

from trocado.core.domain.errors.invalid_money_error import InvalidMoneyError
from trocado.core.infrastructure.http.errors.lookups.error_code import error_code
from trocado.features.budgeting.domain.errors.overlapping_budget_error import OverlappingBudgetError


def test_kebab_cases_a_multi_word_error_dropping_the_error_suffix() -> None:
    assert error_code(OverlappingBudgetError) == "overlapping-budget"


def test_kebab_cases_a_two_word_error() -> None:
    assert error_code(InvalidMoneyError) == "invalid-money"


def test_drops_the_exception_suffix_for_framework_http_errors() -> None:
    assert error_code(NotFoundException) == "not-found"
