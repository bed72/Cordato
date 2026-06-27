## 1. Dependencies & tooling

- [ ] 1.1 `uv add blacksheep "pydantic>=2.2.0" uvicorn` (runtime); confirm `uv.lock` updated and `uv sync` clean
- [ ] 1.2 Run `uv run poe check` on the untouched tree to confirm a green baseline before changes

## 2. Shared error → HTTP mapping (core)

- [ ] 2.1 Add a framework-independent error→status table in `core/` mapping domain-error type → HTTP status (D5), holding no framework types; seed the budgeting subset (`InvalidBudgetRangeError`, `InvalidBudgetAmountError`, `InvalidAmountError`, `InvalidMoneyError` → 422; `OverlappingBudgetError` → 409; `BudgetNotFoundError` → 404; `PersonNotActiveError` → 403)
- [ ] 2.2 Add the `pydantic.ValidationError → 422` entry and a generic "missing transitional identity → 400" entry
- [ ] 2.3 Ensure the table conveys the domain's generic pt-BR message and leaks no sensitive value

## 3. HTTP edge — budgeting (driving adapter, `infrastructure/http/`)

- [x] 3.1 `infrastructure/http/requests/create_budget_request.py` → `CreateBudgetRequest` (Pydantic v2: amount, start_date, end_date, optional note) with structural validation only
- [x] 3.2 `infrastructure/http/responses/budget_response.py` → `BudgetResponse` (Pydantic v2: id, amount, start_date, end_date, note, created_at — no `person_id`: the response carries the budget only, the caller already knows who they are)
- [x] 3.3 `infrastructure/http/mappers/create_budget_request_mapper.py` → `CreateBudgetRequestMapper.to_data` (Request + acting person → `CreateBudgetData`), `@staticmethod`
- [x] 3.4 `infrastructure/http/mappers/budget_response_mapper.py` → `BudgetResponseMapper.to_response` (`BudgetData` → `BudgetResponse`), `@staticmethod`
- [x] 3.5 `infrastructure/http/controllers/budget_controller.py` → BlackSheep-native `BudgetController(Controller)` with `@post("/budgets")`, the `CreateBudgetUseCase` injected via the constructor (Rodi); reads the body and validates it explicitly with `model_validate` (not `FromJSON`) so a malformed body raises `pydantic.ValidationError` → 422, resolves the acting person, maps, executes, and answers `201 Created`
- [ ] 3.6 Request-scoped transitional identity: read `X-Person-Id` header → acting person id; absent → `MissingIdentityError` (→ 400 via the table, D6), clearly marked a placeholder for the auth change
- [x] 3.7 Confirm BlackSheep is imported only under `infrastructure/http/` and `main/`; the inner `domain/`/`application/` stay framework-free

## 5. Composition — a `main/` per module + a thin top-level `main/`

- [x] 5.1 Each module owns its builder under its own `main/`: `core/main/core_factory.py` (`register_core`) registers the cross-cutting gateways (clock, identifier provider) as app-scoped singletons — once; `features/budgeting/main/budgeting_factory.py` (`register_budgeting`) registers the in-memory `BudgetRepository` (app-scoped singleton) and `CreateBudgetUseCase` + `BudgetController` (transient) — its own object graph only, never the core ports
- [x] 5.2 `main/http/app.py` (thin top-level root): build the BlackSheep app, call each module's builder (`register_core`, then `register_budgeting`), and register the error→HTTP exception handlers (incl. `ValidationError → 422`); controllers self-register via their route decorators
- [x] 5.3 `main/__main__.py`: entrypoint serving the ASGI app via uvicorn
- [ ] 5.4 Manual smoke: start the app, `POST /budgets` with `X-Person-Id` → 201; malformed body → 422; overlapping → 409; missing header → 400

## 6. Tests (mirroring the source tree)

- [x] 6.1 Unit: `tests/budgeting/infrastructure/http/mappers/` for both mappers (Request→Data, Data→Response)
- [x] 6.2 The controller is a framework adapter (no standalone framework-free controller); its behavior is covered by the HTTP integration test (6.4), exactly as the repository adapter is covered by its own tests — no separate controller unit test or use-case fake needed
- [ ] 6.3 Unit: `tests/<core>/` for the error→HTTP mapping table (each entry → expected status; mapping is total over known domain errors)
- [ ] 6.4 Integration: `tests/budgeting/integrations/` exercising the real route through the app — 201 happy path (and the store persists across two requests in one run), 422 malformed, 409 overlapping, 400 missing identity header
- [ ] 6.5 Drive async with `asyncio.run`; hand-written fakes preferred over mocks

## 7. Guard & gate

- [ ] 7.1 Run `/trocado:guard` (architecture-guard) on the diff — confirm framework confinement, dependency direction, naming, dedicated mappers, one-concept-per-file, pt-BR non-leaking errors, test layout
- [ ] 7.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) green
- [ ] 7.3 Re-read specs vs implementation: every scenario in `http-api` and `create-budget` deltas has a covering test
