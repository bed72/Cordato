from datetime import UTC, datetime

from trocado.features.pairing.domain.entities.pair_entity import PairEntity

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _build(id: str = "pair-1", person_a_id: str = "person-1", person_b_id: str = "person-2") -> PairEntity:
    return PairEntity.create(
        id=id,
        created_at=_FIXED_NOW,
        person_a_id=person_a_id,
        person_b_id=person_b_id,
    )


def test_create_sets_fields_from_arguments() -> None:
    pair = _build(person_a_id="creator", person_b_id="accepter")

    assert pair.id == "pair-1"
    assert pair.person_a_id == "creator"
    assert pair.created_at == _FIXED_NOW
    assert pair.person_b_id == "accepter"


def test_create_starts_live() -> None:
    pair = _build()

    assert pair.deleted_at is None


def test_dissolve_stamps_deleted_at() -> None:
    pair = _build()
    dissolved_at = datetime(2026, 6, 26, 9, tzinfo=UTC)

    pair.dissolve(dissolved_at)

    assert pair.deleted_at == dissolved_at


def test_dissolve_leaves_identity_and_other_fields_intact() -> None:
    pair = _build(id="pair-1", person_a_id="creator", person_b_id="accepter")

    pair.dissolve(datetime(2026, 6, 26, 9, tzinfo=UTC))

    assert pair.id == "pair-1"
    assert pair.person_a_id == "creator"
    assert pair.person_b_id == "accepter"
    assert pair.created_at == _FIXED_NOW
    assert pair == _build(id="pair-1")  # equality is by id, unaffected by the stamp


def test_equality_is_by_id() -> None:
    same_id_other_fields = PairEntity.create(id="pair-1", created_at=_FIXED_NOW, person_a_id="x", person_b_id="y")

    assert _build(id="pair-1") != _build(id="pair-2")
    assert _build(id="pair-1") == same_id_other_fields


def test_hash_is_by_id() -> None:
    assert hash(_build(id="pair-1")) == hash(_build(id="pair-1", person_a_id="other"))
