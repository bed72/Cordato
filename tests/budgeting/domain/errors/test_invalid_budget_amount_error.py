from trocado.features.budgeting.domain.errors.invalid_budget_amount_error import (
    InvalidBudgetAmountError,
)


def test_carries_ptbr_message() -> None:
    assert str(InvalidBudgetAmountError()) == "Valor do orçamento deve ser maior que zero."
