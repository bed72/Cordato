import asyncio
from datetime import UTC, datetime, timedelta

from tests.core.fakes.fake_clock import FakeClock
from tests.identity.fakes.fake_session_repository import FakeSessionRepository
from trocado.features.identity.application.data.sign_out_data import SignOutData
from trocado.features.identity.application.use_cases.sign_out_use_case import SignOutUseCase
from trocado.features.identity.domain.entities.session_entity import SessionEntity

_NOW = datetime(2026, 6, 26, tzinfo=UTC)


def _session(
    token: str,
    session_id: str,
    *,
    revoked_at: datetime | None = None,
    expires_at: datetime = _NOW + timedelta(days=30),
) -> SessionEntity:
    return SessionEntity(
        token=token,
        id=session_id,
        created_at=_NOW,
        person_id="person-1",
        expires_at=expires_at,
        revoked_at=revoked_at,
    )


def _build(*sessions: SessionEntity) -> tuple[SignOutUseCase, FakeSessionRepository]:
    session_repository = FakeSessionRepository(*sessions)
    return SignOutUseCase(clock=FakeClock(_NOW), session_repository=session_repository), session_repository


def _sign_out(use_case: SignOutUseCase, token: str) -> None:
    asyncio.run(use_case.execute(SignOutData(token=token)))


def test_live_token_is_revoked_and_then_no_longer_valid() -> None:
    use_case, session_repository = _build(_session(session_id="session-1", token="live-token"))

    _sign_out(use_case, "live-token")

    assert session_repository.sessions["session-1"].revoked_at == _NOW
    # A follow-up lookup no longer surfaces the session.
    assert asyncio.run(session_repository.find_valid_by_token("live-token", _NOW)) is None


def test_unknown_token_is_a_silent_no_op() -> None:
    use_case, session_repository = _build(_session(session_id="session-1", token="live-token"))

    _sign_out(use_case, "some-other-token")  # raises nothing

    assert session_repository.sessions["session-1"].revoked_at is None


def test_already_revoked_token_is_a_silent_no_op() -> None:
    already = _session(session_id="session-1", token="live-token", revoked_at=_NOW - timedelta(minutes=5))
    use_case, session_repository = _build(already)

    _sign_out(use_case, "live-token")  # raises nothing

    # Unchanged: the original revocation instant stays put.
    assert session_repository.sessions["session-1"].revoked_at == _NOW - timedelta(minutes=5)


def test_expired_token_is_a_silent_no_op() -> None:
    expired = _session(session_id="session-1", token="live-token", expires_at=_NOW - timedelta(seconds=1))
    use_case, session_repository = _build(expired)

    _sign_out(use_case, "live-token")  # raises nothing

    # Nothing live to revoke: the expired session is left untouched (no revocation stamp).
    assert session_repository.sessions["session-1"].revoked_at is None


def test_signing_out_one_device_leaves_the_other_session_live() -> None:
    use_case, session_repository = _build(
        _session(session_id="session-phone", token="phone-token"),
        _session(session_id="session-tablet", token="tablet-token"),
    )

    _sign_out(use_case, "phone-token")

    assert session_repository.sessions["session-phone"].revoked_at == _NOW
    assert asyncio.run(session_repository.find_valid_by_token("tablet-token", _NOW)) is not None
