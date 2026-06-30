from __future__ import annotations

from litestar import Router
from litestar.di import NamedDependency, Provide

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import IdentifierProviderInterface
from trocado.core.infrastructure.http.errors.handlers.exception_handlers import build_domain_exception_handlers
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.application.use_cases.create_expense_use_case import CreateExpenseUseCase
from trocado.features.expenses.application.use_cases.delete_expense_use_case import DeleteExpenseUseCase
from trocado.features.expenses.application.use_cases.list_expenses_use_case import ListExpensesUseCase
from trocado.features.expenses.application.use_cases.update_expense_use_case import UpdateExpenseUseCase
from trocado.features.expenses.infrastructure.http.controllers.expense_controller import ExpenseController
from trocado.features.expenses.infrastructure.http.errors.lookups.expenses_status_error import EXPENSES_STATUS_ERROR
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository


def register_expenses_router() -> Router:
    """Build expenses' web slice: its controllers plus the dependencies **scoped to this feature**.

    Returns a ``Router`` carrying expenses' own providers, not entries merged into the app's global
    dependency namespace. The object graph is rebuilt on every call, so each ``build()`` gets fresh
    singletons (a test builds an isolated app). The cross-cutting ports (``clock``, ``identifier``) are
    **not** contributed here: they sit at the app layer (``register_core_providers``) and Litestar
    resolves them through the layered scope.

    Error framing is also scoped to this router: expenses' domain errors (merged with the shared core
    errors it can raise, like ``InvalidMoneyError``) are framed by handlers registered here.

    Lifetimes: the in-memory ``ExpenseRepository`` is an **app-scoped singleton** — built once here and
    closed over by its provider. The use cases are **per-request**.
    """
    repository = ExpenseRepository()

    async def provide_expense_repository() -> ExpenseRepositoryInterface:
        return repository

    async def provide_create_expense_use_case(
        clock: NamedDependency[ClockInterface],
        identifier: NamedDependency[IdentifierProviderInterface],
        expense_repository: NamedDependency[ExpenseRepositoryInterface],
    ) -> CreateExpenseUseCase:
        return CreateExpenseUseCase(clock=clock, repository=expense_repository, identifier=identifier)

    async def provide_list_expenses_use_case(
        expense_repository: NamedDependency[ExpenseRepositoryInterface],
    ) -> ListExpensesUseCase:
        return ListExpensesUseCase(repository=expense_repository)

    async def provide_update_expense_use_case(
        expense_repository: NamedDependency[ExpenseRepositoryInterface],
    ) -> UpdateExpenseUseCase:
        return UpdateExpenseUseCase(repository=expense_repository)

    async def provide_delete_expense_use_case(
        clock: NamedDependency[ClockInterface],
        expense_repository: NamedDependency[ExpenseRepositoryInterface],
    ) -> DeleteExpenseUseCase:
        return DeleteExpenseUseCase(clock=clock, repository=expense_repository)

    return Router(
        path="/",
        route_handlers=[ExpenseController],
        dependencies={
            "expense_repository": Provide(provide_expense_repository),
            "list_expenses_use_case": Provide(provide_list_expenses_use_case),
            "create_expense_use_case": Provide(provide_create_expense_use_case),
            "update_expense_use_case": Provide(provide_update_expense_use_case),
            "delete_expense_use_case": Provide(provide_delete_expense_use_case),
        },
        exception_handlers=build_domain_exception_handlers(EXPENSES_STATUS_ERROR),
    )
