from __future__ import annotations

import asyncio

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.features.pairing.application.data.accept_invite_code_data import AcceptInviteCodeData
from trocado.features.pairing.application.data.pair_data import PairData
from trocado.features.pairing.application.interfaces.invite_code_repository_interface import (
    InviteCodeRepositoryInterface,
)
from trocado.features.pairing.application.interfaces.pair_repository_interface import (
    PairRepositoryInterface,
)
from trocado.features.pairing.application.interfaces.person_directory_interface import (
    PersonDirectoryInterface,
)
from trocado.features.pairing.application.mappers.pair_data_mapper import PairDataMapper
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


class AcceptInviteCodeUseCase:
    """Redeem an invite: validate the code and every pairing invariant, then consume it and form the pair."""

    def __init__(
        self,
        clock: ClockInterface,
        identifier: IdentifierProviderInterface,
        pair_repository: PairRepositoryInterface,
        person_directory: PersonDirectoryInterface,
        invite_repository: InviteCodeRepositoryInterface,
    ) -> None:
        self._clock = clock
        self._identifier = identifier
        self._pair_repository = pair_repository
        self._person_directory = person_directory
        self._invite_repository = invite_repository

    async def execute(self, data: AcceptInviteCodeData) -> PairData:
        invite_code = await self._invite_repository.find_by_token(data.code)
        if invite_code is None:
            raise InviteCodeNotFoundError()

        # The code's own state decides redeemability — guard on it before any further work.
        now = await self._clock.now()
        if invite_code.is_expired(now):
            raise InviteCodeExpiredError()
        if invite_code.is_consumed:
            raise InviteCodeAlreadyConsumedError()

        creator_id = invite_code.creator_id
        if data.accepter_id == creator_id:
            raise SelfPairingError()

        # The remaining checks and the fresh id are mutually independent — issue them together.
        (
            id,
            creator_active,
            accepter_active,
            creator_pair,
            accepter_pair,
        ) = await asyncio.gather(
            self._identifier.generate(),
            self._person_directory.is_active(creator_id),
            self._person_directory.is_active(data.accepter_id),
            self._pair_repository.find_active_by_person(creator_id),
            self._pair_repository.find_active_by_person(data.accepter_id),
        )

        if creator_pair is not None or accepter_pair is not None:
            raise AlreadyPairedError()
        if not creator_active or not accepter_active:
            raise PersonNotActiveError()

        invite_code.consume(now)
        pair = PairEntity.create(
            id=id,
            created_at=now,
            person_a_id=creator_id,
            person_b_id=data.accepter_id,
        )

        await asyncio.gather(
            self._pair_repository.create(pair),
            self._invite_repository.consume(invite_code),
        )

        return PairDataMapper.to_data(pair)
