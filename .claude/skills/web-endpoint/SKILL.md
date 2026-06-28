---
name: web-endpoint
description: Scaffold or extend the Litestar HTTP edge for a Trocado/Cordato use case — a native class controller (body bound to the reserved `data`, 201 by default), Pydantic v2 request/response DTOs with OpenAPI docs, dedicated request/response mappers, the feature Router with scoped native DI mounted under /v1, and the feature's pure error→status table with router-scoped handlers in the unified pt-BR error envelope. Confines the framework to infrastructure/http/ + the composition root, never touching domain/ or application/. Refuses to scaffold unless an OpenSpec change covering the work already exists — enforcing spec-first. Use when exposing a use case over HTTP, adding an operation to a controller, or wiring a new feature's web edge.
metadata:
  author: trocado
  version: "1.0"
---

# Web Endpoint (Litestar)

Generate (or extend) the **HTTP edge** for a use case, wired to the conventions in `CLAUDE.md` →
"The web edge (Litestar)" and "HTTP errors — one unified envelope". This skill **encodes** those rules so the
generated edge starts correct: the framework stays at the boundary, the body binds to `data`, DI and error
handlers are layered/router-scoped, every route is under `/v1`, and errors answer in the single pt-BR envelope.

> The web edge is an **inbound adapter** that *drives* a use case. It NEVER contains business rules and NEVER
> touches `domain/`/`application/` internals beyond calling the use case with its `data` command and mapping its
> read-model out. The framework-free, server-free testable unit stays the **use case**.

## Gate 0 — spec first (non-negotiable, refuse otherwise)

Exposing a use case over HTTP is an **API contract** = feature behavior. There MUST be an approved OpenSpec
change covering it before any code:

```bash
openspec list --json
```

- No relevant change → **STOP. Do not scaffold.** Tell the user to create one first (`openspec-propose`, or the
  `/trocado:endpoint` command which drives this). The spec describes *what* and *why* before *how*.
- A change exists → announce `Using change: <name>`, read its `specs/` + `tasks.md`, and scaffold only what it
  covers (which routes, which status codes, which errors).

## What it generates (per feature, under `features/<ctx>/infrastructure/http/`)

```
infrastructure/http/
  controllers/   <resource>_controller.py     class <Resource>Controller(Controller)
  requests/      <command>_request.py          <Command>Request     (Pydantic v2)
  responses/     <resource>_response.py        <Resource>Response   (Pydantic v2)
  mappers/
    requests/    <command>_request_mapper.py   <Command>RequestMapper.to_data   (@staticmethod)
    responses/   <resource>_response_mapper.py <Resource>ResponseMapper.to_response (@staticmethod)
  errors/        <feature>_status_error.py     <FEATURE>_STATUS_ERROR   (pure dict[type[Exception], int])
main/
  <feature>_factory.py                          register_<feature>() -> Router
```

### Controller
- Litestar-native class controller: `path` on the class (the **bare** resource path, e.g. `/budgets` — never the
  version), one decorated method per operation; `@post()` answers **201** by default (set `status_code=` only to
  override). Class name carries **no lib name** (`BudgetController`, never `LitestarBudgetController`).
- **The body parameter MUST be named `data`** — Litestar binds the validated body to the reserved `data` kwarg;
  `request` is also reserved (the ASGI `Request`). Any other name silently breaks binding (→ 500).
- Inject the use case **by name** with `NamedDependency[<UseCase>]`. The method only: `to_data` the request →
  `await use_case.execute(...)` → `to_response` the read-model. No business rule.
- Add `tags = ["<Resource>"]`, a `summary=`, and a `description=` (pt-BR) on the operation for Swagger.

### DTOs (Pydantic v2)
- `requests/<command>_request.py`: structural validation only (presence/type) — domain rules stay in the value
  objects, **never duplicated**. Add `Field(description=, examples=)` per field + a `model_config` example.
- `responses/<resource>_response.py`: the serialized read-model (named after what it represents, not the use
  case). Same `Field` docs/examples. Carries no spend/derived fields unless the read-model does.

### Mappers (dedicated, `@staticmethod`, named after the destination)
- `<Command>RequestMapper.to_data(request) -> <Command>Data` — request → command. Named after the **request**
  (never `DataMapper`; `application/mappers/<Resource>DataMapper` owns that). **Transitional:** fill `person_id`
  with the fixed placeholder until the identity change lands.
- `<Resource>ResponseMapper.to_response(data) -> <Resource>Response` — read-model → response.

### Composition (the feature factory returns a `Router`)
`register_<feature>() -> Router` builds and returns a `Router(path="/", route_handlers=[<Controller>, …])` with:
- **`dependencies`** = its own **scoped** providers (the in-memory repository as an app-scoped singleton via a
  closure over one instance; the use case per-request, taking `clock`/`identifier` by name from the app layer).
  Keys are **specific** (`create_budget_use_case`, `budget_repository`) — unique within the feature.
- **`exception_handlers`** = `build_domain_exception_handlers({**CORE_STATUS_ERROR, **<FEATURE>_STATUS_ERROR})`
  (router-scoped domain framing).
The composition root (`core/infrastructure/http/app.py`) mounts every feature router under one `Router("/v1", …)`,
registers only the cross-cutting handlers (`build_core_exception_handlers()`), and the OpenAPI config. Do **not**
register feature deps or error maps at the app layer; do **not** import a feature controller in `app.py`.

### Errors (unified pt-BR envelope — see `errors/` by role)
- Add the feature's pure `<FEATURE>_STATUS_ERROR: dict[type[Exception], int]` (no framework types) in
  `infrastructure/http/errors/<feature>_status_error.py`, **total** over the errors the wired operations can
  raise (conflict/invariant → 409, malformed value → 422, not-found → 404, auth → 401). Include shared-kernel
  errors it raises (e.g. `InvalidMoneyError`) by merging `CORE_STATUS_ERROR` at the factory, not by duplicating.
- Reuse the core machinery in `core/infrastructure/http/errors/` (`responses/`, `handlers/`, `validations/`,
  `http/`, `lookups/`). The envelope is `{status, code, message, errors?}`; `code` from the error class, `message`
  from the domain's pt-BR `str(exc)`; `errors` only for field-level (validation) errors. **Never** echo a
  framework English `detail` or leak sensitive data.

## Hard rules this skill must not break
- Framework imports **only** under `infrastructure/http/` + the composition root / `main/` factories. `domain/`
  and `application/` stay framework-free.
- No lib name in any file/class. Dedicated mapper per hop (no inline conversion). One concept per file.
- The error→status table holds **no** framework types and is unit-testable in pure Python.
- Money stays exact decimal; dates pure `date`. pt-BR, non-leaking messages.

## After scaffolding
- Invoke `feature-tests` for the HTTP integration test (`TestClient` against `build()`: status + the unified
  error envelope + store persistence) and the pure lookup/table unit tests.
- Run `uv run poe check` (format → lint → mypy --strict → pytest), then `/trocado:guard` on the diff.
- Keep code and spec in sync; update the spec in the **same** change if behavior shifts.

See `CLAUDE.md` → "The web edge (Litestar)", "HTTP errors — one unified envelope", and "Mapper conventions".
