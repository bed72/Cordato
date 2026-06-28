## Why

The web edge is online (`POST /v1/budgets`), but it has **no error handling**: a domain error raised by the use
case surfaces as an unhandled `500`, and a malformed body falls through to Litestar's default `400` with a
framework-shaped body. There is no single, predictable error contract for a client to rely on, and the
validation status is wrong (`400` where it should be `422`). This change introduces **one standardized error
envelope for every error** — domain, validation, and framework HTTP errors alike — and fixes the validation
status. It is the domain-error→HTTP-status mapping that the archived `web-create-budget` change deferred.

## What Changes

- **One unified error envelope** for every error: `status` (HTTP status), `code` (a stable, programmatic
  identifier of the error kind, e.g. `overlapping-budget`), and `message` (a human message — pt-BR for domain
  errors), plus an **optional** `errors` (a list of `{key, message}` field details) present only for field-level
  errors and omitted otherwise. Implemented with Litestar's native `exception_handlers` (returning an
  `ErrorResponse` model) — chosen over the RFC 9457 Problem Details plugin, which produced an **inconsistent
  shape** (a `detail` only sometimes, `errors` only on validation) and a low-value `type` URI.
- **A framework-independent domain-error → HTTP-status table.** A pure `dict[type[Exception], int]` with **no
  framework types**, unit-tested in plain Python. The only framework-aware part is the handler builder in
  `core/infrastructure/http/`, which turns the table into handlers generically — for each `(ErrType, status)` a
  handler returning `ErrorResponse(status=status, code=error_code(ErrType), message=str(exc))`.
- **Validation errors map to `422`** (was Litestar's default `400`), in the same envelope, lifting the field
  errors into `errors` with `code="validation"` and `message="Dados inválidos."`.
- **Framework HTTP errors use the same envelope too** — an `HTTPException` handler frames unknown-route `404`,
  `405`, etc. in `ErrorResponse`, so nothing escapes in the framework's default shape.
- **Per-feature handlers scoped to the feature's router; cross-cutting at the app.** Mirroring the DI layering:
  each feature owns its error→status mapping in its `infrastructure/http/errors/lookups/` and frames it with handlers on
  **its own `Router`** (built in its factory from `{core ∪ feature}` entries, so shared errors like
  `InvalidMoneyError` are framed where raised). The app registers only the cross-cutting handlers. Only the
  **budgeting subset** is seeded now; other features add their entries when their endpoints land.
- **The mapping is total over known boundary-reachable errors** — none falls through to an unhandled `500`. The
  pt-BR message is conveyed via `message`; nothing sensitive is leaked (`BudgetNotFoundError` stays generic,
  preserving non-enumeration).
- **Fix `__main__.py` reload (infra tweak).** `uvicorn.run` passed the app **object** with `reload=True`, which
  uvicorn ignores (reload needs an import string). Switch to the import string so `python -m trocado`
  hot-reloads, matching `poe serve`.

## Capabilities

### Modified Capabilities
- `http-api`: add the single unified error envelope for all errors; the framework-independent, total
  domain-error→HTTP-status table; validation errors framed as `422` with field details; and per-feature domain
  handlers scoped to each feature's router, with the cross-cutting handlers at the app layer.
- `create-budget`: the previously-deferred error framing is now defined — an overlapping budget over HTTP returns
  `409` and a malformed body returns `422`, both in the unified envelope.

## Impact

- **No new runtime dependencies** — Litestar's native `exception_handlers` are used (no plugin).
- **New code:** under `infrastructure/http/errors/` (sub-grouped into `lookups/`, `responses/`, `handlers/`): a
  pure error→status table per feature, core's generic table, the error-code/validation-message lookups, the
  `ErrorResponse`/`ErrorDetailResponse` envelope models, and the exception-handler builders. The feature router registers
  its domain handlers; the app registers the cross-cutting ones.
- **No changes to `domain/` or `application/`** — domain errors keep their pt-BR messages; the web edge frames
  them. The error→status table holds no framework types and is tested in pure Python.
- **One-line `__main__.py` fix** so dev reload works.
- **Not in scope (own future changes):** request identity (`X-Person-Id`, still a fixed placeholder), the
  ORM/persistence, and the other features' endpoints and their error entries.
