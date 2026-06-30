from __future__ import annotations

from typing import Annotated

from litestar import Controller, delete, post
from litestar.di import NamedDependency
from litestar.params import Parameter

from trocado.features.identity.infrastructure.http.providers.current_person_provider import CurrentPersonProvider
from trocado.features.pairing.application.data.accept_invite_code_data import AcceptInviteCodeData
from trocado.features.pairing.application.data.create_invite_code_data import CreateInviteCodeData
from trocado.features.pairing.application.data.revoke_invite_code_data import RevokeInviteCodeData
from trocado.features.pairing.application.use_cases.accept_invite_code_use_case import AcceptInviteCodeUseCase
from trocado.features.pairing.application.use_cases.create_invite_code_use_case import CreateInviteCodeUseCase
from trocado.features.pairing.application.use_cases.revoke_invite_code_use_case import RevokeInviteCodeUseCase
from trocado.features.pairing.infrastructure.http.mappers.responses.accepted_pair_response_mapper import (
    AcceptedPairResponseMapper,
)
from trocado.features.pairing.infrastructure.http.mappers.responses.invite_code_response_mapper import (
    InviteCodeResponseMapper,
)
from trocado.features.pairing.infrastructure.http.responses.accepted_pair_response import AcceptedPairResponse
from trocado.features.pairing.infrastructure.http.responses.invite_code_response import InviteCodeResponse


class InviteController(Controller):
    path = "/invites"
    tags = ["Pairing"]

    @post(
        summary="Criar convite",
        description=(
            "Gera um invite code CSPRNG de uso único para o parceiro resgatar. "
            "O code expira em ~1 dia. Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def create(
        self,
        current_person_provider: NamedDependency[CurrentPersonProvider],
        create_invite_code_use_case: NamedDependency[CreateInviteCodeUseCase],
    ) -> InviteCodeResponse:
        """``POST /invites`` — mint a single-use invite code, answering ``201 Created``."""
        person = await current_person_provider.data()
        data = await create_invite_code_use_case.execute(CreateInviteCodeData(creator_id=person.id))
        return InviteCodeResponseMapper.to_response(data)

    @delete(
        "/{code:str}",
        summary="Revogar convite",
        description=(
            "Revoga o invite code do criador pelo token. Idempotente se já revogado. "
            "Falha com 409 se o code já foi consumido. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
        status_code=204,
    )
    async def revoke(
        self,
        code: Annotated[str, Parameter(title="code")],
        current_person_provider: NamedDependency[CurrentPersonProvider],
        revoke_invite_code_use_case: NamedDependency[RevokeInviteCodeUseCase],
    ) -> None:
        """``DELETE /invites/{code}`` — revoke a pending invite, answering ``204 No Content``."""
        person = await current_person_provider.data()
        await revoke_invite_code_use_case.execute(RevokeInviteCodeData(code=code, requester_id=person.id))

    @post(
        "/{code:str}/accept",
        summary="Aceitar convite",
        description=(
            "Resgata um invite code e forma o par entre o criador e o aceitante. "
            "O code é consumido atomicamente. "
            "Falha com 409 para código expirado, consumido, revogado, self-pairing ou já emparelhado. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def accept(
        self,
        code: Annotated[str, Parameter(title="code")],
        current_person_provider: NamedDependency[CurrentPersonProvider],
        accept_invite_code_use_case: NamedDependency[AcceptInviteCodeUseCase],
    ) -> AcceptedPairResponse:
        """``POST /invites/{code}/accept`` — redeem the invite and form the pair, answering ``201 Created``."""
        person = await current_person_provider.data()
        pair = await accept_invite_code_use_case.execute(AcceptInviteCodeData(code=code, accepter_id=person.id))
        return AcceptedPairResponseMapper.to_response(pair)
