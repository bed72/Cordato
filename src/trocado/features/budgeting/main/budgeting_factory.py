from __future__ import annotations

from rodi import Container

from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.application.use_cases.create_budget_use_case import CreateBudgetUseCase
from trocado.features.budgeting.infrastructure.http.controllers.budget_controller import BudgetController
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository


def register_budgeting(container: Container) -> None:
    """Wire the budgeting object graph into the Rodi container.

    The stateful in-memory repository is an **app-scoped singleton** — one instance shared across requests, so
    the in-memory "database" survives between requests of a run (a per-request instance would start empty every
    time). The use case and controller are **transient**: Rodi resolves them fresh per request, injecting the
    registered ports by type — nothing self-constructs its dependencies. The cross-cutting core gateways (clock,
    identifier provider) are not registered here: ``register_core`` already wired them once for the whole app.
    """
    container.add_instance(BudgetRepository(), BudgetRepositoryInterface)
    container.add_transient(CreateBudgetUseCase)
    container.add_transient(BudgetController)
