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


def test_create_starts_unrevoked() -> None:
    invite_code = _build()

    assert invite_code.revoked_at is None
    assert invite_code.is_revoked is False


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


def test_is_consumed_reflects_consumed_at() -> None:
    invite_code = _build()

    assert invite_code.is_consumed is False

    invite_code.consume(_FIXED_NOW + timedelta(hours=1))

    assert invite_code.is_consumed is True


def test_consume_stamps_the_given_instant() -> None:
    invite_code = _build()
    redeemed_at = _FIXED_NOW + timedelta(hours=2)

    invite_code.consume(redeemed_at)

    assert invite_code.consumed_at == redeemed_at


def test_is_revoked_reflects_revoked_at() -> None:
    invite_code = _build()

    assert invite_code.is_revoked is False

    invite_code.revoke(_FIXED_NOW + timedelta(hours=1))

    assert invite_code.is_revoked is True


def test_revoke_stamps_the_given_instant() -> None:
    invite_code = _build()
    revoked_at = _FIXED_NOW + timedelta(hours=3)

    invite_code.revoke(revoked_at)

    assert invite_code.revoked_at == revoked_at


def test_revoke_and_consume_are_independent() -> None:
    revoked_only = _build()
    revoked_only.revoke(_FIXED_NOW + timedelta(hours=1))
    assert revoked_only.consumed_at is None

    consumed_only = _build()
    consumed_only.consume(_FIXED_NOW + timedelta(hours=1))
    assert consumed_only.revoked_at is None


def test_is_expired_is_false_before_expiry() -> None:
    invite_code = _build()

    assert invite_code.is_expired(invite_code.expires_at - timedelta(seconds=1)) is False


def test_is_expired_is_true_at_and_after_expiry() -> None:
    invite_code = _build()

    assert invite_code.is_expired(invite_code.expires_at) is True
    assert invite_code.is_expired(invite_code.expires_at + timedelta(seconds=1)) is True
