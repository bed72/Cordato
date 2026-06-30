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


def register_expenses_router(expense_repository: ExpenseRepositoryInterface | None = None) -> Router:
    """Build expenses' web slice: its controllers plus the dependencies **scoped to this feature**.

    Accepts an optional ``expense_repository`` so the composition root can inject a shared instance
    (required when cross-module adapters like ``PartnerExpenseReader`` must read from the same
    in-memory store). When omitted, creates its own ``ExpenseRepository`` — the default for
    standalone test setups. The cross-cutting ports (``clock``, ``identifier``) sit at the app layer
    and are inherited through Litestar's layered DI.

    Error framing is scoped to this router: expenses' domain errors are framed here; cross-cutting
    handlers (422, HTTP fallback) stay at the app layer.
    """
    repository: ExpenseRepositoryInterface = expense_repository or ExpenseRepository()

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
            "delete_expense_use_case": Provide(provide_delete_expense_use_case),
            "update_expense_use_case": Provide(provide_update_expense_use_case),
        },
        exception_handlers=build_domain_exception_handlers(EXPENSES_STATUS_ERROR),
    )
