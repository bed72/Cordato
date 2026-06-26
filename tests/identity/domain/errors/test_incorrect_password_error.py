from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError


def test_carries_ptbr_message() -> None:
    assert str(IncorrectPasswordError()) == "Senha incorreta."
