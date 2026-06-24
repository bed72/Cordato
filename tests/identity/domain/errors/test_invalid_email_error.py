from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError


def test_message_is_generic_and_leaks_no_value() -> None:
    message = str(InvalidEmailError())
    assert message == "E-mail inválido."
    assert "@" not in message
