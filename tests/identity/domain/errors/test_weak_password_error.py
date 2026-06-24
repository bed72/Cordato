from trocado.features.identity.domain.errors.weak_password_error import WeakPasswordError


def test_message_states_only_the_minimum() -> None:
    assert str(WeakPasswordError(8)) == "Senha deve ter ao menos 8 caracteres."
