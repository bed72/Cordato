## Why

The domain and application layers are complete as in-memory vertical slices, but nothing is reachable over the network — the system is not yet an application, only a library of use cases. We need to choose and wire the web edge so the use cases can be exercised end to end. Rather than expose everything at once, this change establishes the **entire web foundation** (framework, composition root, error mapping, HTTP-adapter conventions) and proves it with a **single vertical slice — `POST /budgets`** — so the pattern is validated on a minimal surface before the other features follow in their own changes.

## What Changes

- **Adopt BlackSheep** as the web framework (async-native, Rodi DI, class-based controllers, OpenAPI from Pydantic v2). It enters only at the edge, behind the existing ports.
- **Build the HTTP edge as a driving adapter** under a feature's `infrastructure/http/` — a BlackSheep-native class controller plus the request/response DTOs and their Request→Data / Data→Response mappers, following one-concept-per-file. There is **no separate `presentation/` layer**: a controller is an inbound adapter (the mirror of a repository), so it lives in `infrastructure/`. Validation of input shape lives in the request DTOs (Pydantic); domain-rule validation stays in the value objects.
- **Introduce composition by module**: each module owns a `main/` package at its root that knows how to build itself (register its own object graph into Rodi) — `core/main/` for the shared-kernel gateways, `features/budgeting/main/` for budgeting's repo/use-case/controller. A thin top-level `main/` orchestrates these builders and owns only the cross-module concerns (the BlackSheep app, the aggregate error→status table, the entrypoint). Controllers self-register via their route decorators.
- **Confine the framework lib** to `infrastructure/http/` (controller, DTOs, parsing) and `main/` (app assembly). The inner `domain/` and `application/` layers never import it; the framework-free, server-free testable unit is the **use case**.
- **Add the domain-error → HTTP-status mapping** as an explicit, framework-independent table, registered as exception handlers — including `pydantic.ValidationError → 422` with the error detail. This is how 4xx framing is owned, not left to framework defaults.
- **Expose `POST /budgets`** wiring the existing `CreateBudgetUseCase` end to end over HTTP, running on the in-memory repository (no persistence between restarts — acceptable for this slice).
- **Transitional identity:** since the auth middleware is deferred to its own change, the endpoint resolves the acting person from a temporary `X-Person-Id` request header, explicitly marked as a placeholder the auth change will replace. **No real authorization yet.**

## Capabilities

### New Capabilities
- `http-api`: The cross-cutting HTTP runtime and web-edge conventions — BlackSheep app assembly, the Rodi composition root and its dependency lifetimes (singleton vs request-scoped), the HTTP-adapter shape under `infrastructure/http/` (native class controller + requests/responses/mappers, no separate `presentation/` layer), the domain-error→HTTP-status mapping (incl. Pydantic `ValidationError`→422), and the transitional request-scoped person identity pending real authentication.

### Modified Capabilities
- `create-budget`: add the requirement that the existing create-budget behavior is reachable over HTTP as `POST /budgets`, with a Pydantic-validated request body, a created-budget response, and the standard error framing.

## Impact

- **New runtime dependencies:** `blacksheep`, `pydantic` (v2 ≥ 2.2.0), an ASGI server (`uvicorn`). Added via `uv add`.
- **New packages:** `features/budgeting/infrastructure/http/` (native class controller + requests, responses, mappers); a `main/` package per module that self-constructs (`core/main/`, `features/budgeting/main/`); a thin top-level `main/` (cross-module app assembly + entrypoint); a shared error→HTTP mapping under `core/infrastructure/http/`.
- **No changes to `domain/` or `application/`** — the web edge slots behind the existing ports. The in-memory `BudgetRepository` is reused as an app-scoped singleton.
- **Not in scope (own future changes):** authentication middleware (server-side session token → person), the ORM/persistence, and the remaining features' endpoints.
