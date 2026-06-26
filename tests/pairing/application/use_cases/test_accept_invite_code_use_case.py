import asyncio
from datetime import UTC, datetime, timedelta

import pytest

from tests.core.fakes.fake_clock import FakeClock
from tests.core.fakes.fake_identifier_provider import FakeIdentifierProvider
from tests.pairing.fakes.fake_invite_code_repository import FakeInviteCodeRepository
from tests.pairing.fakes.fake_pair_repository import FakePairRepository
from tests.pairing.fakes.fake_person_directory import FakePersonDirectory
from trocado.features.pairing.application.data.accept_invite_code_data import AcceptInviteCodeData
from trocado.features.pairing.application.use_cases.accept_invite_code_use_case import (
    AcceptInviteCodeUseCase,
)
from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity
from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.domain.errors.already_paired_error import AlreadyPairedError
from trocado.features.pairing.domain.errors.invite_code_already_consumed_error import (
    InviteCodeAlreadyConsumedError,
)
from trocado.features.pairing.domain.errors.invite_code_expired_error import InviteCodeExpiredError
from trocado.features.pairing.domain.errors.invite_code_not_found_error import (
    InviteCodeNotFoundError,
)
from trocado.features.pairing.domain.errors.person_not_active_error import PersonNotActiveError
from trocado.features.pairing.domain.errors.self_pairing_error import SelfPairingError

_TOKEN = "the-token"
_CREATOR = "creator-1"
_ACCEPTER = "accepter-1"
_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _code(
    *,
    code: str = _TOKEN,
    creator_id: str = _CREATOR,
    created_at: datetime = _FIXED_NOW,
    consumed_at: datetime | None = None,
) -> InviteCodeEntity:
    invite_code = InviteCodeEntity.create(id="code-1", creator_id=creator_id, code=code, created_at=created_at)
    if consumed_at is not None:
        invite_code.consume(consumed_at)
    return invite_code


def _build(
    *,
    now: datetime = _FIXED_NOW,
    identifier: str = "pair-1",
    active_ids: set[str] | None = None,
    pairs: tuple[PairEntity, ...] = (),
    codes: tuple[InviteCodeEntity, ...] = (),
) -> tuple[AcceptInviteCodeUseCase, FakeInviteCodeRepository, FakePairRepository]:
    invite_code_repository = FakeInviteCodeRepository()
    invite_code_repository.invite_codes.extend(codes)
    pair_repository = FakePairRepository(*pairs)
    use_case = AcceptInviteCodeUseCase(
        clock=FakeClock(now),
        pair_repository=pair_repository,
        invite_repository=invite_code_repository,
        identifier=FakeIdentifierProvider(identifier),
        person_directory=FakePersonDirectory(active_ids),
    )

    return use_case, invite_code_repository, pair_repository


def _accept(use_case: AcceptInviteCodeUseCase, *, code: str = _TOKEN, accepter_id: str = _ACCEPTER):  # type: ignore[no-untyped-def]
    return asyncio.run(use_case.execute(AcceptInviteCodeData(code=code, accepter_id=accepter_id)))


def test_valid_invite_forms_the_pair() -> None:
    use_case, _, pair_repository = _build(codes=(_code(),))

    data = _accept(use_case)

    assert data.id == "pair-1"
    assert data.person_a_id == _CREATOR  # creator
    assert data.person_b_id == _ACCEPTER  # accepter
    assert data.created_at == _FIXED_NOW
    assert len(pair_repository.pairs) == 1
    assert pair_repository.pairs[0].deleted_at is None


def test_accepting_consumes_the_code() -> None:
    use_case, invite_code_repository, _ = _build(codes=(_code(),))

    _accept(use_case)

    assert invite_code_repository.invite_codes[0].consumed_at == _FIXED_NOW


def test_unknown_token_is_rejected() -> None:
    use_case, _, pair_repository = _build(codes=(_code(),))

    with pytest.raises(InviteCodeNotFoundError):
        _accept(use_case, code="nope")

    assert pair_repository.pairs == []


def test_expired_code_is_rejected() -> None:
    expired_at = _FIXED_NOW + timedelta(days=1)  # expires_at == created_at + 1 day
    use_case, invite_code_repository, pair_repository = _build(codes=(_code(),), now=expired_at)

    with pytest.raises(InviteCodeExpiredError):
        _accept(use_case)

    assert pair_repository.pairs == []
    assert invite_code_repository.invite_codes[0].consumed_at is None


def test_code_on_its_last_moment_is_still_live() -> None:
    last_live = _FIXED_NOW + timedelta(days=1) - timedelta(seconds=1)
    use_case, _, pair_repository = _build(codes=(_code(),), now=last_live)

    data = _accept(use_case)

    assert data.created_at == last_live
    assert len(pair_repository.pairs) == 1


def test_already_consumed_code_is_rejected() -> None:
    consumed = _code(consumed_at=_FIXED_NOW - timedelta(hours=1))
    use_case, _, pair_repository = _build(codes=(consumed,))

    with pytest.raises(InviteCodeAlreadyConsumedError):
        _accept(use_case)

    assert pair_repository.pairs == []


def test_self_pairing_is_rejected() -> None:
    use_case, invite_code_repository, pair_repository = _build(codes=(_code(),))

    with pytest.raises(SelfPairingError):
        _accept(use_case, accepter_id=_CREATOR)

    assert pair_repository.pairs == []
    assert invite_code_repository.invite_codes[0].consumed_at is None


def _live_pair(person_a_id: str, person_b_id: str) -> PairEntity:
    return PairEntity.create(id="existing", created_at=_FIXED_NOW, person_a_id=person_a_id, person_b_id=person_b_id)


def test_accepter_already_paired_is_rejected() -> None:
    existing = _live_pair(_ACCEPTER, "someone-else")
    use_case, _, pair_repository = _build(codes=(_code(),), pairs=(existing,))

    with pytest.raises(AlreadyPairedError):
        _accept(use_case)

    assert len(pair_repository.pairs) == 1  # no new pair added


def test_creator_already_paired_is_rejected() -> None:
    existing = _live_pair(_CREATOR, "someone-else")
    use_case, _, pair_repository = _build(codes=(_code(),), pairs=(existing,))

    with pytest.raises(AlreadyPairedError):
        _accept(use_case)

    assert len(pair_repository.pairs) == 1


def test_dissolved_past_pair_does_not_block() -> None:
    dissolved = PairEntity(
        id="old",
        person_a_id=_CREATOR,
        person_b_id=_ACCEPTER,
        created_at=_FIXED_NOW - timedelta(days=30),
        deleted_at=_FIXED_NOW - timedelta(days=10),
    )
    use_case, _, pair_repository = _build(codes=(_code(),), pairs=(dissolved,))

    data = _accept(use_case)

    assert data.id == "pair-1"
    assert len(pair_repository.pairs) == 2  # the dissolved one plus the new live one


def test_inactive_accepter_is_rejected() -> None:
    use_case, _, pair_repository = _build(codes=(_code(),), active_ids={_CREATOR})

    with pytest.raises(PersonNotActiveError):
        _accept(use_case)

    assert pair_repository.pairs == []


def test_inactive_creator_is_rejected() -> None:
    use_case, _, pair_repository = _build(codes=(_code(),), active_ids={_ACCEPTER})

    with pytest.raises(PersonNotActiveError):
        _accept(use_case)

    assert pair_repository.pairs == []
