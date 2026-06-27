import asyncio

import pytest

from tests.pairing.fakes.fake_person_directory import FakePersonDirectory
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.pairing.application.data.accept_invite_code_data import AcceptInviteCodeData
from trocado.features.pairing.application.data.create_invite_code_data import CreateInviteCodeData
from trocado.features.pairing.application.data.revoke_invite_code_data import RevokeInviteCodeData
from trocado.features.pairing.application.use_cases.accept_invite_code_use_case import (
    AcceptInviteCodeUseCase,
)
from trocado.features.pairing.application.use_cases.create_invite_code_use_case import (
    CreateInviteCodeUseCase,
)
from trocado.features.pairing.application.use_cases.revoke_invite_code_use_case import (
    RevokeInviteCodeUseCase,
)
from trocado.features.pairing.domain.errors.invite_code_already_consumed_error import (
    InviteCodeAlreadyConsumedError,
)
from trocado.features.pairing.domain.errors.invite_code_not_found_error import (
    InviteCodeNotFoundError,
)
from trocado.features.pairing.domain.errors.invite_code_revoked_error import InviteCodeRevokedError
from trocado.features.pairing.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.pairing.infrastructure.repositories.invite_code_repository import (
    InviteCodeRepository,
)
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository


def _wire() -> tuple[
    InviteCodeRepository,
    CreateInviteCodeUseCase,
    RevokeInviteCodeUseCase,
    AcceptInviteCodeUseCase,
]:
    invite_code_repository = InviteCodeRepository()
    pair_repository = PairRepository()
    mint = CreateInviteCodeUseCase(
        clock=Clock(),
        identifier=IdentifierProvider(),
        token_generator=TokenGenerator(),
        repository=invite_code_repository,
    )
    revoke = RevokeInviteCodeUseCase(clock=Clock(), repository=invite_code_repository)
    accept = AcceptInviteCodeUseCase(
        clock=Clock(),
        identifier=IdentifierProvider(),
        pair_repository=pair_repository,
        invite_repository=invite_code_repository,
        person_directory=FakePersonDirectory({"creator", "accepter"}),
    )
    return invite_code_repository, mint, revoke, accept


def test_revoked_code_can_no_longer_be_accepted() -> None:
    invite_code_repository, mint, revoke, accept = _wire()

    minted = asyncio.run(mint.execute(CreateInviteCodeData(creator_id="creator")))
    asyncio.run(revoke.execute(RevokeInviteCodeData(code=minted.code, requester_id="creator")))

    # The stored code is revoked, and redemption is now refused end to end.
    assert invite_code_repository._invite_codes[minted.id].revoked_at is not None
    with pytest.raises(InviteCodeRevokedError):
        asyncio.run(accept.execute(AcceptInviteCodeData(code=minted.code, accepter_id="accepter")))


def test_non_owner_cannot_revoke_and_code_stays_live() -> None:
    invite_code_repository, mint, revoke, accept = _wire()

    minted = asyncio.run(mint.execute(CreateInviteCodeData(creator_id="creator")))

    with pytest.raises(InviteCodeNotFoundError):
        asyncio.run(revoke.execute(RevokeInviteCodeData(code=minted.code, requester_id="intruder")))

    # Untouched by the rejected revoke, the code still redeems normally.
    assert invite_code_repository._invite_codes[minted.id].revoked_at is None
    pair = asyncio.run(accept.execute(AcceptInviteCodeData(code=minted.code, accepter_id="accepter")))
    assert pair.person_a_id == "creator"


def test_consumed_code_cannot_be_revoked() -> None:
    _, mint, revoke, accept = _wire()

    minted = asyncio.run(mint.execute(CreateInviteCodeData(creator_id="creator")))
    asyncio.run(accept.execute(AcceptInviteCodeData(code=minted.code, accepter_id="accepter")))

    with pytest.raises(InviteCodeAlreadyConsumedError):
        asyncio.run(revoke.execute(RevokeInviteCodeData(code=minted.code, requester_id="creator")))
