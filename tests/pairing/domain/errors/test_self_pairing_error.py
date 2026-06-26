from trocado.features.pairing.domain.errors.self_pairing_error import SelfPairingError


def test_carries_ptbr_message() -> None:
    assert str(SelfPairingError()) == "Você não pode parear consigo mesmo."
