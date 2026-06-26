from trocado.features.identity.domain.errors.invalid_credentials_error import InvalidCredentialsError


def test_carries_generic_ptbr_message() -> None:
    assert str(InvalidCredentialsError()) == "E-mail ou senha inválidos."
