import pytest

from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject


def test_normalizes_trim_and_lowercase() -> None:
    assert EmailValueObject("  Ana@Example.COM ").value == "ana@example.com"


@pytest.mark.parametrize("raw", ["not-an-email", "a@b", "@example.com", "ana@", "a b@c.com"])
def test_rejects_malformed(raw: str) -> None:
    with pytest.raises(InvalidEmailError):
        EmailValueObject(raw)


def test_equality_is_by_normalized_value() -> None:
    assert EmailValueObject("ANA@example.com") == EmailValueObject("ana@example.com")
