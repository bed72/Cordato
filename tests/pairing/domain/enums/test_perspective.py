from trocado.features.pairing.domain.enums.perspective import Perspective


def test_has_mine_and_theirs_members() -> None:
    assert {member.name for member in Perspective} == {"MINE", "THEIRS"}


def test_values_are_lowercase_strings() -> None:
    assert Perspective.MINE.value == "mine"
    assert Perspective.THEIRS.value == "theirs"
