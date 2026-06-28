## Context

The domain and application layers are complete as in-memory vertical slices; every business capability has a
use case, fronted by async ABC ports with in-memory adapters and real gateways. Nothing is reachable over the
network, and there is no composition root — use cases are only ever assembled inside tests. This change picks
the web edge and wires it end to end, proving the whole pattern on one slice (`POST /v1/budgets`) before the
other features follow in their own changes.

This revision **supersedes the original BlackSheep decision with Litestar**, and **narrows the scope** of this
change to the framework foundation: app boot, routing, native DI, and boundary input binding/validation. The
domain-error→HTTP-status mapping and the transitional request identity — neither of which was implemented under
BlackSheep here — are split into their own changes (see *Deferred to their own changes* below).

Hard constraints inherited from the project: async everywhere at I/O boundaries; the dependency rule points
inward (`infrastructure → application → domain`, with `domain` importing nothing outward); the framework lib
must not leak into `domain`/`application`; one concept per file; dedicated mappers at every boundary; exact
decimal money; pt-BR domain errors that never leak sensitive data. The web layer must respect all of these.

## Goals / Non-Goals

**Goals:**
- Stand up the **web foundation**: framework choice, HTTP-adapter shape, composition root, and OpenAPI — once, reusably.
- Expose `POST /v1/budgets` running the existing `CreateBudgetUseCase` over the in-memory repository.
- Keep `domain`/`application` free of the framework; confine it to `infrastructure/http/` + the composition root.
- Bind and validate input at the boundary with Pydantic, rejecting a malformed body before the use case.

**Non-Goals:**
- **Domain-error → HTTP-status mapping** — its own change (see below). Until then, framework defaults apply to errors.
- **Request identity** — its own change. Until then, the request→command mapper uses a fixed placeholder `person_id`.
- **Authentication** — no session-token middleware.
- **Persistence/ORM** — the in-memory repository stays; no data survives a restart.
- The other features' endpoints, and the other budgeting endpoints (update/delete/list/active/default).

## Decisions

### D1 — Framework: Litestar (over BlackSheep / FastAPI)

Litestar is chosen for its **layered, native dependency injection** (`Provide` resolved at app/router/controller/
handler scope, with caching and generator teardown), **class-based controllers**, async-native ASGI runtime,
first-class Pydantic v2 integration, and OpenAPI generation — while bringing a **larger ecosystem and docs** than
BlackSheep. This **reverses the earlier BlackSheep pick**: BlackSheep's edge was its Rodi DI and class
controllers, but Litestar matches the same controller shape *and* its native DI removes the dependency on a
second container (Rodi). FastAPI stays ruled out: its `Depends` is the weakest for an app-level object graph, and
its main edge (AI ecosystem gravity) is neutralized because the AI roadmap (chat, auto-categorization) runs on
framework-agnostic agent libraries (Agno / PydanticAI). The cross-cutting concern that originally tipped the
balance to BlackSheep — error→HTTP framing — is no longer decided here; Litestar additionally offers a native
Problem Details plugin that the forthcoming error-mapping change can build on.

### D2 — Request binding & validation: Pydantic v2, bound natively by Litestar

Request DTOs are **Pydantic v2 models**, which Litestar binds natively from the JSON body (`data: CreateBudgetRequest`)
and documents in OpenAPI using Pydantic's own schema. Structural validation (presence, types, positivity) lives
here; **domain-rule validation stays in the value objects** and is not duplicated. A malformed body is rejected
by Litestar's native validation **before the use case runs**. Unlike the BlackSheep design — which avoided
`FromJSON` and validated explicitly with `model_validate` to dodge an undocumented framework `400` — Litestar's
native binding is used directly; the **canonical status/envelope** for a rejected body is deferred to the
error-mapping change (which may refine the framework default).

### D3 — The web edge is a driving adapter in `infrastructure/http/` — no separate `presentation/` layer

There is **no `presentation/` package**. The documented module shape has exactly three layers —
`domain/` → `application/` → `infrastructure/` — and a web controller is an **inbound (driving) adapter**, the
mirror image of a repository (an outbound adapter). Both live in `infrastructure/`, both legitimately know the
framework lib (`infrastructure/` is "the only place that knows the lib"), and both are fronted by a port the
inner layers own: the repository implements an ABC port; the controller *drives* the use case. The HTTP edge
therefore lives entirely under the feature's `infrastructure/http/`:

```
features/budgeting/infrastructure/http/
  controllers/   budget_controller.py        class BudgetController(Controller): @post()
  requests/      create_budget_request.py    CreateBudgetRequest   (Pydantic v2 model)
  responses/     budget_response.py          BudgetResponse        (Pydantic v2 model)
  mappers/
    requests/    create_budget_request_mapper.py   CreateBudgetRequestMapper.to_data
    responses/   budget_response_mapper.py         BudgetResponseMapper.to_response
```

- **Litestar-native class controllers.** `BudgetController` subclasses Litestar's `Controller`; the resource
  `path` is declared on the class and each operation is a decorated method (`@post()`) with its use case injected
  by name from the controller's `dependencies`. The class name carries no lib name (`BudgetController`, never
  `LitestarBudgetController`), honoring "never the lib's name in the file/class"; the lib stays *inside* the file.
- **Why no framework-free pass-through controller.** An earlier draft kept a pure `presentation/` controller
  (`create(req) -> resp`) in front of the route. It added no rule — `to_data → execute → to_response` — so it
  was ceremony over a boundary that does not move, exactly the "earn its existence / symmetry is not a reason"
  rule the project applies to value objects and mappers. The framework-free, server-free testability guarantee
  lives where it belongs: in the **use case** (`application/`), which is pure and tested with fakes. The
  controller is the adapter that drives it and is covered by the HTTP integration test (Litestar's `TestClient`),
  just as the repository adapter is covered by its own tests.
- **Native body binding.** The handler declares `data: CreateBudgetRequest`; Litestar parses and validates the
  JSON body, then the controller maps it (`CreateBudgetRequestMapper.to_data`), executes the use case, and frames
  the `201 Created` response from the read-model (`BudgetResponseMapper.to_response`).
- **Transitional identity is a fixed placeholder.** `CreateBudgetRequestMapper.to_data` fills `person_id` with a
  hardcoded value, explicitly a placeholder; the request-identity change will introduce the real per-request
  mechanism without touching the controller or use case (they only depend on the resolved identity).
- **Controller granularity = per resource** (`BudgetController` with one method per operation). This mirrors the
  read-model side of `application/data`, which is per-resource, and aligns REST with the codebase: requests/
  request-mappers are per-operation (≈ commands), responses/response-mapper are per-resource (≈ read-models).
- **Mapper naming avoids collision:** the Request→Data mapper is named after the **request** it governs
  (`CreateBudgetRequestMapper`), never `DataMapper` — `application/mappers/BudgetDataMapper` (Entity→Data)
  already owns that name. Methods follow `to_<target>` (`to_data`, `to_response`), `@staticmethod`, one per file.
- **Pydantic DTOs in `infrastructure/http/`.** Request/response models and their mappers sit beside the
  controller in the adapter, not in an inner layer — so the framework-confinement rule is simply "Litestar
  lives in `infrastructure/http/` + the composition root"; the inner `domain/`/`application/` never import it.

### D4 — Composition: layered DI — cross-cutting at the app, each feature scoped to its own `Router`

Litestar's DI is **layered** (app → router → controller → handler, innermost wins), and the composition uses that
deliberately instead of one flat, app-wide bag of dependencies:

- **App layer = cross-cutting only.** `core/main/core_factory.py` contributes the shared-kernel gateways
  (`clock`, `identifier`) as the application-level `dependencies`. These are the only dependencies every feature
  shares, so they — and nothing else — live at the app layer.
- **Each feature = its own scope, via a `Router`.** `features/budgeting/main/budgeting_factory.py` returns a
  `Router` carrying budgeting's controllers **and** its own providers (`budget_repository`,
  `create_budget_use_case`). Those providers live in the **router's scope**, not the app-wide namespace. The
  use-case provider depends on `clock`/`identifier` by name; Litestar resolves them through the layered scope
  (router first, then app). A feature's keys therefore cannot collide with another feature's — even two features
  naming a provider `repository` stay isolated in their own routers.

Why a `Router` and not the literal `Controller.dependencies`: a controller's `dependencies` is a **class
attribute**, fixed at import time, so it cannot hold the per-`build()` singleton instances that test isolation
needs (a class attribute would be shared across every app built in a test run). A `Router` is an **instance**
created fresh inside `register_budgeting()` on each call, so its providers close over that build's own
singletons. The router is the natural per-feature scope boundary; the controller lives inside it.

- **No separate container.** There is no Rodi. Dependencies are Litestar `Provide` providers, resolved by name.
- **App-scoped singletons:** the in-memory repository (it holds the "database" dict — a per-request instance
  would start empty every time) and the cross-cutting gateways. Each is a `Provide` over a single instance built
  once at composition (a closure returning that instance), so every request shares it; a fresh `build()` makes a
  fresh one — hence isolated test apps.
- **Per-request:** the use case, built fresh by its provider each request around the shared singletons (and,
  later, the request identity from D6's change).
- Litestar injects the controller's use case and its ports; nothing self-constructs its dependencies.
- **The composition root holds only the cross-cutting layer** and *collects* each feature's router. It does not
  even import a feature's controller — the feature's router encapsulates that. Adding a feature to the web = one
  builder call here.

```
core/main/                 core_factory.py        contributes the cross-cutting providers (clock, id) — APP layer
features/budgeting/main/    budgeting_factory.py   returns a Router: budgeting's controllers + its SCOPED providers
core/infrastructure/http/   app.py                 build the Litestar app: app-layer deps = register_core(),
                                                   route_handlers = [register_budgeting(), …]
src/trocado/                __main__.py            entrypoint: uvicorn serves the ASGI app
```

> Note: route *declaration* lives in `infrastructure/http/` — the controller's `path` + decorated methods. The
> composition root does the *assembly*: app-layer `dependencies` from `register_core()`, and each feature's
> `Router` (handlers + scoped `dependencies`) as a `route_handler`. Both may import the framework; inner layers
> never do. Each build produces a **fresh Litestar app instance** with its own singletons, so tests can call the
> builder per scenario with isolated state.

### D5 — (deferred) Error → HTTP mapping — its own change

The explicit, framework-independent domain-error→HTTP-status table and its exception handlers (incl. framing
`pydantic.ValidationError`) are **split out of this change** into their own OpenSpec change. Litestar's
`ProblemDetailsPlugin` is a candidate substrate for that change. Until it lands, errors from the use case and a
malformed body surface via Litestar's framework defaults. This keeps the present change scoped to *what the
framework does*.

### D6 — (deferred) Transitional identity — its own change

The per-request `X-Person-Id` mechanism (and its eventual replacement by real session-token auth) is **split out
into its own change**. Until then, `CreateBudgetRequestMapper.to_data` uses a **fixed placeholder `person_id`**.
When the identity change lands it introduces the request-scoped dependency and the mapper takes the resolved
identity as an argument — **no controller or use case changes**, because they only depend on the injected identity.

### D7 — API version prefix (`/v1`) and OpenAPI/Swagger at the composition root

All feature routers are mounted under a single `/v1` parent router built at the composition root, so every route
is versioned (`/v1/budgets`) without any controller naming the version — versioning is a cross-cutting transport
concern, and a new version is a new parent scope here, not an edit across controllers. OpenAPI is enabled
explicitly via `OpenAPIConfig` (title `Trocado`, version `1.0.0`) served at `/schema`, with the **Swagger UI** at
`/schema/swagger` and the raw document at `/schema/openapi.json`; adding Redoc/Scalar is one more render plugin.
This resolves the earlier open question (enable docs now — it is nearly free with Litestar).

## Risks / Trade-offs

- **[Framework swap from BlackSheep]** → Cheap precisely because the framework was confined to
  `infrastructure/http/` + the composition root: only the controller adapter, its DTO binding, and the app
  assembly change. The use cases, ports, domain, request/response DTOs, and mappers are untouched — they never
  knew the framework. Dropping Rodi simplifies the dependency graph.
- **[No error framing yet]** → Accepted and explicit: domain errors and malformed bodies fall back to Litestar
  defaults until the error-mapping change lands. This slice is not deployed publicly.
- **[`person_id` is a fixed placeholder — every budget is created for the same id]** → Acceptable only because
  this slice is not deployed publicly; isolated in one mapper and removed by the request-identity change. Flagged
  loudly in code.
- **[In-memory store loses data on restart]** → Expected for the transitional stage; the ORM change replaces the
  adapter behind the unchanged port.
- **[New deps (`litestar`, `pydantic`, `uvicorn`) widen the surface]** → All enter at the edge only; inner
  layers stay pure, enforced by D1/D3 and checkable with the architecture guard.

## Open Questions

- **Canonical 4xx envelope** — deferred to the error-mapping change (likely Problem Details via Litestar's plugin).
