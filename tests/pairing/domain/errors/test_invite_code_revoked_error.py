from trocado.features.pairing.domain.errors.invite_code_revoked_error import InviteCodeRevokedError


def test_carries_a_non_leaking_ptbr_message() -> None:
    error = InviteCodeRevokedError()

    # A short pt-BR message that reveals nothing about the token's existence or state.
    assert str(error) == "Convite inválido."


def test_is_an_exception() -> None:
    assert isinstance(InviteCodeRevokedError(), Exception)
