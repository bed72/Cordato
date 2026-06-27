import asyncio
from datetime import UTC, datetime, timedelta

import pytest

from tests.core.fakes.fake_clock import FakeClock
from tests.pairing.fakes.fake_invite_code_repository import FakeInviteCodeRepository
from trocado.features.pairing.application.data.revoke_invite_code_data import RevokeInviteCodeData
from trocado.features.pairing.application.use_cases.revoke_invite_code_use_case import (
    RevokeInviteCodeUseCase,
)
from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity
from trocado.features.pairing.domain.errors.invite_code_already_consumed_error import (
    InviteCodeAlreadyConsumedError,
)
from trocado.features.pairing.domain.errors.invite_code_not_found_error import (
    InviteCodeNotFoundError,
)

_TOKEN = "the-token"
_CREATOR = "creator-1"
_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _code(
    *,
    code: str = _TOKEN,
    creator_id: str = _CREATOR,
    created_at: datetime = _FIXED_NOW,
    revoked_at: datetime | None = None,
    consumed_at: datetime | None = None,
) -> InviteCodeEntity:
    invite_code = InviteCodeEntity.create(id="code-1", creator_id=creator_id, code=code, created_at=created_at)
    if consumed_at is not None:
        invite_code.consume(consumed_at)
    if revoked_at is not None:
        invite_code.revoke(revoked_at)
    return invite_code


def _build(
    *,
    now: datetime = _FIXED_NOW,
    codes: tuple[InviteCodeEntity, ...] = (),
) -> tuple[RevokeInviteCodeUseCase, FakeInviteCodeRepository]:
    repository = FakeInviteCodeRepository()
    repository.invite_codes.extend(codes)
    use_case = RevokeInviteCodeUseCase(clock=FakeClock(now), repository=repository)
    return use_case, repository


def _revoke(use_case: RevokeInviteCodeUseCase, *, code: str = _TOKEN, requester_id: str = _CREATOR) -> None:
    asyncio.run(use_case.execute(RevokeInviteCodeData(code=code, requester_id=requester_id)))


def test_pending_code_is_revoked() -> None:
    use_case, repository = _build(codes=(_code(),))

    _revoke(use_case)

    assert repository.invite_codes[0].is_revoked is True
    assert repository.invite_codes[0].revoked_at == _FIXED_NOW


def test_revoking_does_not_consume() -> None:
    use_case, repository = _build(codes=(_code(),))

    _revoke(use_case)

    assert repository.invite_codes[0].consumed_at is None


def test_unknown_token_is_rejected_as_not_found() -> None:
    use_case, repository = _build(codes=(_code(),))

    with pytest.raises(InviteCodeNotFoundError):
        _revoke(use_case, code="nope")

    assert repository.invite_codes[0].revoked_at is None


def test_non_owner_is_rejected_as_not_found() -> None:
    use_case, repository = _build(codes=(_code(),))

    with pytest.raises(InviteCodeNotFoundError):
        _revoke(use_case, requester_id="someone-else")

    # The code stays untouched — a non-owner learns nothing and changes nothing.
    assert repository.invite_codes[0].revoked_at is None


def test_consumed_code_cannot_be_revoked() -> None:
    consumed = _code(consumed_at=_FIXED_NOW - timedelta(hours=1))
    use_case, repository = _build(codes=(consumed,))

    with pytest.raises(InviteCodeAlreadyConsumedError):
        _revoke(use_case)

    assert repository.invite_codes[0].revoked_at is None


def test_revoking_already_revoked_is_idempotent() -> None:
    first_instant = _FIXED_NOW - timedelta(hours=2)
    already = _code(revoked_at=first_instant)
    # A clock at a later instant — a re-stamp would change the timestamp; idempotency must not.
    use_case, repository = _build(codes=(already,), now=_FIXED_NOW)

    _revoke(use_case)

    assert repository.invite_codes[0].revoked_at == first_instant


def test_expired_but_unconsumed_code_can_be_revoked() -> None:
    past_expiry = _FIXED_NOW + timedelta(days=2)  # well past expires_at (created_at + 1 day)
    use_case, repository = _build(codes=(_code(),), now=past_expiry)

    _revoke(use_case)

    assert repository.invite_codes[0].revoked_at == past_expiry
