from trocado.features.pairing.domain.errors.invite_code_not_found_error import (
    InviteCodeNotFoundError,
)


def test_carries_ptbr_message() -> None:
    assert str(InviteCodeNotFoundError()) == "Convite inválido."
