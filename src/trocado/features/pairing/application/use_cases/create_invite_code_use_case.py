from __future__ import annotations

import asyncio

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.features.pairing.application.data.create_invite_code_data import CreateInviteCodeData
from trocado.features.pairing.application.data.invite_code_data import InviteCodeData
from trocado.features.pairing.application.interfaces.invite_code_repository_interface import (
    InviteCodeRepositoryInterface,
)
from trocado.features.pairing.application.interfaces.token_generator_interface import (
    TokenGeneratorInterface,
)
from trocado.features.pairing.application.mappers.invite_code_data_mapper import InviteCodeDataMapper
from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity


class CreateInviteCodeUseCase:
    """Mint an invite code: draw a token, assign identity + timestamp, persist, return public data."""

    def __init__(
        self,
        clock: ClockInterface,
        identifier: IdentifierProviderInterface,
        token_generator: TokenGeneratorInterface,
        repository: InviteCodeRepositoryInterface,
    ) -> None:
        self._clock = clock
        self._repository = repository
        self._identifier = identifier
        self._token_generator = token_generator

    async def execute(self, data: CreateInviteCodeData) -> InviteCodeData:
        # The three reads are mutually independent — issue them together; no guard to short-circuit.
        created_at, id, code = await asyncio.gather(
            self._clock.now(),
            self._identifier.generate(),
            self._token_generator.generate(),
        )

        invite_code = InviteCodeEntity.create(
            id=id,
            code=code,
            created_at=created_at,
            creator_id=data.creator_id,
        )
        await self._repository.create(invite_code)

        return InviteCodeDataMapper.to_data(invite_code)
