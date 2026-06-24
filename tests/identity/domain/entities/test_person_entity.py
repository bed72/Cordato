from datetime import UTC, datetime

from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.domain.value_objects.person_status import PersonStatus


def _build(id: str = "id-1") -> PersonEntity:
    return PersonEntity.create(
        id=id,
        created_at=datetime(2026, 6, 24, tzinfo=UTC),
        name=NameValueObject("Ana"),
        email=EmailValueObject("ana@example.com"),
        password="hash",
    )


def test_create_starts_active() -> None:
    assert _build().status is PersonStatus.ACTIVE


def test_identity_equality_by_id() -> None:
    assert _build("same") == _build("same")
    assert _build("a") != _build("b")


def test_hashable_by_id() -> None:
    assert len({_build("a"), _build("a"), _build("b")}) == 2
