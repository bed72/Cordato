from __future__ import annotations

from litestar import Litestar, Router
from litestar.openapi import OpenAPIConfig
from litestar.openapi.plugins import ScalarRenderPlugin
from litestar.openapi.spec import Components, SecurityScheme, Tag

from trocado.core.infrastructure.http.errors.handlers.exception_handlers import build_core_exception_handlers
from trocado.core.main.core_provider import register_core_providers
from trocado.features.budgeting.main.budgeting_route import register_budgeting_router
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
    """
    api = Router(
        path="/v1",
        dependencies=register_identity_providers(),
        route_handlers=[register_identity_router(), register_budgeting_router()],
    )

    return Litestar(
        route_handlers=[api],
        dependencies=register_core_providers(),
        exception_handlers=build_core_exception_handlers(),
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
            ],
        ),
    )


app = build()
