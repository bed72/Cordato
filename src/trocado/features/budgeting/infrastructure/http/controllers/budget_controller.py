from __future__ import annotations

from http import HTTPStatus

from blacksheep import Content, Request, Response
from blacksheep.server.controllers import Controller, post

from trocado.core.infrastructure.http.media_types import JSON
from trocado.features.budgeting.application.use_cases.create_budget_use_case import CreateBudgetUseCase
from trocado.features.budgeting.infrastructure.http.mappers.budget_response_mapper import (
    BudgetResponseMapper,
)
from trocado.features.budgeting.infrastructure.http.mappers.create_budget_request_mapper import (
    CreateBudgetRequestMapper,
)
from trocado.features.budgeting.infrastructure.http.requests.create_budget_request import (
    CreateBudgetRequest,
)


class BudgetController(Controller):
    """The driving adapter for budgeting over HTTP — a BlackSheep-native class controller.

    The web edge is an inbound adapter (the mirror of a repository), so it lives in ``infrastructure/http/``
    and may know the framework; the lib stays *inside* the file and never reaches ``application``/``domain``.
    The use case is injected by the Rodi container through the constructor; the controller adds no business
    rule — it parses, delegates, and frames — while the framework-free, server-free testable unit stays the
    use case itself, exercised in ``application`` with fakes.
    """

    def __init__(self, use_case: CreateBudgetUseCase) -> None:
        self._use_case = use_case

    @post("/budgets")
    async def create(self, request: Request) -> Response:
        """``POST /budgets`` — create a budget for the acting person, answering ``201 Created``.

        The body is validated **explicitly** with ``CreateBudgetRequest.model_validate`` rather than via
        BlackSheep's ``FromJSON`` binding: ``FromJSON`` would swallow a malformed body into the framework's own
        ``400``, whereas the explicit call raises ``pydantic.ValidationError``, which the registered handler
        frames as ``422`` with field detail. A ``ValidationError`` and any domain error from the use case both
        propagate untouched to the exception handlers.
        """

        payload = await request.json()
        model = CreateBudgetRequest.model_validate(payload)
        data = CreateBudgetRequestMapper.to_data(model)
        budget = await self._use_case.execute(data)
        response = BudgetResponseMapper.to_response(budget)
        return Response(HTTPStatus.CREATED, content=Content(JSON, response.model_dump_json().encode()))
