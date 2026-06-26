import asyncio

from tests.pairing.fakes.fake_person_directory import FakePersonDirectory
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.pairing.application.data.accept_invite_code_data import AcceptInviteCodeData
from trocado.features.pairing.application.data.create_invite_code_data import CreateInviteCodeData
from trocado.features.pairing.application.use_cases.accept_invite_code_use_case import (
    AcceptInviteCodeUseCase,
)
from trocado.features.pairing.application.use_cases.create_invite_code_use_case import (
    CreateInviteCodeUseCase,
)
from trocado.features.pairing.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.pairing.infrastructure.repositories.invite_code_repository import (
    InviteCodeRepository,
)
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository


def test_real_adapters_mint_then_accept_forming_a_pair() -> None:
    invite_code_repository = InviteCodeRepository()
    pair_repository = PairRepository()

    mint = CreateInviteCodeUseCase(
        clock=Clock(),
        identifier=IdentifierProvider(),
        token_generator=TokenGenerator(),
        repository=invite_code_repository,
    )
    accept = AcceptInviteCodeUseCase(
        clock=Clock(),
        identifier=IdentifierProvider(),
        pair_repository=pair_repository,
        invite_repository=invite_code_repository,
        person_directory=FakePersonDirectory({"creator", "accepter"}),
    )

    minted = asyncio.run(mint.execute(CreateInviteCodeData(creator_id="creator")))
    pair = asyncio.run(accept.execute(AcceptInviteCodeData(code=minted.code, accepter_id="accepter")))

    # A real uuid7 id, the creator/accepter linked, and a timezone-aware timestamp.
    assert len(pair.id) == 36
    assert pair.person_a_id == "creator"
    assert pair.person_b_id == "accepter"
    assert pair.created_at.tzinfo is not None

    # The code is now consumed and the creator is in exactly one live pair.
    assert invite_code_repository._invite_codes[minted.id].consumed_at is not None
    assert asyncio.run(pair_repository.find_active_by_person("creator")) is not None
