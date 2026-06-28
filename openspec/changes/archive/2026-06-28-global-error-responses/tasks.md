## 1. Error → status table (pure, framework-independent) + helpers

- [x] 1.1 `core/infrastructure/http/errors/lookups/core_status_error.py` → core-generic domain-error→status entries as a pure
  `dict[type[Exception], int]` (`InvalidMoneyError → 422`). No framework import.
- [x] 1.2 `features/budgeting/infrastructure/http/errors/lookups/budgeting_status_error.py` → budgeting's pure map: `InvalidBudgetAmountError
  → 422`, `InvalidBudgetRangeError → 422`, `OverlappingBudgetError → 409`, `BudgetNotFoundError → 404`. No
  framework import.
- [x] 1.3 `core/infrastructure/http/errors/lookups/error_code.py` → pure `error_code(error_type) -> str` (class name → kebab,
  drop the `Error`/`Exception` suffix, e.g. `OverlappingBudgetError → overlapping-budget`, `NotFoundException →
  not-found`).

## 2. Unified envelope + exception handlers (the only framework-aware piece)

- [x] 2.1 `core/infrastructure/http/errors/responses/error_detail_response.py` → `ErrorDetailResponse` (Pydantic: `key`, `message`); and
  `core/infrastructure/http/errors/responses/error_response.py` → `ErrorResponse` (Pydantic: `status`, `code`, `message`,
  `errors: list[ErrorDetailResponse] | None = None` — **optional**, omitted when absent via `model_dump(exclude_none=True)`).
- [x] 2.2 `core/infrastructure/http/errors/validations/messages_validation.py` → pure `validation_message(type) -> str` mapping
  Pydantic error codes (`missing`, `decimal_type`, `date_parsing`, …) to pt-BR, with a generic fallback; and
  `core/infrastructure/http/errors/http/messages_http.py` → pure `http_message(status) -> str` mapping framework
  HTTP statuses (400/404/405/…) to pt-BR, with a generic fallback.
- [x] 2.3 `core/infrastructure/http/errors/handlers/exception_handlers.py` → two builders: `build_domain_exception_handlers(status_error)`
  (per `(ErrType, status)` a handler framing `ErrorResponse(status, code=error_code(ErrType), message=str(exc))`,
  no `errors` — registered on the feature router) and `build_core_exception_handlers()` (cross-cutting, app-level):
  a `ValidationException` handler → `422`, `code="validation"`, reading the structured underlying errors
  (`exc.__cause__`, Pydantic method or msgspec list) and translating each `type` to pt-BR via `validation_message`;
  plus an `HTTPException` base handler framing framework HTTP errors with `code`+`message` derived from the HTTP
  status (`http_message`), never the framework's English detail.
- [x] 2.4 Confirm the envelope conveys only the domain's generic pt-BR message and leaks no sensitive value
  (`BudgetNotFoundError` stays generic); validation field messages are pt-BR, never Pydantic's raw English.

## 3. Wiring (layered, like the DI)

- [x] 3.1 `features/budgeting/main/budgeting_factory.py` → the budgeting `Router` carries its own
  `exception_handlers = build_domain_exception_handlers({**CORE_STATUS_ERROR, **BUDGETING_STATUS_ERROR})`
  (scoped per route-module), alongside its scoped DI providers.
- [x] 3.2 `core/infrastructure/http/app.py` → registers only the cross-cutting `build_core_exception_handlers()`
  at the app layer; it does not import any feature's error map. Litestar resolves the most specific across layers.

## 4. Dev entrypoint fix (infra)

- [x] 4.1 `src/trocado/__main__.py` → `uvicorn.run("trocado.core.infrastructure.http.app:app", host="127.0.0.1",
  port=8000, reload=True, log_level="debug")` so `python -m trocado` actually hot-reloads (uvicorn needs an import
  string for reload).

## 5. Tests (mirroring the source tree)

- [x] 5.1 Pure unit: `tests/core/infrastructure/http/errors/lookups/test_error_code.py` (domain + framework error types →
  expected code), `tests/core/infrastructure/http/errors/validations/test_messages_validation.py` (known type → pt-BR, fallback),
  `tests/core/infrastructure/http/errors/http/test_messages_http.py` (known status → pt-BR, fallback), and
  `tests/budgeting/infrastructure/http/errors/lookups/test_budgeting_status_error.py` (each entry → expected status; totality over the
  reachable errors). No server.
- [x] 5.2 Integration (Litestar `TestClient`): extend `tests/budgeting/integrations/test_create_budget_http_integration.py`
  — overlap → `409` with `code="overlapping-budget"` and **no** `errors` key; malformed body (`amount: true`) →
  `422` with `code="validation"` and a pt-BR `errors` entry keyed `amount` (`"Deve ser um número decimal."`);
  malformed JSON (`"amount": ,`) → `400`, `code="bad-request"`, pt-BR message, no `errors`.
- [x] 5.3 Drive async through `TestClient`; hand-written fakes preferred over mocks.

## 6. Guard & gate

- [x] 6.1 Run `/trocado:guard` (architecture-guard) — confirm the framework stays in `infrastructure/http/` + the
  composition root, the error→status table holds no framework types, pt-BR non-leaking messages, one-concept-per-file,
  dependency direction, test layout.
- [x] 6.2 `uv run poe check` (format → lint → mypy --strict → pytest) green.
- [x] 6.3 Re-read specs vs implementation: every scenario in the `http-api` and `create-budget` deltas has a
  covering test (unified envelope shape, 422 validation w/ field details, 409 overlap, totality).
