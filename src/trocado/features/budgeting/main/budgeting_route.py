from __future__ import annotations

from litestar import Router
from litestar.di import NamedDependency, Provide

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.core.infrastructure.http.errors.handlers.exception_handlers import build_domain_exception_handlers
from trocado.core.infrastructure.http.errors.lookups.core_status_error import CORE_STATUS_ERROR
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.use_cases.create_budget_use_case import CreateBudgetUseCase
from trocado.features.budgeting.infrastructure.http.controllers.budget_controller import BudgetController
from trocado.features.budgeting.infrastructure.http.errors.lookups.budgeting_status_error import BUDGETING_STATUS_ERROR
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository


def register_budgeting_router() -> Router:
    """Build budgeting's web slice: its controllers plus the dependencies **scoped to this feature**.

    Returns a ``Router`` carrying budgeting's own providers, not entries merged into the app's global
    dependency namespace. Two payoffs: a feature's keys (``budget_repository``, ``create_budget_use_case``)
    cannot collide with another feature's — they live in this router's scope, not a shared dict — and the
    object graph is rebuilt on every call, so each ``build()`` gets fresh singletons (a test builds an
    isolated app). The cross-cutting ports (``clock``, ``identifier``) are **not** contributed here: they sit
    at the app layer (``register_core_providers``) and Litestar resolves them through the layered scope when
    this router's use-case provider asks for them by name.

    Error framing is **also scoped to this router**: budgeting's own domain errors (merged with the shared core
    errors it can raise, like ``InvalidMoneyError``) are framed by handlers registered here, mirroring the scoped
    DI. The cross-cutting handlers (``ValidationException`` → 422, the ``HTTPException`` fallback) stay at the app
    layer; Litestar resolves the most specific across layers, so a budgeting domain error is framed here while a
    validation error is framed at the app.

    Lifetimes: the in-memory ``BudgetRepository`` is an **app-scoped singleton** — built once here and closed
    over by its provider, so every request shares the same in-memory "database" (a per-request instance would
    start empty every time). The use case is **per-request**: Litestar resolves it fresh for each request,
    injecting its ports by name — nothing self-constructs its dependencies.
    """
    repository = BudgetRepository()

    async def provide_budget_repository() -> BudgetRepositoryInterface:
        return repository

    async def provide_create_budget_use_case(
        clock: NamedDependency[ClockInterface],
        identifier: NamedDependency[IdentifierProviderInterface],
        budget_repository: NamedDependency[BudgetRepositoryInterface],
    ) -> CreateBudgetUseCase:
        return CreateBudgetUseCase(clock=clock, repository=budget_repository, identifier=identifier)

    return Router(
        path="/",
        route_handlers=[BudgetController],
        dependencies={
            "budget_repository": Provide(provide_budget_repository),
            "create_budget_use_case": Provide(provide_create_budget_use_case),
        },
        exception_handlers=build_domain_exception_handlers({**CORE_STATUS_ERROR, **BUDGETING_STATUS_ERROR}),
    )
