from datetime import UTC, datetime, timedelta

from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _build(id: str = "code-1", code: str = "tok") -> InviteCodeEntity:
    return InviteCodeEntity.create(id=id, creator_id="person-1", code=code, created_at=_FIXED_NOW)


def test_create_sets_fields_from_arguments() -> None:
    invite_code = _build(code="abc123")

    assert invite_code.id == "code-1"
    assert invite_code.code == "abc123"
    assert invite_code.creator_id == "person-1"
    assert invite_code.created_at == _FIXED_NOW


def test_create_starts_unconsumed() -> None:
    invite_code = _build()

    assert invite_code.consumed_at is None


def test_expiry_is_one_day_past_creation() -> None:
    invite_code = _build()

    assert invite_code.expires_at == _FIXED_NOW + timedelta(days=1)


def test_equality_is_by_id() -> None:
    same_id_other_fields = InviteCodeEntity.create(
        id="code-1", creator_id="person-2", code="other", created_at=_FIXED_NOW
    )

    assert _build(id="code-1") != _build(id="code-2")
    assert _build(id="code-1") == same_id_other_fields


def test_hash_is_by_id() -> None:
    assert hash(_build(id="code-1")) == hash(_build(id="code-1", code="different"))
