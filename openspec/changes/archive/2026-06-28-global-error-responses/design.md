## Context

`web-create-budget` (archived) brought the Litestar edge online with layered DI (cross-cutting `clock`/
`identifier` at the app layer; each feature contributes a `Router` with scoped providers), a `/v1` prefix, and
OpenAPI/Swagger — but it deliberately left **error framing** out: today domain errors become unhandled `500`s
and a malformed body returns Litestar's default `400`. This change supplies the missing, cross-cutting error
contract. The hard project constraints apply: the framework lives only at `infrastructure/http/` + the
composition root; the dependency rule points inward; domain errors carry short pt-BR messages and leak nothing
sensitive; one concept per file; tests mirror the source and the pure pieces are tested without a server.

## Goals / Non-Goals

**Goals:**
- One standardized error envelope for **every** error — domain, validation, and framework HTTP errors — with a
  shape that does not vary by error kind.
- A framework-independent, **total** domain-error→HTTP-status table, unit-tested in pure Python.
- Validation errors framed as `422` (not `400`) with field details.
- Per-feature domain-error handlers scoped to each feature's router (cross-cutting at the app), mirroring the DI layering.

**Non-Goals:**
- Request identity (`X-Person-Id`) — still its own change; the mapper keeps a fixed placeholder `person_id`.
- Persistence/ORM; new endpoints; other features' error entries (they arrive with their endpoints).

## Decisions

### D1 — Envelope: a single `ErrorResponse` via Litestar's native `exception_handlers`

Every error answers in **one consistent JSON envelope** (an `ErrorResponse` Pydantic model) with exactly these
keys — the shape never varies by error kind:

| Field | Source |
|---|---|
| `status` | the HTTP status |
| `code` | a stable programmatic identifier of the error kind (e.g. `overlapping-budget`, `validation`, `not-found`) |
| `message` | a human message — the domain's pt-BR text (`str(exc)`) for domain errors |
| `errors` | a list of `{key, message}` field details — **optional**, present only for field-level errors (validation), omitted otherwise |

This is wired with Litestar's **native** `exception_handlers`, **layered** like the DI (registerable on the app,
a router, or a controller — see D5). `errors` defaults to `None` on the model and handlers serialize with
`model_dump(exclude_none=True)`, so a non-field error omits the key entirely rather than showing an empty list.

**Why not RFC 9457 Problem Details / the `ProblemDetailsPlugin`.** The plugin was tried first and rejected: it
produced an **inconsistent shape** — a `detail` field auto-filled only sometimes, and `errors` only on validation
— so two errors did not share keys. Its `type` URI is also low-value for an internal API (non-dereferenceable,
unused by clients) versus a short programmatic `code`. Native `exception_handlers` give full control over a
single, stable envelope, and are *layered* (registerable on app/router/controller) like the DI — matching the
project's feature-scoped style.

### D2 — The domain-error → HTTP-status mapping is a pure, framework-independent table

The mapping is a plain `dict[type[Exception], int]` (error class → HTTP status) with **no Litestar types**, so it
is unit-testable in pure Python (per CLAUDE.md). Status codes are plain `int`/`http.HTTPStatus`, not a framework
concept. The budgeting subset reachable today:

| Error | Status |
|---|---|
| `InvalidMoneyError` (core) | 422 |
| `InvalidBudgetAmountError` | 422 |
| `InvalidBudgetRangeError` | 422 |
| `OverlappingBudgetError` | 409 |
| `BudgetNotFoundError` | 404 |

The full ~22-error table is built incrementally as each feature's endpoints land; this change seeds the budgeting
subset plus the core-generic `InvalidMoneyError → 422`.

### D3 — Handlers are generated generically from the table

The only framework-aware piece (in `core/infrastructure/http/errors/handlers/`) turns the pure table into the
`exception_handlers` map: for each `(ErrType, status)` it builds a handler
`lambda request, exc: Response(ErrorResponse(status=status, code=error_code(type(exc)), message=str(exc)), status_code=status)`.
`message` comes straight from the domain text; `code` from a pure `error_code(error_type)` helper (class name →
kebab, `Error`/`Exception` suffix dropped, e.g. `OverlappingBudgetError → overlapping-budget`). No per-error
hand-written handler — the table is the single source.

### D4 — Validation and framework HTTP errors share the envelope

- **Validation.** Litestar's `ValidationException` (a `400`) gets a dedicated handler returning `422`,
  `code="validation"`, `message="Dados inválidos."`, with per-field `errors`. Each field message is **pt-BR**:
  the handler reads the structured underlying errors from `exc.__cause__` (Pydantic exposes `errors()` as a
  method; Litestar's msgspec path exposes an `errors` list attribute — both handled), takes each error's stable
  `type` (`missing`, `decimal_type`, `date_parsing`, …) and `loc`, and translates the `type` via a pure
  `validation_message(type) -> str` table (generic pt-BR fallback for unlisted codes). This owns the boundary's
  `422`, shape, **and language** — never echoing Pydantic's raw English.
- **Framework HTTP errors.** A handler on the `HTTPException` base frames malformed JSON (`400`), unknown route
  (`404`), wrong method (`405`), etc. in the same `ErrorResponse`. Both `code` and `message` are derived from the
  **HTTP status** — `code` from the status name (`400 → bad-request`, `404 → not-found`) and `message` from a pure
  pt-BR `http_message(status)` table — **never** the framework's English `detail` (which can leak parser internals
  like a byte offset). So **no** error escapes in the framework's default shape or language. Litestar resolves the
  most specific registered type, so `ValidationException` wins over `HTTPException`, and domain errors (plain
  `Exception` subclasses) match their own entries.

### D5 — Per-feature handlers scoped to the feature's router; cross-cutting at the app

Error framing is **layered exactly like the DI**. Each feature owns its error→status mapping as a pure constant
in its `infrastructure/http/errors/lookups/` (budgeting → `{InvalidBudgetAmountError: 422, InvalidBudgetRangeError: 422,
OverlappingBudgetError: 409, BudgetNotFoundError: 404}`), and its **factory** builds the domain handlers from
`{**CORE_STATUS_ERROR, **<FEATURE>_STATUS_ERROR}` (so shared-kernel errors it can raise, like
`InvalidMoneyError`, are framed where they occur) and registers them on **its own `Router`**
(`build_domain_exception_handlers(...)`). The composition root registers **only** the cross-cutting handlers —
`build_core_exception_handlers()` → `ValidationException` (422) + the `HTTPException` fallback — at the app layer
(`Litestar(exception_handlers=…)`), and never imports a feature's error map. Litestar resolves the most specific
across layers (controller → router → app), so a budgeting domain error is framed in budgeting's router while a
validation error is framed at the app. Adding a feature's error framing = its own router, no edit to the app or
to other features.

### D6 — Totality and non-leaking

The mapping SHALL be **total** over the domain errors reachable at the wired boundary: every such error has a
table entry, so none falls through to an unhandled `500`. The pt-BR message is conveyed via `message` and nothing
sensitive is echoed — `BudgetNotFoundError` stays the generic `"Orçamento não encontrado."`, preserving
non-enumeration. A pure test asserts each entry maps to its expected status and that the budgeting subset is
covered.

### D7 — `__main__.py` reload fix (bundled infra tweak)

`uvicorn.run(app, …, reload=True)` does not reload — uvicorn requires an **import string** for reload/workers and
silently ignores `reload` when handed an app object. Switch to
`uvicorn.run("trocado.core.infrastructure.http.app:app", host="127.0.0.1", port=8000, reload=True, …)` so
`python -m trocado` hot-reloads, matching `poe serve`. Low-risk, no behavior change to the app itself.

## Risks / Trade-offs

- **[An `HTTPException` handler reshapes 404/405/etc.]** → Desired: a single envelope for everything, including
  framework-raised HTTP errors. Accepted.
- **[Table drifts from reality as errors are added]** → Mitigated by the totality test per feature and by keeping
  each feature's map beside its endpoints; an unmapped boundary domain error is a visible `500` in the integration
  test.
- **[Reading `exc.__cause__` for structured validation errors is an internal detail]** → Guarded: it accepts
  either a Pydantic `errors()` method or a msgspec `errors` list attribute, and falls back to `exc.extra` (with a
  generic pt-BR message) if neither is present. A new Pydantic `type` code simply gets the generic fallback until
  added to the table.

## Open Questions

- None — the envelope (`status`/`code`/`message`/`errors`) and the validation status (`422`) are decided.
