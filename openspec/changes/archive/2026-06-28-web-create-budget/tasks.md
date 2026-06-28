## 1. Dependencies & tooling

- [x] 1.1 `uv remove blacksheep`; `uv add litestar "pydantic>=2" uvicorn` (runtime); confirm `uv.lock` updated and `uv sync` clean (Rodi dropped with BlackSheep — Litestar's native DI replaces it)
- [x] 1.2 Run `uv run poe check` to confirm a green baseline once the swap compiles

## 2. HTTP edge — budgeting (driving adapter, `infrastructure/http/`)

- [x] 2.1 `infrastructure/http/requests/create_budget_request.py` → `CreateBudgetRequest` (Pydantic v2: amount, start_date, end_date, optional note) with structural validation only — framework-independent, unchanged by the swap
- [x] 2.2 `infrastructure/http/responses/budget_response.py` → `BudgetResponse` (Pydantic v2: id, amount, start_date, end_date, note, created_at — no `person_id`) — framework-independent, unchanged by the swap
- [x] 2.3 `infrastructure/http/mappers/requests/create_budget_request_mapper.py` → `CreateBudgetRequestMapper.to_data`, `@staticmethod` — fills `person_id` with a **fixed placeholder** for now (the request-identity change replaces it); left as-is
- [x] 2.4 `infrastructure/http/mappers/responses/budget_response_mapper.py` → `BudgetResponseMapper.to_response` (`BudgetData` → `BudgetResponse`), `@staticmethod` — framework-independent, unchanged
- [x] 2.5 `infrastructure/http/controllers/budget_controller.py` → rewritten to a **Litestar-native** `BudgetController(Controller)` with `path` + `@post()`, the `CreateBudgetUseCase` injected **by name** (`NamedDependency`); body bound natively via `data: CreateBudgetRequest`; maps, executes, answers `201 Created` (BlackSheep `Controller`/`Content`/`Response`/explicit `model_validate` dropped)
- [x] 2.6 Confirmed the framework is imported only under `infrastructure/http/` and the composition root; the inner `domain/`/`application/` stay framework-free, and the class carries no lib name

## 3. Composition — a `main/` per module + the composition root, native DI

- [x] 3.1 `core/main/core_factory.py` → contributes the **cross-cutting** gateway providers (clock, identifier provider) as the **app-layer** `dependencies` — app-scoped singletons via Litestar `Provide` (closures over one instance); the only dependencies every feature shares (was Rodi `add_instance`)
- [x] 3.2 `features/budgeting/main/budgeting_factory.py` → returns a `Router` carrying budgeting's controllers **and** its own **feature-scoped** providers (`budget_repository` app-scoped singleton, `create_budget_use_case` per-request), injecting `clock`/`identifier`/`budget_repository` by name through the layered scope — not merged into the app-wide namespace, so feature keys cannot collide (was Rodi `add_instance`/`add_transient`)
- [x] 3.3 `core/infrastructure/http/app.py` (composition root) → builds the Litestar app with app-layer `dependencies = register_core()`; mounts every feature router under a single `/v1` parent router (version prefix owned here, controllers stay version-free → `/v1/budgets`); enables OpenAPI + Swagger (`OpenAPIConfig` + `SwaggerRenderPlugin`) at `/schema`; holds only the cross-cutting layer (does not import a feature's controller); a fresh app per `build()`
- [x] 3.4 `__main__.py`: entrypoint serving the ASGI app via uvicorn — unchanged (ASGI-agnostic)
- [x] 3.5 Smoke covered by the HTTP integration test (`TestClient` builds and drives the real app): well-formed body → 201; malformed body → 4xx before the use case

## 4. Tests (mirroring the source tree)

- [x] 4.1 Unit: `tests/budgeting/infrastructure/http/mappers/` for both mappers (Request→Data, Data→Response) — framework-independent, unchanged
- [x] 4.2 The controller is a framework adapter; its behavior is covered by the HTTP integration test (4.3), exactly as the repository adapter is covered by its own tests — no separate controller unit test
- [x] 4.3 Integration: `tests/budgeting/integrations/test_create_budget_http_integration.py` exercising the real route through the Litestar app (`TestClient`) — 201 happy path, the shared singleton persisting across two requests in one run, and a malformed body rejected before the use case
- [x] 4.4 Async driven through the framework's `TestClient`; the existing use-case integration uses `asyncio.run`; hand-written fakes preferred over mocks
- [x] 4.5 Composition unit tests: `tests/budgeting/main/test_budgeting_factory.py` (the feature is a `Router` carrying only its own scoped deps; a fresh router per build) and `tests/core/main/test_core_factory.py` (the app layer holds only the cross-cutting ports) — cover the feature-scoping guarantee

## 5. Guard & gate

- [x] 5.1 Run `/trocado:guard` (architecture-guard) on the diff — PASS, 0 blockers (framework confined, dependency direction inward, no lib name in class/file, dedicated mappers, test layout correct)
- [x] 5.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) green — 437 passed, 0 warnings
- [x] 5.3 Re-read specs vs implementation: `create-budget` (201 happy path, malformed rejected) and `http-api` (framework confined, layered DI with feature-scoped dependencies + no-collision, shared-singleton persistence, boundary validation, use case runs without the framework) scenarios are each covered by a test

## Deferred to their own changes (out of scope here)

- **Domain-error → HTTP-status mapping** — the framework-independent error→status table + exception handlers (incl. `pydantic.ValidationError` framing; Litestar `ProblemDetailsPlugin` as a candidate substrate). Was sections 2 & 5.2 of the BlackSheep plan.
- **Request identity** — the transitional `X-Person-Id` request-scoped dependency, later real session-token auth. Was task 3.6. Until it lands, the request mapper uses a fixed `person_id` (task 2.3).
