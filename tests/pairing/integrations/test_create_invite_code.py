import asyncio
from datetime import timedelta

from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.pairing.application.data.create_invite_code_data import CreateInviteCodeData
from trocado.features.pairing.application.use_cases.create_invite_code_use_case import (
    CreateInviteCodeUseCase,
)
from trocado.features.pairing.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.pairing.infrastructure.repositories.invite_code_repository import (
    InviteCodeRepository,
)


def _build() -> tuple[CreateInviteCodeUseCase, InviteCodeRepository]:
    repository = InviteCodeRepository()
    use_case = CreateInviteCodeUseCase(
        clock=Clock(),
        repository=repository,
        identifier=IdentifierProvider(),
        token_generator=TokenGenerator(),
    )

    return use_case, repository


def test_real_adapters_mint_an_invite_code() -> None:
    use_case, _ = _build()

    data = asyncio.run(use_case.execute(CreateInviteCodeData(creator_id="person-1")))

    # A real uuid7 string id (canonical 36-char form) and a timezone-aware timestamp.
    assert len(data.id) == 36
    assert data.creator_id == "person-1"
    assert data.code
    assert data.consumed_at is None
    assert data.created_at.tzinfo is not None
    assert data.expires_at == data.created_at + timedelta(days=1)
