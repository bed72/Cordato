from trocado.features.pairing.domain.errors.invite_code_expired_error import InviteCodeExpiredError


def test_carries_ptbr_message() -> None:
    assert str(InviteCodeExpiredError()) == "Convite expirado."
