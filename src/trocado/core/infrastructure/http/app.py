from __future__ import annotations

from blacksheep import Application
from rodi import Container

from trocado.core.main.core_factory import register_core
from trocado.features.budgeting.main.budgeting_factory import register_budgeting


def build() -> Application:
    """Assemble the BlackSheep application — the composition root.

    Builds the Rodi container, lets each module wire its own object graph (core first, then each feature),
    and hands the container to BlackSheep. Routes self-register: importing ``BudgetController`` — which
    ``register_budgeting`` does to wire its DI — runs the ``@post`` decorator that binds the route. This
    root only does the assembly.

    As the composition root it is the **one place allowed to know every module** (it imports each feature's
    builder to wire it); the rest of ``core`` must never reach into a feature. Deliberately the **bare
    bootstrap**: it brings the happy path online and nothing more. Error→HTTP framing (the exception
    handlers / status table) and the transitional ``X-Person-Id`` identity are left to their own tasks of
    this change — not wired here.
    """
    container = Container()
    register_core(container)
    register_budgeting(container)

    return Application(services=container)


app = build()
