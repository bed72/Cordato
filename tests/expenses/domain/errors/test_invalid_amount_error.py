from trocado.features.expenses.domain.errors.invalid_amount_error import InvalidAmountError


def test_carries_ptbr_message() -> None:
    assert str(InvalidAmountError()) == "Valor deve ser maior que zero."
