from trocado.features.pairing.domain.errors.person_not_active_error import PersonNotActiveError


def test_carries_ptbr_message() -> None:
    message = str(PersonNotActiveError())

    # Non-leaking: never reveals which party is inactive, never echoes an id.
    assert message == "Conta indisponível."
