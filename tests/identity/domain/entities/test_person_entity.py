from datetime import UTC, datetime

import pytest

from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject


def _build(id: str = "id-1") -> PersonEntity:
    return PersonEntity.create(
        id=id,
        password="hash",
        name=NameValueObject("Ana"),
        email=EmailValueObject("ana@example.com"),
        created_at=datetime(2026, 6, 24, tzinfo=UTC),
    )


def test_create_starts_active() -> None:
    assert _build().status is PersonStatus.ACTIVE


def test_bare_constructor_requires_explicit_status() -> None:
    # No implicit `active` default: birthing an active person must go through `create(...)`.
    # The bare constructor is reserved for rehydration, which states the persisted status explicitly.
    with pytest.raises(TypeError):
        PersonEntity(  # type: ignore[call-arg]
            id="id-1",
            password="hash",
            name=NameValueObject("Ana"),
            email=EmailValueObject("ana@example.com"),
            created_at=datetime(2026, 6, 24, tzinfo=UTC),
        )


def test_identity_equality_by_id() -> None:
    assert _build("same") == _build("same")
    assert _build("a") != _build("b")


def test_hashable_by_id() -> None:
    assert len({_build("a"), _build("a"), _build("b")}) == 2


def test_delete_retires_the_account() -> None:
    person = _build("id-1")

    person.delete()

    assert person.status is PersonStatus.DELETED


def test_delete_neutralizes_the_email_to_an_id_derived_sentinel() -> None:
    person = _build("id-1")

    person.delete()

    # The original address is gone; the sentinel is collision-free (derived from the id) and still a valid
    # email, so the freed address can later be reused by a brand-new person.
    assert person.email != EmailValueObject("ana@example.com")
    assert person.email.value == "deleted+id-1@trocado.invalid"


def test_delete_keeps_identity_by_id() -> None:
    person = _build("same")
    person.delete()

    # A person IS its id: retiring it neither changes identity nor its hash.
    assert person == _build("same")
    assert hash(person) == hash(_build("same"))
