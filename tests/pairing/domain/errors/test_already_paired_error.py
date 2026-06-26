from trocado.features.pairing.domain.errors.already_paired_error import AlreadyPairedError


def test_carries_ptbr_message() -> None:
    message = str(AlreadyPairedError())

    # Non-leaking: never reveals which party is already paired.
    assert message == "Já existe um par ativo."
