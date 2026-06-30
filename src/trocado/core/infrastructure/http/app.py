from __future__ import annotations

from litestar import Litestar, Router
from litestar.di import Provide
from litestar.openapi import OpenAPIConfig
from litestar.openapi.plugins import ScalarRenderPlugin
from litestar.openapi.spec import Components, SecurityScheme, Tag

from trocado.core.infrastructure.gateways.spend_reader import SpendReader
from trocado.core.infrastructure.http.errors.handlers.exception_handlers import build_core_exception_handlers
from trocado.core.infrastructure.http.errors.lookups.core_status_error import CORE_STATUS_ERROR
from trocado.core.main.core_provider import register_core_providers
from trocado.features.budgeting.application.interfaces.spend_reader_interface import SpendReaderInterface
from trocado.features.budgeting.main.budgeting_route import register_budgeting_router
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository
from trocado.features.expenses.main.expenses_router import register_expenses_router
from trocado.features.identity.main.identity_provider import register_identity_providers
from trocado.features.identity.main.identity_route import register_identity_router


def build() -> Litestar:
    """Assemble the Litestar application — the composition root.

    Wires two layers of dependency injection. The **app layer** holds only the genuinely cross-cutting ports
    (``clock``, ``identifier``) from ``register_core`` — shared by every feature. Each **feature** contributes
    a ``Router`` (``register_budgeting``, …) carrying its own controllers and its own scoped providers, so a
    feature's dependency keys never collide in a global namespace and Litestar resolves each handler's graph
    through the layered scope (feature router → version router → app). Nothing self-constructs its dependencies.

    Every feature router is mounted under a single **``/v1`` version prefix** owned here, at the composition
    root — versioning is a cross-cutting transport concern, so a controller declares its bare resource path
    (``/budgets``) and never hardcodes the version (final path: ``/v1/budgets``). A new API version is a new
    parent router here, not an edit across every controller.

    OpenAPI is served at ``/schema`` with the Scalar UI at ``/schema`` (raw doc at ``/schema/openapi.json``).

    Errors answer in a single **unified envelope** (``ErrorResponse``: ``status``, ``code``, ``message``,
    ``errors``) via Litestar's native ``exception_handlers``, layered like the DI: only the **cross-cutting**
    handlers live here (``ValidationException`` → 422 and the framework ``HTTPException`` fallback); each
    feature's **domain-error** handlers are scoped to its own ``Router`` (built in its factory). Litestar resolves
    the most specific across layers, so a feature's domain error is framed in its router and a validation error at
    the app.

    **Auth infrastructure** (``person_repository``, ``session_repository``, ``validate_session``, and
    ``current_person_data``) is registered at the ``/v1`` router level — not per-feature — because
    ``CurrentPersonProvider`` is a cross-cutting provider that any protected handler may trigger. The same
    singleton repositories are passed to ``register_identity`` so both sides share the same in-memory store
    within a run. Each ``build()`` call produces fresh singletons, keeping test runs isolated.

    ``spend_reader`` is registered at the ``/v1`` router level — the only cross-feature concern:
    budgeting needs to derive total spend from the expenses ledger. ``SpendReader`` lives in
    ``core/infrastructure/gateways/`` because it is the one object allowed to import from two
    feature packages simultaneously; wired here and exposed only as ``SpendReaderInterface`` so
    budgeting never mentions expenses. Pre-ORM: ``SpendReader`` holds its own ``ExpenseRepository``
    instance, separate from the one expenses uses internally — the DB will be the shared state.
    """
    spend_reader = SpendReader(ExpenseRepository())

    async def provide_spend_reader() -> SpendReaderInterface:
        return spend_reader

    api = Router(
        path="/v1",
        dependencies={
            **register_identity_providers(),
            "spend_reader": Provide(provide_spend_reader),
        },
        route_handlers=[
            register_identity_router(),
            register_expenses_router(),
            register_budgeting_router(),
        ],
    )

    return Litestar(
        route_handlers=[api],
        dependencies=register_core_providers(),
        exception_handlers=build_core_exception_handlers(CORE_STATUS_ERROR),
        openapi_config=OpenAPIConfig(
            path="/docs",
            title="Trocado",
            version="1.0.0",
            security=[{"BearerToken": []}],
            render_plugins=[ScalarRenderPlugin(version="1.62.0", options={"hiddenClients": True})],
            description=(
                "API da Trocado — finanças pessoais para casais que não dissolvem o indivíduo no "
                "relacionamento. Cada pessoa é dona do próprio dinheiro; o casal é um ponto de vista, "
                "não um dono. Valores em BRL (decimal exato), datas sem horário."
            ),
            components=Components(
                security_schemes={
                    "BearerToken": SecurityScheme(
                        type="http",
                        scheme="bearer",
                        description=(
                            "Token opaco de sessão — obtido via `POST /v1/authentication/sign-in` "
                            "ou `POST /v1/authentication/sign-up`. Envie como "
                            "`Authorization: Bearer <token>` em todos os requests autenticados."
                        ),
                    )
                }
            ),
            tags=[
                Tag(name="Authentication", description="Autenticação — sign-up, sign-in e sign-out."),
                Tag(name="Budgets", description="Orçamentos individuais — criação e, em breve, consulta e edição."),
                Tag(name="Expenses", description="Despesas individuais — registro, listagem, edição e remoção."),
            ],
        ),
    )


app = build()
