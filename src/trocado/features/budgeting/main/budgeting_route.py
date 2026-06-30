from __future__ import annotations

from datetime import date
from decimal import Decimal

from litestar import Router
from litestar.di import NamedDependency, Provide

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.core.application.interfaces.spend_reader_interface import SpendReaderInterface
from trocado.core.infrastructure.gateways.spend_reader import SpendReader
from trocado.core.infrastructure.http.errors.handlers.exception_handlers import build_domain_exception_handlers
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.use_cases.create_budget_use_case import CreateBudgetUseCase
from trocado.features.budgeting.application.use_cases.delete_budget_use_case import DeleteBudgetUseCase
from trocado.features.budgeting.application.use_cases.get_active_budget_use_case import GetActiveBudgetUseCase
from trocado.features.budgeting.application.use_cases.list_budgets_use_case import ListBudgetsUseCase
from trocado.features.budgeting.application.use_cases.update_budget_use_case import UpdateBudgetUseCase
from trocado.features.budgeting.infrastructure.http.controllers.budget_controller import BudgetController
from trocado.features.budgeting.infrastructure.http.errors.lookups.budgeting_status_error import BUDGETING_STATUS_ERROR
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository


def register_budgeting_router() -> Router:
    """Build budgeting's web slice: its controllers plus the dependencies **scoped to this feature**.

    Creates and owns its own ``BudgetRepository`` and ``ExpenseRepository``. Wraps
    ``expense_repository.find_in_range`` in a callable and passes it to ``SpendReader`` from core so
    no feature imports another feature. The cross-cutting ports (``clock``, ``identifier``) sit at
    the app layer and are inherited through Litestar's layered DI.

    Error framing is scoped to this router: budgeting's domain errors are framed here; cross-cutting
    handlers (422, HTTP fallback) stay at the app layer.
    """
    repository: BudgetRepositoryInterface = BudgetRepository()
    expense_repository = ExpenseRepository()

    async def _fetch_amounts(person_id: str, start: date, end: date) -> list[Decimal]:
        expenses = await expense_repository.find_in_range(person_id, start, end)
        return [e.amount.value for e in expenses]

    spend_reader: SpendReaderInterface = SpendReader(_fetch_amounts)

    async def provide_budget_repository() -> BudgetRepositoryInterface:
        return repository

    async def provide_spend_reader() -> SpendReaderInterface:
        return spend_reader

    async def provide_create_budget_use_case(
        clock: NamedDependency[ClockInterface],
        identifier: NamedDependency[IdentifierProviderInterface],
        budget_repository: NamedDependency[BudgetRepositoryInterface],
    ) -> CreateBudgetUseCase:
        return CreateBudgetUseCase(clock=clock, repository=budget_repository, identifier=identifier)

    async def provide_list_budgets_use_case(
        budget_repository: NamedDependency[BudgetRepositoryInterface],
    ) -> ListBudgetsUseCase:
        return ListBudgetsUseCase(repository=budget_repository)

    async def provide_get_active_budget_use_case(
        budget_repository: NamedDependency[BudgetRepositoryInterface],
        spend_reader: NamedDependency[SpendReaderInterface],
    ) -> GetActiveBudgetUseCase:
        return GetActiveBudgetUseCase(repository=budget_repository, spend_reader=spend_reader)

    async def provide_update_budget_use_case(
        budget_repository: NamedDependency[BudgetRepositoryInterface],
    ) -> UpdateBudgetUseCase:
        return UpdateBudgetUseCase(repository=budget_repository)

    async def provide_delete_budget_use_case(
        clock: NamedDependency[ClockInterface],
        budget_repository: NamedDependency[BudgetRepositoryInterface],
    ) -> DeleteBudgetUseCase:
        return DeleteBudgetUseCase(clock=clock, repository=budget_repository)

    router = Router(
        path="/",
        route_handlers=[BudgetController],
        dependencies={
            "spend_reader": Provide(provide_spend_reader),
            "budget_repository": Provide(provide_budget_repository),
            "list_budgets_use_case": Provide(provide_list_budgets_use_case),
            "create_budget_use_case": Provide(provide_create_budget_use_case),
            "delete_budget_use_case": Provide(provide_delete_budget_use_case),
            "update_budget_use_case": Provide(provide_update_budget_use_case),
            "get_active_budget_use_case": Provide(provide_get_active_budget_use_case),
        },
        exception_handlers=build_domain_exception_handlers(BUDGETING_STATUS_ERROR),
    )
    return router
