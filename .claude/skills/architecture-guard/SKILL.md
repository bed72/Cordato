---
name: architecture-guard
description: Audit Trocado/Cordato code or a diff against the project's non-negotiable rules — spec-first (every feature has an OpenSpec change), async everywhere at I/O boundaries, Clean Architecture layering and dependency direction, naming conventions, ABC ports, no library names in files/classes, a dedicated mapper at every boundary, derive-don't-store, soft-delete in the repository, exact-decimal money, per-person authorization, one-concept-per-file, value-object-earns-existence, the gateways/ bucket, determinism ports (clock/id), pt-BR non-leaking error messages, the Litestar web edge (framework confinement, body bound to `data`, layered/router-scoped DI & error handlers, /v1 prefix, the unified error envelope, errors/ layout), and test layout. Use before committing, when reviewing changes, or whenever the user asks to check architecture/convention compliance.
metadata:
  author: trocado
  version: "2.1"
---

# Architecture Guard

Audit changes against the **non-negotiable rules** defined in `CLAUDE.md`. This skill is the enforcement
arm of those rules: it reads the code, classifies each finding, and reports violations with the exact rule
they break and how to fix them. It **does not** silently fix — it reports; apply fixes only when asked.

## Scope

Default target is the **current uncommitted diff**. If the user names files, a feature, or a change, scope
to that instead. State what you audited.

```bash
git diff --stat 2>/dev/null || echo "(not a git repo — audit the files the user named)"
```

## The checklist

Go through every category. For each violation report: `path:line` · the rule broken · the fix.

### 1. Spec first (process)
- Does this change implement or alter **feature behavior**? If yes, there MUST be a corresponding OpenSpec
  change. Verify one exists and covers it:
  ```bash
  openspec list --json 2>/dev/null
  ```
- Behavior that diverges from the spec is a bug in **one of them** — never "ignore the spec". Flag drift.
- Pure refactor / build-infra / typo with no behavior change is exempt — but if in doubt, flag it as
  "needs a change".

### 2. Async everywhere
- Every **port** (interface ABC) method that touches I/O is `async def` returning an awaitable.
- Every **adapter** (repository/infra), **use case**, and **web handler** is `async` and `await`ed end to end.
- **No blocking call on the event loop.** A sync-only dependency must be wrapped off-loop (thread executor)
  **at the adapter edge** — never leaked inward. No hidden `.run()` / `asyncio.run()` bridge inside a method.
- The pure `domain/` (entities, value objects, policies, no-I/O services) stays **synchronous** — flag
  `async def` on a pure-compute domain method as empty ceremony.

### 3. Dependency direction & layering
- Imports point **inward only**: `infrastructure → application → domain`. Flag any `domain/` file importing
  from `application/` or `infrastructure/`, and any `application/` file importing `infrastructure/`.
- `domain/` imports **nothing framework/lib**. Pure Python only.
- A library/ORM is known **only** inside `infrastructure/`.

### 4. Naming conventions (apply to ALL modules)
Flag any mismatch with the canonical table:
| Concept | Folder | File suffix | Class suffix |
|---|---|---|---|
| Entity | `domain/entities` | `_entity.py` | `Entity` |
| Value Object | `domain/value_objects` | `_value_object.py` | `ValueObject` |
| Enum (closed domain set) | `domain/enums` | role-named, no suffix (`person_status.py`) | role-named, no suffix (`PersonStatus`) |
| Virtual Object (read-time view) | `domain/virtual_objects` | `_virtual_object.py` | `VirtualObject` |
| Error | `domain/errors` | `_error.py` | `Error` |
| Interface (port) | `application/interfaces` | `_repository_interface.py` (etc.) | `Interface` |
| Implementation | `infrastructure/repositories` | `_repository.py` | `Repository` |
| Use case | `application/use_cases` | `_use_case.py` | `UseCase` |
| Data (command/output) | `application/data` | `_data.py` | `Data` |
| Mapper entity↔model | `infrastructure/mappers` | `_model_mapper.py` | `ModelMapper` |
| Mapper entity→data | `application/mappers` | `_data_mapper.py` | `DataMapper` |
| Model (table) | `infrastructure/models` | `_model.py` | `Model` |
| Gateway (other adapter) | `infrastructure/gateways` | role-named (`password_hasher.py`, `clock.py`) | role-named (`PasswordHasher`, `Clock`) — no lib name |

### 5. The hard "never" rules
- **No library name in a file or class.** `ExpenseRepository`, never `SqlAlchemyExpenseRepository`. The tool
  hides *inside* the file. Flag any class/file carrying a lib name.
- **Interfaces always via `abc.ABC` + `@abstractmethod`.** No duck-typed/Protocol-only ports.
- **No abbreviations.** `value_objects` not `vos`; `MoneyValueObject` not `MoneyVO`.
- **A dedicated mapper class at every boundary** — never inline conversion across Request↔Data↔Entity↔Model.

### 6. Domain-model integrity (derive, don't store)
- **`Expense` has zero link to `Budget`.** Flag any `budget_id` on an expense (model, entity, or data) or any
  stored expense→budget association. Belonging is computed at read-time by date range.
- Budget/couple aggregates (`total_spent`, `remaining`, couple budget/expenses) are **computed**, not stored
  columns. Flag persisted aggregate fields (current decision: **no cache**).
- Don't add a stored reference where attribute-derived association would do.

### 7. Money & dates
- Money is **exact decimal** (cents, BRL) — flag any `float` for amounts.
- Budget dates are `date` (no time), inclusive both ends. Flag `datetime` where a pure `date` is meant.

### 8. Soft-delete & authorization
- Soft-delete (`deleted_at`) is the **repository's** responsibility: normal reads exclude removed rows; only
  an explicit `list_including_removed` (audit) sees all. Flag use-case-level soft-delete filtering or normal
  reads that return removed rows.
- Account deletion is the **only** physical/hard delete (cascade + email neutralization + status flip + pair
  dissolution). Flag hard-deletes anywhere else.
- Per-person authorization: a person reads/mutates only their own data; shared (couple) views are
  **read-only**. Flag a write path reaching a partner's data.

### 9. One concept per file
- Each value object, enum, error, port, use case, mapper, and gateway is its **own file**. Flag any module
  bundling several (e.g. multiple error classes in one file, or several value objects together).
- The same applies to tests — see §12.

### 10. Value object earns its existence (and enums are their own shape)
- A value object must enforce an **invariant** or carry **behavior** (validation, normalization, a domain
  operation). Flag a value object that only wraps a bare primitive with no rule (a password **hash**, an
  opaque token) — it should be the primitive (`str`). Reverse is also a flag: a raw primitive that clearly
  needs validation (an unvalidated email `str`) should be a value object.
- **An enum lives in `domain/enums/`, never `domain/value_objects/`.** A closed domain set
  (`PersonStatus`, `Perspective`) validates nothing and carries no behavior, so it is *not* a value
  object. Flag an `Enum` placed under `value_objects/` (move to `enums/`), and flag a `_value_object`/`_enum`
  suffix on the file/class — enums are role-named with no suffix. If an enum grows an invariant or
  behavior, it becomes a value object and moves to `value_objects/`.

### 11. Infrastructure buckets, determinism & messages
- **Two buckets only.** Persistence in `repositories/` (+ `models/`, `mappers/`); every other outbound adapter
  in `gateways/`. Flag a folder-per-tool (`hashers/`, `providers/`, `senders/`…) — it must be a file in
  `gateways/`. Flag a `Model`/`ModelMapper` invented before the ORM exists (no table to bridge yet).
- **Determinism via ports.** Flag `uuid.*`/`datetime.now()` called **inside** `domain/` (entities/VOs) — `id`
  and `created_at` come from `IdentifierProviderInterface` (uuid7) + `ClockInterface`, passed into the entity
  factory. Flag an entity constructed bypassing its `create(...)` factory into an illegal state, or an entity
  compared by value instead of identity (`id`).
- **Sync adapter off-loop.** A sync library call in a gateway (e.g. Argon2) must be wrapped (`asyncio.to_thread`)
  at the adapter edge — flag a blocking call on the event loop.
- **Error messages.** Domain error messages must be short **pt-BR** and **must not echo sensitive values**
  (no account enumeration: `EmailAlreadyInUseError`/`InvalidEmailError` never include the email). Flag a
  message that interpolates the offending value, or an English user-facing message.

### 12. Test layout
- **One test file per unit, mirroring the source path** (`tests/<ctx>/domain/value_objects/test_email_value_object.py`).
  Flag a grouped file covering several units.
- **Two integration depths** under `tests/<ctx>/integrations/`:
  - **Root** (`integrations/test_*_integration.py`) — use-case level, real adapters, no HTTP server.
  - **`http/` subdirectory** (`integrations/http/test_*_http.py`) — HTTP level, `TestClient(app=build())`.
  Flag an HTTP integration test placed at the `integrations/` root (wrong depth). Flag a pure use-case
  integration test placed in `integrations/http/` (also wrong depth).
- **Fakes** in `tests/<ctx>/fakes/`, one per file. Flag fakes defined inline in a test module.
- Prefer hand-written fakes over mocks for ABC ports. Flag an `AsyncMock` used where a typed fake belongs.
- **Web edge:** no standalone controller unit test (framework adapter — covered by `TestClient` in
  `integrations/http/`); the **pure** web pieces (error→status table, `error_code`, pt-BR message lookups) DO
  get plain-Python unit tests mirroring the source (`tests/<ctx>/infrastructure/http/errors/...`). Flag a
  missing HTTP integration test for a wired route, or a pure lookup left untested.
- **Load tests** live in `tests/stress/`, not inside any feature's `integrations/`. Flag a Locust `HttpUser`
  file placed under a feature's test tree.

### 13. The web edge (Litestar)
Applies to anything under `infrastructure/http/` and the composition root (`core/infrastructure/http/app.py`,
`main/*_factory.py`). See `CLAUDE.md` → "The web edge (Litestar)" and "HTTP errors — one unified envelope".
- **Framework confined.** Litestar/Pydantic-web imports appear **only** under `infrastructure/http/` and the
  composition root / `main/` factories. Flag any `litestar` import in `domain/` or `application/`. No
  `presentation/` layer.
- **No lib name** in controller/file/class (`BudgetController`, never `LitestarBudgetController`).
- **Body bound to `data`.** A request-body handler parameter MUST be named `data` (Litestar reserves `data` for
  the body and `request` for the ASGI `Request`). Flag a body param named anything else — it silently breaks
  binding. The controller only binds → maps → `await`s the use case → maps out; flag any business rule in it.
- **Dedicated request/response mappers** (`*RequestMapper.to_data`, `*ResponseMapper.to_response`,
  `@staticmethod`, named after destination). Flag inline conversion or a request mapper named `*DataMapper`.
- **DTOs** are Pydantic v2 with `Field` docs/examples; structural validation only (no domain rules duplicated).
- **Layered, scoped DI.** Cross-cutting ports (`clock`/`identifier`) live at the **app** layer (`register_core`);
  each feature contributes a `Router` (its factory) with its **own scoped** providers and **specific** key names.
  Flag feature deps registered at the app layer, a global container/Rodi, the composition root importing a
  feature controller, or non-unique dependency keys. Repositories are app-scoped singletons (closure over one
  instance built per `build()`); use cases per-request.
- **`/v1` prefix** owned by the composition root; controllers declare the **bare** resource path. Flag a version
  hardcoded in a controller path.
- **Unified error envelope.** Errors answer as `{status, code, message, errors?}` via native
  `exception_handlers` — never the framework default shape, never the Problem Details plugin. `errors` present
  only for field-level errors. Flag a handler echoing the framework's English `detail`, a non-pt-BR `message`, a
  varying shape, or a domain error left unmapped (→ unhandled 500).
- **Error handlers layered like the DI.** Domain handlers are **router-scoped** (built from
  `{**CORE_STATUS_ERROR, **<FEATURE>_STATUS_ERROR}` in the feature factory); only the cross-cutting handlers
  (`ValidationException` → 422, the `HTTPException` fallback) live at the app. Validation field messages are
  pt-BR (translated from the Pydantic `type`), never raw English.
- **Pure error tables.** `<FEATURE>_STATUS_ERROR` / `CORE_STATUS_ERROR` are `dict[type[Exception], int]` with
  **no framework types** (plain `int`/`HTTPStatus`), unit-testable in pure Python. Flag a framework import there.
- **`errors/` organized by role:** `responses/` (envelope DTOs) · `handlers/` (the only framework-aware piece) ·
  `validations/` + `http/` (pt-BR message lookups) · `lookups/` (`error_code`, status tables). The message/code
  lookups are **pure functions, not `*Mapper` classes** — flag a lookup modeled as a mapper (over-engineering).

## Output format

Group findings by **severity**:
- **🔴 Blocker** — breaks a non-negotiable rule (missing spec, sync I/O on the loop, stored expense→budget
  link, lib name in class, float money, hard-delete outside account deletion, `uuid`/`datetime` inside the
  domain, an error message leaking an email/sensitive value, a premature `Model`/`ModelMapper`; on the web edge:
  a framework import in `domain/`/`application/`, a request body param not named `data`, a domain error left
  unmapped (unhandled 500), or an error not in the unified pt-BR envelope).
- **🟡 Convention** — naming/structure drift, missing dedicated mapper, abbreviation, folder-per-tool instead
  of `gateways/`, bundling concepts in one file, a primitive-wrapping value object, grouped/misplaced tests,
  inline fakes.
- **🟢 Note** — stylistic or "in doubt, confirm".

End with a one-line verdict: **PASS** (no blockers) or **CHANGES REQUIRED** (≥1 blocker), and the blocker count.
