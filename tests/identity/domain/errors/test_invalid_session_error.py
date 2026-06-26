from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError


def test_carries_generic_ptbr_message() -> None:
    assert str(InvalidSessionError()) == "Sessão inválida."
