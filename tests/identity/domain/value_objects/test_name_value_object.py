import pytest

from trocado.features.identity.domain.errors.invalid_name_error import InvalidNameError
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject


def test_trims_surrounding_whitespace() -> None:
    assert NameValueObject("  Ana  ").value == "Ana"


@pytest.mark.parametrize("raw", ["", "   ", "\t\n"])
def test_rejects_blank(raw: str) -> None:
    with pytest.raises(InvalidNameError):
        NameValueObject(raw)
