from __future__ import annotations

from litestar import Controller, Request, post
from litestar.di import NamedDependency

from trocado.features.identity.application.data.sign_in_data import SignInData
from trocado.features.identity.application.data.sign_out_data import SignOutData
from trocado.features.identity.application.use_cases.sign_in_use_case import SignInUseCase
from trocado.features.identity.application.use_cases.sign_out_use_case import SignOutUseCase
from trocado.features.identity.application.use_cases.sign_up_use_case import SignUpUseCase
from trocado.features.identity.infrastructure.http.mappers.requests.sign_in_request_mapper import SignInRequestMapper
from trocado.features.identity.infrastructure.http.mappers.requests.sign_up_request_mapper import SignUpRequestMapper
from trocado.features.identity.infrastructure.http.mappers.responses.session_response_mapper import (
    SessionResponseMapper,
)
from trocado.features.identity.infrastructure.http.requests.sign_in_request import SignInRequest
from trocado.features.identity.infrastructure.http.requests.sign_up_request import SignUpRequest
from trocado.features.identity.infrastructure.http.responses.session_response import SessionResponse


class AuthenticationController(Controller):
    """Driving adapter for authentication over HTTP — sign-up, sign-in, and sign-out.

    All three routes are **public**: none declares ``current_person_data``, so the auth provider never runs
    here. The controller only binds, maps, delegates, and frames — no business rule.
    """

    path = "/authentication"
    tags = ["Authentication"]

    @post(
        "/sign-up",
        status_code=201,
        summary="Criar conta",
        description=(
            "Cadastra uma nova pessoa e emite uma sessão imediatamente. "
            "Responde **201 Created** com o token Bearer e os dados públicos da pessoa. "
            "E-mail duplicado retorna **409**; e-mail inválido ou senha fraca retornam **422**."
        ),
        security=[{}],
    )
    async def sign_up(
        self,
        data: SignUpRequest,
        sign_up_use_case: NamedDependency[SignUpUseCase],
        sign_in_use_case: NamedDependency[SignInUseCase],
    ) -> SessionResponse:
        await sign_up_use_case.execute(SignUpRequestMapper.to_data(data))
        # Issue the first session immediately — sign_up_use_case creates the person; sign_in issues the token.
        session = await sign_in_use_case.execute(SignInData(email=data.email, password=data.password))
        return SessionResponseMapper.to_response(session)

    @post(
        "/sign-in",
        status_code=200,
        summary="Entrar",
        description=(
            "Verifica a credencial (e-mail + senha) e emite uma sessão. "
            "Responde **200 OK** com o token Bearer e os dados públicos da pessoa. "
            "Credencial inválida — por qualquer motivo — retorna **401** com mensagem genérica "
            "(nenhum detalhe revelado para evitar enumeração de contas)."
        ),
        security=[{}],
    )
    async def sign_in(
        self,
        data: SignInRequest,
        sign_in_use_case: NamedDependency[SignInUseCase],
    ) -> SessionResponse:
        command = SignInRequestMapper.to_data(data)
        session = await sign_in_use_case.execute(command)

        return SessionResponseMapper.to_response(session)

    @post(
        "/sign-out",
        status_code=204,
        summary="Sair",
        description=(
            "Revoga a sessão identificada pelo token Bearer no header ``Authorization``. "
            "Responde **204 No Content** em qualquer situação — token válido, desconhecido, "
            "expirado ou já revogado são tratados da mesma forma (idempotente, sem oracle)."
        ),
        security=[{"BearerToken": []}],
    )
    async def sign_out(
        self,
        request: Request,  # type: ignore[type-arg]
        sign_out_use_case: NamedDependency[SignOutUseCase],
    ) -> None:
        header = request.headers.get("Authorization", "")
        token = header[len("Bearer ") :] if header.startswith("Bearer ") else ""
        await sign_out_use_case.execute(SignOutData(token=token))
