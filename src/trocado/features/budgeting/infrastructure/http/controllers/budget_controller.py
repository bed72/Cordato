from __future__ import annotations

from litestar import Controller, post
from litestar.di import NamedDependency

from trocado.features.budgeting.application.use_cases.create_budget_use_case import CreateBudgetUseCase
from trocado.features.budgeting.infrastructure.http.mappers.requests.create_budget_request_mapper import (
    CreateBudgetRequestMapper,
)
from trocado.features.budgeting.infrastructure.http.mappers.responses.budget_response_mapper import (
    BudgetResponseMapper,
)
from trocado.features.budgeting.infrastructure.http.requests.create_budget_request import (
    CreateBudgetRequest,
)
from trocado.features.budgeting.infrastructure.http.responses.budget_response import BudgetResponse


class BudgetController(Controller):
    """The driving adapter for budgeting over HTTP — a Litestar-native class controller.

    The web edge is an inbound adapter (the mirror of a repository), so it lives in ``infrastructure/http/``
    and may know the framework; the lib stays *inside* the file and never reaches ``application``/``domain``.
    The use case is injected **by name** from the composition root's dependencies; the controller adds no
    business rule — it binds, maps, delegates, and frames — while the framework-free, server-free testable
    unit stays the use case itself, exercised in ``application`` with fakes.
    """

    path = "/budgets"
    tags = ["Budgets"]

    @post(
        summary="Criar orçamento",
        description=(
            "Cria um orçamento individual para a pessoa atuante: um valor em BRL e um período de datas "
            "inclusivas (início e fim). Responde **201 Created** com o orçamento criado. As regras de "
            "domínio (valor positivo, início não posterior ao fim, sem sobreposição com outro orçamento "
            "vivo) são aplicadas pelo domínio."
        ),
    )
    async def create(
        self, data: CreateBudgetRequest, create_budget_use_case: NamedDependency[CreateBudgetUseCase]
    ) -> BudgetResponse:
        """``POST /budgets`` — create a budget for the acting person, answering ``201 Created``.

        The body parameter **must** be named ``data``: Litestar binds and validates the JSON body into it
        natively (a malformed body is rejected at the boundary before this runs). ``data``/``request`` are both
        reserved kwargs — ``request`` would inject the ASGI ``Request`` object, not the body. ``@post`` answers
        ``201`` by default. The acting person is still a fixed placeholder inside ``CreateBudgetRequestMapper``
        until the request-identity change lands.
        """

        command = CreateBudgetRequestMapper.to_data(data)
        budget = await create_budget_use_case.execute(command)

        return BudgetResponseMapper.to_response(budget)
