from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError


def test_carries_ptbr_message() -> None:
    assert str(NotPairedError()) == "Você não está em um par ativo."
