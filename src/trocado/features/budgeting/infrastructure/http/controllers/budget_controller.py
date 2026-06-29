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
from trocado.features.identity.infrastructure.http.providers.current_person_provider import CurrentPersonProvider


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
            "vivo) são aplicadas pelo domínio. Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def create(
        self,
        data: CreateBudgetRequest,
        create_budget_use_case: NamedDependency[CreateBudgetUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> BudgetResponse:
        """``POST /budgets`` — create a budget for the acting person, answering ``201 Created``."""
        person = await current_person_provider.data()
        command = CreateBudgetRequestMapper.to_data(request=data, person_id=person.id)
        budget = await create_budget_use_case.execute(command)

        return BudgetResponseMapper.to_response(budget)
