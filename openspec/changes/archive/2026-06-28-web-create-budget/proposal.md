## Why

The domain and application layers are complete as in-memory vertical slices, but nothing is reachable over the network — the system is not yet an application, only a library of use cases. We need to choose and wire the web edge so the use cases can be exercised end to end. Rather than expose everything at once, this change establishes the **web foundation** (framework, composition root, HTTP-adapter conventions) and proves it with a **single vertical slice — `POST /v1/budgets`** — so the pattern is validated on a minimal surface before the other features follow in their own changes.

This proposal supersedes the framework decision: **Litestar replaces BlackSheep**. The two cross-cutting concerns that had not yet been implemented here — the domain-error→HTTP-status mapping and the transitional request identity — are **carved out into their own changes**, so this one stays scoped to exactly *what the framework does*: boot the app, route, bind/validate input, and inject dependencies.

## What Changes

- **Adopt Litestar** as the web framework (async-native ASGI, layered dependency injection, class-based controllers, OpenAPI from Pydantic v2). It enters only at the edge, behind the existing ports. This **replaces the earlier BlackSheep choice** and drops the Rodi container that came with it.
- **Dependency injection via Litestar's native DI** (`Provide` + layered `dependencies`), not a separate container. Each module's `main/` factory contributes the `Provide` mapping for its own object graph; the composition root assembles them into the app. Injection is by name into the handler, replacing the BlackSheep/Rodi constructor injection.
- **Build the HTTP edge as a driving adapter** under a feature's `infrastructure/http/` — a Litestar-native class controller plus the request/response DTOs and their Request→Data / Data→Response mappers, following one-concept-per-file. There is **no separate `presentation/` layer**: a controller is an inbound adapter (the mirror of a repository), so it lives in `infrastructure/`. Validation of input shape lives in the request DTOs (Pydantic), bound natively by Litestar; domain-rule validation stays in the value objects.
- **Composition by module**: each module owns a `main/` package at its root that knows how to build itself (contribute its providers and route handlers) — `core/main/` for the shared-kernel gateways, `features/budgeting/main/` for budgeting's repo/use-case/controller. A thin top-level composition root assembles the Litestar app from these builders and owns only the cross-module wiring (the app, the entrypoint).
- **Confine the framework lib** to `infrastructure/http/` (controller, DTOs, parsing) and the composition root (app assembly). The inner `domain/` and `application/` layers never import it; the framework-free, server-free testable unit is the **use case**.
- **Expose `POST /v1/budgets`** wiring the existing `CreateBudgetUseCase` end to end over HTTP, running on the in-memory repository (no persistence between restarts — acceptable for this slice). A malformed body is rejected at the boundary by Litestar's native validation before the use case runs.
- **Transitional identity stays a fixed placeholder.** Since both real auth and the request-identity mechanism are deferred to their own change, the request→command mapper resolves the acting person to a **hardcoded `person_id`** for now, explicitly a placeholder. **No real authorization yet.**

## Capabilities

### New Capabilities
- `http-api`: The cross-cutting HTTP runtime and web-edge conventions — Litestar app assembly, the composition root using Litestar's native DI and its dependency lifetimes (app-scoped singleton vs per-request), the HTTP-adapter shape under `infrastructure/http/` (native class controller + requests/responses/mappers, no separate `presentation/` layer), and Pydantic-based boundary input validation that rejects a malformed body before the use case.

### Modified Capabilities
- `create-budget`: add the requirement that the existing create-budget behavior is reachable over HTTP as `POST /v1/budgets`, with a Pydantic-validated request body and a created-budget response.

## Impact

- **New runtime dependencies:** `litestar`, `pydantic` (v2), an ASGI server (`uvicorn`). Added via `uv add`. **Removed:** `blacksheep` (and with it the transitive Rodi DI container).
- **New packages:** `features/budgeting/infrastructure/http/` (native class controller + requests, responses, mappers); a `main/` package per module that self-constructs (`core/main/`, `features/budgeting/main/`); a thin top-level composition root (cross-module app assembly + entrypoint).
- **No changes to `domain/` or `application/`** — the web edge slots behind the existing ports. The in-memory `BudgetRepository` is reused as an app-scoped singleton.
- **Not in scope (own future changes):**
  - **Domain-error → HTTP-status mapping** — the explicit, framework-independent error→status table and the exception handlers (incl. `pydantic.ValidationError` framing). Its own change.
  - **Request identity** — the transitional `X-Person-Id` request-scoped dependency, later replaced by real session-token auth. Its own change; until then the mapper uses a fixed `person_id`.
  - Authentication middleware, the ORM/persistence, and the remaining features' endpoints.
