import asyncio

from tests.pairing.fakes.fake_person_directory import FakePersonDirectory
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.pairing.application.data.accept_invite_code_data import AcceptInviteCodeData
from trocado.features.pairing.application.data.create_invite_code_data import CreateInviteCodeData
from trocado.features.pairing.application.data.dissolve_pair_data import DissolvePairData
from trocado.features.pairing.application.use_cases.accept_invite_code_use_case import (
    AcceptInviteCodeUseCase,
)
from trocado.features.pairing.application.use_cases.create_invite_code_use_case import (
    CreateInviteCodeUseCase,
)
from trocado.features.pairing.application.use_cases.dissolve_pair_use_case import (
    DissolvePairUseCase,
)
from trocado.features.pairing.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.pairing.infrastructure.repositories.invite_code_repository import (
    InviteCodeRepository,
)
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository


def test_real_adapters_dissolve_takes_the_view_down_and_allows_re_pairing() -> None:
    pair_repository = PairRepository()
    invite_code_repository = InviteCodeRepository()
    person_directory = FakePersonDirectory({"creator", "accepter"})

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
        person_directory=person_directory,
    )
    dissolve = DissolvePairUseCase(clock=Clock(), repository=pair_repository)

    # Form a live pair.
    first_code = asyncio.run(mint.execute(CreateInviteCodeData(creator_id="creator")))
    first_pair = asyncio.run(accept.execute(AcceptInviteCodeData(code=first_code.code, accepter_id="accepter")))
    assert asyncio.run(pair_repository.find_active_by_person("creator")) is not None

    # Dissolve it — requested by one member.
    asyncio.run(dissolve.execute(DissolvePairData(requester_id="creator")))

    # The shared view is gone for BOTH former members; no budget/expense was involved.
    assert asyncio.run(pair_repository.find_active_by_person("creator")) is None
    assert asyncio.run(pair_repository.find_active_by_person("accepter")) is None

    # Re-pairing the same two people succeeds, forming a NEW pair (new id); the old one stays in history.
    second_code = asyncio.run(mint.execute(CreateInviteCodeData(creator_id="creator")))
    second_pair = asyncio.run(accept.execute(AcceptInviteCodeData(code=second_code.code, accepter_id="accepter")))

    assert second_pair.id != first_pair.id
    assert asyncio.run(pair_repository.find_active_by_person("creator")) is not None
