from __future__ import annotations

from litestar import Litestar, Router
from litestar.openapi import OpenAPIConfig
from litestar.openapi.plugins import SwaggerRenderPlugin
from litestar.openapi.spec import Tag

from trocado.core.main.core_factory import register_core
from trocado.features.budgeting.main.budgeting_factory import register_budgeting


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

    OpenAPI is served at ``/schema`` with the **Swagger UI** at ``/schema/swagger`` (raw doc at
    ``/schema/openapi.json``). Adding Redoc/Scalar/etc. is one more render plugin in this list.

    As the composition root it is the **one place allowed to know every module** (it calls each feature's
    builder); the rest of ``core`` must never reach into a feature, and here it does not even import a feature's
    controller — the feature's router encapsulates that. Each call returns a **fresh app** with its own
    singletons, so a test can build an isolated instance per scenario. Deliberately the **bare bootstrap**: it
    brings the happy path online and nothing more — the error→HTTP framing and the transitional request
    identity are left to their own changes, not wired here.
    """
    api = Router(path="/v1", route_handlers=[register_budgeting()])

    return Litestar(
        route_handlers=[api],
        dependencies=register_core(),
        openapi_config=OpenAPIConfig(
            path="/schema",
            title="Trocado",
            version="1.0.0",
            render_plugins=[SwaggerRenderPlugin()],
            description=(
                "API da Trocado — finanças pessoais para casais que não dissolvem o indivíduo no "
                "relacionamento. Cada pessoa é dona do próprio dinheiro; o casal é um ponto de vista, "
                "não um dono. Valores em BRL (decimal exato), datas sem horário."
            ),
            tags=[Tag(name="Budgets", description="Orçamentos individuais — criação e, em breve, consulta e edição.")],
        ),
    )


app = build()
