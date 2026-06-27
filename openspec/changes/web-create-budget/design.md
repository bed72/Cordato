## Context

The domain and application layers are complete as in-memory vertical slices; every business capability has a
use case, fronted by async ABC ports with in-memory adapters and real gateways. Nothing is reachable over the
network, and there is no composition root — use cases are only ever assembled inside tests. This change picks
the web edge and wires it end to end, proving the whole pattern on one slice (`POST /budgets`) before the
other features follow in their own changes.

Hard constraints inherited from the project: async everywhere at I/O boundaries; the dependency rule points
inward (`infrastructure → application → domain`, with `domain` importing nothing outward); the framework lib
must not leak into `domain`/`application`; one concept per file; dedicated mappers at every boundary; exact
decimal money; pt-BR domain errors that never leak sensitive data. The web layer must respect all of these.

## Goals / Non-Goals

**Goals:**
- Stand up the **whole web foundation**: framework choice, presentation layer, composition root, error→HTTP
  mapping, and OpenAPI — once, reusably.
- Expose `POST /budgets` running the existing `CreateBudgetUseCase` over the in-memory repository.
- Keep `domain`/`application`/`presentation` free of the framework; confine it to `infrastructure/http/` + `main/`.
- Own the 4xx framing explicitly (incl. `ValidationError → 422`), not by framework default.

**Non-Goals:**
- **Authentication** — no session-token middleware yet; identity is a transitional `X-Person-Id` header.
- **Persistence/ORM** — the in-memory repository stays; no data survives a restart.
- The other features' endpoints, and the other budgeting endpoints (update/delete/list/active/default).
- Real authorization beyond "the request names a person".

## Decisions

### D1 — Framework: BlackSheep (over FastAPI / Litestar)

BlackSheep is chosen for its **first-class DI (Rodi)** and **native class-based controllers**, which match the
desired shape, plus async-native runtime, OpenAPI generation, and top-tier performance. FastAPI was ruled out:
its `Depends` is the weakest for an app-level object graph, and its main edge (AI ecosystem gravity) is
neutralized because the AI roadmap (chat, auto-categorization) runs on framework-agnostic agent libraries
(Agno / PydanticAI). Litestar was the runner-up (larger ecosystem, layered DI) and remains a fallback; it lost
on DI ergonomics and controller-class fit. Accepted trade-off: BlackSheep's **smaller ecosystem/docs** — taken
knowingly, since the AI work lives outside the web framework and DI is the deciding factor.

### D2 — Request validation: Pydantic v2, with an explicit `ValidationError → 422` handler

Request DTOs are **Pydantic v2 models** (`pydantic ≥ 2.2.0`), which BlackSheep binds via `FromJSON[...]` and
documents in OpenAPI using Pydantic's own schema. Structural validation (presence, types, positivity) lives
here; **domain-rule validation stays in the value objects** and is not duplicated. BlackSheep's default status
for an invalid body is **not documented as 422**, so we do not rely on it: a **global exception handler maps
`pydantic.ValidationError → 422`** with `errors()` detail. This is simply the first row of the error→HTTP table
(D5) and gives full control over the 422 shape.

### D3 — The web edge is a driving adapter in `infrastructure/http/` — no separate `presentation/` layer

There is **no `presentation/` package**. The documented module shape has exactly three layers —
`domain/` → `application/` → `infrastructure/` — and a web controller is an **inbound (driving) adapter**, the
mirror image of a repository (an outbound adapter). Both live in `infrastructure/`, both legitimately know the
framework lib (`infrastructure/` is "the only place that knows the lib"), and both are fronted by a port the
inner layers own: the repository implements an ABC port; the controller *drives* the use case. The HTTP edge
therefore lives entirely under the feature's `infrastructure/http/`:

```
features/budgeting/infrastructure/http/
  controllers/   budget_controller.py        class BudgetController(Controller): @post("/budgets")
  requests/      create_budget_request.py    CreateBudgetRequest   (Pydantic v2 model)
  responses/     budget_response.py          BudgetResponse        (Pydantic v2 model)
  mappers/       create_budget_request_mapper.py  CreateBudgetRequestMapper.to_data
                 budget_response_mapper.py        BudgetResponseMapper.to_response
```

- **BlackSheep-native class controllers.** `BudgetController` subclasses BlackSheep's `Controller`; each
  operation is a decorated method (`@post("/budgets")`) with the use case injected by Rodi through the
  constructor. This is the framework's idiom and the reason BlackSheep was chosen (D1) — class controllers with
  first-class DI. The class name carries no lib name (`BudgetController`, never `BlackSheepBudgetController`),
  honoring "never the lib's name in the file/class"; the lib stays *inside* the file.
- **Why no framework-free pass-through controller.** An earlier draft kept a pure `presentation/` controller
  (`create(req) -> resp`) in front of the route. It added no rule — `to_data → execute → to_response` — so it
  was ceremony over a boundary that does not move, exactly the "earn its existence / symmetry is not a reason"
  rule the project applies to value objects and mappers. The framework-free, server-free testability guarantee
  lives where it belongs: in the **use case** (`application/`), which is pure and tested with fakes. The
  controller is the adapter that drives it and is covered by the HTTP integration test (TestClient), just as the
  repository adapter is covered by its own tests.
- **Explicit body validation (not `FromJSON`).** The controller reads the raw JSON and calls
  `CreateBudgetRequest.model_validate(payload)` itself, rather than binding via BlackSheep's `FromJSON[...]`.
  This is deliberate: `FromJSON` swallows a malformed body into the framework's own `400 Bad Request`, whereas
  the explicit `model_validate` raises `pydantic.ValidationError`, which our exception handler frames as **422**
  with field detail (D2/D5). We own the 4xx framing, not the framework.
- **Controller granularity = per resource** (`BudgetController` with one method per operation). This mirrors the
  read-model side of `application/data`, which is per-resource, and aligns REST with the codebase: requests/
  request-mappers are per-operation (≈ commands), responses/response-mapper are per-resource (≈ read-models).
- **Mapper naming avoids collision:** the Request→Data mapper is named after the **request** it governs
  (`CreateBudgetRequestMapper`), never `DataMapper` — `application/mappers/BudgetDataMapper` (Entity→Data)
  already owns that name. Methods follow `to_<target>` (`to_data`, `to_response`), `@staticmethod`, one per file.
- **Pydantic DTOs in `infrastructure/http/`.** Request/response models and their mappers sit beside the
  controller in the adapter, not in an inner layer — so the framework-confinement rule is simply "BlackSheep
  lives in `infrastructure/http/` + `main/`"; the inner `domain/`/`application/` never import it.

### D4 — Composition: a `main/` package **per module**, orchestrated by a thin top-level `main/`

Each module owns its own composition: a `main/` package at the **module root** (sibling to its `domain/`,
`application/`, `infrastructure/`) that knows how to **build itself** — registering its own object graph into the
Rodi container. The top-level `main/` (sibling to `core/` and `features/`) does **not** reach into a module's
internals; it is the thin application root that *orchestrates* each module's builder and owns only the genuinely
**cross-module** concerns (the BlackSheep app, the aggregate error→status table, the uvicorn entrypoint). DI and
the framework still live only at this edge — the per-module `main/` and the top-level `main/`, plus
`infrastructure/http/`; the inner layers never import either.

- **Each module self-constructs.** `core/main/core_factory.py` (`register_core`) registers the shared-kernel
  gateways; `features/budgeting/main/budgeting_factory.py` (`register_budgeting`) registers budgeting's own
  repository, use case, and controller. A feature's builder registers **only its own** graph and never the core
  ports — so there is no duplicate/competing registration as more features are wired.
- **App-scoped singletons:** the in-memory repositories (they hold the "database" dict — a per-request instance
  would start empty every time) and the stateless cross-cutting gateways (clock, identifier provider).
- **Request-scoped:** the acting-person identity (D6) and the use cases assembled around it.
- Rodi resolves the controller's use case by injecting its ports; nothing self-constructs its dependencies.
- **Order at the root.** The top-level `build_app` calls `register_core` first (shared kernel, once), then each
  feature's builder (`register_budgeting`, …). Adding a feature to the web = one import + one builder call here.

```
core/main/                 core_factory.py        core knows how to register its own gateways (clock, id) — once
features/budgeting/main/    budgeting_factory.py   budgeting knows how to register its own repo/use-case/controller
main/                       the thin application root — cross-module only
  http/                     app.py                 build the BlackSheep app, call each module's builder, register handlers
                            error_status_table.py  aggregate every feature's error→status entries (the one place that may know all)
                            exception_handlers.py
  __main__.py                                      entrypoint: uvicorn serves the ASGI app
```

> Note: route *binding* lives in `infrastructure/http/` — the `@post`-decorated controller methods self-register
> into BlackSheep's controllers registry when the controller module is imported (the budgeting factory imports
> and registers `BudgetController` in the container, which both wires its DI and triggers the decorator). `main/`
> does the *assembly* (build container, build app, register exception handlers). Both may import the framework;
> inner layers never do. Each build gets a **fresh per-app `Router()`** (not BlackSheep's shared module-global
> default), and its `controllers_routes` is pointed at the global controllers registry. This is required for
> isolated rebuilds: BlackSheep's default router is a module-global singleton whose route objects and per-app
> handler bindings would otherwise bleed across apps (and its `_registered_routes` are consumed on first start),
> breaking the tests that call `build_app()` per scenario. The global controllers registry holds only the
> constant route *definitions* — read, never consumed during setup — so every build binds the same declarations
> against its own container.

### D5 — Error → HTTP mapping: explicit, framework-independent table

A single mapping from domain-error type to HTTP status, registered as BlackSheep exception handlers. It is a
plain table (no framework types in the table itself), so it is unit-testable and reusable by future features.
For this slice:

| Error | Status |
|---|---|
| `pydantic.ValidationError` | 422 |
| `InvalidBudgetRangeError`, `InvalidBudgetAmountError`, `InvalidAmountError`, `InvalidMoneyError` | 422 |
| `OverlappingBudgetError` | 409 |
| `BudgetNotFoundError` | 404 |
| `PersonNotActiveError` | 403 |
| missing `X-Person-Id` (transitional) | 400 |

Responses carry the domain's generic pt-BR message; nothing sensitive is echoed. The mapping is **total** for
known domain errors — none should fall through to an unhandled 500. The full ~22-error table is built
incrementally as each feature's endpoints land; this change seeds it in `core/` and registers the budgeting
subset.

### D6 — Transitional identity: `X-Person-Id` header

The endpoint needs a `person_id`, but auth is a separate change. A request-scoped dependency reads the
`X-Person-Id` header and provides the acting person id; absence → 400. It is clearly marked a placeholder. The
auth change will swap this single dependency for one that validates a session token via `ValidateSessionUseCase`
and yields the authenticated person — **no controller or use case changes** when that happens, because they only
depend on the injected identity.

## Risks / Trade-offs

- **[BlackSheep's small ecosystem]** → Accepted deliberately; DI is the deciding factor and AI lives outside the
  framework. A future swap (e.g. to Litestar) stays cheap because the framework is confined to
  `infrastructure/http/` + `main/`: only the controller adapter, its DTOs/mappers, and the assembly would change.
  The use cases, ports, domain, and the error→status table (a plain, framework-free table) are untouched — they
  never knew the framework. The swap cost is the same as it would have been with a separate framework-free
  controller, without the redundant pass-through layer.
- **[`X-Person-Id` is unauthenticated — anyone can act as anyone]** → Acceptable only because this slice is not
  deployed publicly; isolated behind one request-scoped dependency and removed by the very next change. Flagged
  loudly in code.
- **[In-memory store loses data on restart]** → Expected for the transitional stage; the ORM change replaces the
  adapter behind the unchanged port.
- **[Relying on a framework default for 422]** → Avoided by D2's explicit handler; we own the status and shape.
- **[New deps (`blacksheep`, `pydantic`, `uvicorn`) widen the surface]** → All enter at the edge only; inner
  layers stay pure, enforced by D1/D3 and checkable with the architecture guard.

## Open Questions

- **Pydantic DTOs in `infrastructure/http/`** — Pydantic is a validation lib, not the web framework, and the
  request/response models live in the adapter (`infrastructure/http/`) anyway, so framework confinement is not at
  stake. Resolved: keep Pydantic v2 models for the free OpenAPI schema.
- **BlackSheep default status for an invalid body** — *confirmed from source*: binding via `FromJSON[...]` answers
  the framework's own `400 Bad Request` ("Missing/invalid body payload"), never surfacing `pydantic.ValidationError`.
  This is exactly why the controller validates explicitly with `model_validate` (D3) so our handler owns the 422.
- **OpenAPI route for docs** (`/docs`/`/openapi.json`) — enable now or in a follow-up? Leaning: enable now, it is
  nearly free with BlackSheep.
