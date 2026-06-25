from trocado.core.domain.errors.invalid_money_error import InvalidMoneyError


def test_carries_ptbr_message() -> None:
    assert str(InvalidMoneyError()) == "Valor monetário inválido."
