from trocado.features.pairing.domain.errors.invite_code_already_consumed_error import (
    InviteCodeAlreadyConsumedError,
)


def test_carries_ptbr_message() -> None:
    assert str(InviteCodeAlreadyConsumedError()) == "Convite já utilizado."
