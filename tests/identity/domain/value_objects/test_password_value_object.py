import pytest

from trocado.features.identity.domain.errors.weak_password_error import WeakPasswordError
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


def test_accepts_policy_compliant() -> None:
    assert PasswordValueObject("12345678").value == "12345678"


def test_does_not_trim_spaces() -> None:
    assert PasswordValueObject("  spaces  ").value == "  spaces  "


@pytest.mark.parametrize("raw", ["", "short", "1234567"])
def test_rejects_below_minimum(raw: str) -> None:
    with pytest.raises(WeakPasswordError):
        PasswordValueObject(raw)


def test_repr_hides_plaintext() -> None:
    assert "supersecret" not in repr(PasswordValueObject("supersecret"))
