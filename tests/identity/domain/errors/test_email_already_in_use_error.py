from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError


def test_message_is_generic_and_does_not_reveal_the_email() -> None:
    message = str(EmailAlreadyInUseError())
    assert message == "E-mail já está em uso."
    # No address echoed — revealing which emails exist enables account enumeration.
    assert "@" not in message
