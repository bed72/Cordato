from __future__ import annotations

import asyncio
from typing import Annotated

from litestar import Controller, delete, get, patch, post
from litestar.di import NamedDependency
from litestar.params import Parameter

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.budgeting.application.data.delete_budget_data import DeleteBudgetData
from trocado.features.budgeting.application.use_cases.create_budget_use_case import CreateBudgetUseCase
from trocado.features.budgeting.application.use_cases.delete_budget_use_case import DeleteBudgetUseCase
from trocado.features.budgeting.application.use_cases.get_active_budget_use_case import GetActiveBudgetUseCase
from trocado.features.budgeting.application.use_cases.list_budgets_use_case import ListBudgetsUseCase
from trocado.features.budgeting.application.use_cases.update_budget_use_case import UpdateBudgetUseCase
from trocado.features.budgeting.domain.errors.budget_not_found_error import BudgetNotFoundError
from trocado.features.budgeting.infrastructure.http.mappers.requests.create_budget_request_mapper import (
    CreateBudgetRequestMapper,
)
from trocado.features.budgeting.infrastructure.http.mappers.requests.update_budget_request_mapper import (
    UpdateBudgetRequestMapper,
)
from trocado.features.budgeting.infrastructure.http.mappers.responses.active_budget_response_mapper import (
    ActiveBudgetResponseMapper,
)
from trocado.features.budgeting.infrastructure.http.mappers.responses.budget_response_mapper import (
    BudgetResponseMapper,
)
from trocado.features.budgeting.infrastructure.http.requests.create_budget_request import (
    CreateBudgetRequest,
)
from trocado.features.budgeting.infrastructure.http.requests.update_budget_request import UpdateBudgetRequest
from trocado.features.budgeting.infrastructure.http.responses.active_budget_response import ActiveBudgetResponse
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

    @get(
        summary="Listar orçamentos",
        description=(
            "Retorna os orçamentos vivos da pessoa atuante, ordenados pelo período mais recente primeiro. "
            "Lista vazia quando não há orçamentos. Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def list_budgets(
        self,
        list_budgets_use_case: NamedDependency[ListBudgetsUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> list[BudgetResponse]:
        """``GET /budgets`` — list the acting person's live budgets, most-recent-period-first."""
        person = await current_person_provider.data()
        budgets = await list_budgets_use_case.execute(person.id)
        return [BudgetResponseMapper.to_response(budget) for budget in budgets]

    @get(
        "/active",
        summary="Orçamento ativo",
        description=(
            "Retorna o orçamento ativo da pessoa atuante para hoje, enriquecido com ``total_spent`` e "
            "``remaining``. Responde **404** quando nenhum orçamento vivo contém o dia de hoje. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def active(
        self,
        clock: NamedDependency[ClockInterface],
        current_person_provider: NamedDependency[CurrentPersonProvider],
        get_active_budget_use_case: NamedDependency[GetActiveBudgetUseCase],
    ) -> ActiveBudgetResponse:
        """``GET /budgets/active`` — active budget for today, enriched with spend; ``404`` when none."""
        today, person = await asyncio.gather(clock.now(), current_person_provider.data())
        data = await get_active_budget_use_case.execute(person_id=person.id, day=today.date())
        if data is None:
            raise BudgetNotFoundError()
        return ActiveBudgetResponseMapper.to_response(data)

    @patch(
        "/{budget_id:str}",
        summary="Editar orçamento",
        description=(
            "Substitui todos os campos editáveis (valor, período, nota) de um orçamento da pessoa atuante. "
            "Semântica de **substituição completa** — todos os campos são obrigatórios. "
            "Responde **200 OK** com o orçamento atualizado. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def update(
        self,
        data: UpdateBudgetRequest,
        budget_id: Annotated[str, Parameter(title="budget_id")],
        update_budget_use_case: NamedDependency[UpdateBudgetUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> BudgetResponse:
        """``PATCH /budgets/{budget_id}`` — full-replace a live budget, answering ``200 OK``."""
        person = await current_person_provider.data()
        command = UpdateBudgetRequestMapper.to_data(request=data, person_id=person.id, budget_id=budget_id)
        budget = await update_budget_use_case.execute(command)
        return BudgetResponseMapper.to_response(budget)

    @delete(
        "/{budget_id:str}",
        summary="Remover orçamento",
        description=(
            "Soft-deleta um orçamento da pessoa atuante. O orçamento deixa de aparecer nas listagens normais "
            "mas permanece visível na auditoria. Responde **204 No Content** sem corpo. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
        status_code=204,
    )
    async def remove(
        self,
        budget_id: Annotated[str, Parameter(title="budget_id")],
        delete_budget_use_case: NamedDependency[DeleteBudgetUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> None:
        """``DELETE /budgets/{budget_id}`` — soft-delete a live budget, answering ``204 No Content``."""
        person = await current_person_provider.data()
        command = DeleteBudgetData(requester_id=person.id, budget_id=budget_id)
        await delete_budget_use_case.execute(command)
