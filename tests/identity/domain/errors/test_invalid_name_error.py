from trocado.features.identity.domain.errors.invalid_name_error import InvalidNameError


def test_message() -> None:
    assert str(InvalidNameError()) == "Nome não pode ser vazio."
