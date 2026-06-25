from trocado.features.budgeting.domain.errors.invalid_budget_range_error import (
    InvalidBudgetRangeError,
)


def test_carries_ptbr_message() -> None:
    assert str(InvalidBudgetRangeError()) == "Data inicial não pode ser posterior à data final."
