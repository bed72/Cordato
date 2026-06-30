# Trocado / Cordato

A personal-finance tool for **couples** that refuses to dissolve the individual into the relationship. Each person owns their own money, budgets, and expenses. When two people pair up, a **shared view** emerges — a lens, not a merge. If the pair breaks up, each one keeps everything intact.

> **A couple is a point of view, not an owner.**

- **Individual by default.** Every datum belongs to exactly one person.
- **Shared by consent.** Pairing adds a *read* perspective over two individuals.
- **Reversible without loss.** Unpairing never destroys nor moves anyone's data.

---

## Non-negotiable process rule: spec first, always

> **No line of a feature is born without an OpenSpec spec tied to it.**

Flow (always in this order):
1. **Propose** — `openspec-propose` (explore first with `openspec-explore` if fuzzy)
2. **Approve** — spec describes *what* and *why* before *how*
3. **Implement** — `openspec-apply-change`
4. **Archive** — `openspec-archive-change`

- **No spec, no PR.** Feature code without a change is rejected.
- **Spec is the source of truth.** Code/spec divergence is a bug in one of them — never "spec is outdated".
- **Behavior change = new change.** Domain rules, lifecycles, API contracts start with OpenSpec.
- Low-risk exceptions (pure refactor, build tweaks, typo fixes) skip the change — when in doubt, propose.

---

## Central modeling principle: derive, don't store

> **Store events; compute groupings.**

Add a link only when the relationship is an intrinsic fact of ownership (a person owns a budget), never for query convenience.

### The association that deliberately does NOT exist: `Expense ──╳── Budget`

An expense does **not** point to a budget. It belongs to a budget **dynamically**, by falling within the budget's date range — computed at read-time, never stored. Editing budget dates or deleting a budget never touches an expense.

---

## Stored entities

All have `id` (opaque) and `created_at`.

**Person** — `email` (unique), `name`, `password` (Argon2 **hash**, never plaintext), `status` (`active`/`deleted`). Hard-delete only (see Lifecycles).

**Budget** — `person_id`, `amount` (exact decimal, BRL), `start_date`, `end_date` (inclusive, date only), `note` (optional), `deleted_at` (soft-delete). No list of expenses — spend is computed. **Non-overlap invariant:** two live budgets of the same person share no date (not even the boundary day).

**Expense** — `person_id`, `amount` (exact decimal), `occurred_on` (date only — named `occurred_on`, not `date`), `description` (optional), `deleted_at` (soft-delete). **Zero link to Budget.**

**Pair** — `person_a_id`, `person_b_id`, `deleted_at` (soft-delete = dissolved). Owns no money, budget, or expense. Invariant: a person is in ≤1 active pair.

**InviteCode** — `creator_id`, `code` (**CSPRNG-generated**, never predictable), `expires_at` (~1 day), `consumed_at` (null = unused). Accepting a valid code creates the Pair and sets `consumed_at`. Single-use.

---

## Virtual objects — computed at read-time, NEVER stored

- **Active budget (enriched):** live budget containing today + `total_spent` + `remaining`
- **Default budget ("No budget"):** fabricated bucket for expenses outside any real budget
- **Couple budget:** `[min(starts), max(ends)]`, amount = sum, spend = sum. Approximate panorama — not an entity
- **Couple expenses:** union of both partners' expenses, each marked `mine`/`theirs`

These live in `domain/virtual_objects/` (`active_budget_virtual_object.py` → `ActiveBudgetVirtualObject`). A **Virtual Object** is a read-time projection: holds entities, carries derived behavior, has no identity or lifecycle, is **never stored**. It is neither an entity nor a value object:

| | `id` | References entity? | Validates value | Persisted |
|---|---|---|---|---|
| Entity | yes | — | — | yes |
| Value Object | no | **never** | yes | no |
| **Virtual Object** | no | **yes** | no — composes + derives | no |

---

## Lifecycles

**Dissolve a pair** — soft-delete of the Pair. Both partners keep all their data intact.

**Delete account (hard-delete — no restore)** — requires live session + password. In one atomic operation:
- invalidate session, verify password
- physically delete (cascade) budgets and expenses
- neutralize email (`deleted+<id>@…`), freeing it for reuse
- set `status = deleted`
- dissolve any active pair

Reusing the email creates a **new** Person — never resurrects the old one.

**Day-to-day soft-delete** — Budget/Expense/Pair: `deleted_at`, disappears from normal views, visible in audit.

---

## Cross-cutting expectations

- **Per-person authorization.** Each person reads/mutates only their own data. Pairing grants read-only access to the shared view — never write over a partner's data.
- **Exact decimal money** (never float). **Date-only** for budget belonging.
- **No cache** for derived numbers (`total_spent`, `remaining`, couple aggregates) — data is small.

---

## Parking lot

- **Joint couple goal** — a genuine joint budget would be its own stored entity. Out of scope.
- **Timezones** — pure `date` for now; handle if/when needed.
- **Postgres RLS** — defense-in-depth backstop (not primary auth), via its own OpenSpec change when the ORM lands.

---

## Architecture & conventions

Clean Architecture + tactical DDD + Ports & Adapters, modular monolith. Dependency rule always points **inward**: `infrastructure → application → domain`. `domain/` imports nothing from outside.

### Async everywhere (non-negotiable)

**Every I/O boundary is `async`. No exceptions.** Ports, adapters, use cases, and web handlers are all `async def` end to end.

- **Gather independent awaits:** `id, created_at = await asyncio.gather(identifier.generate(), clock.now())`. Await sequentially only when a real data dependency exists.
- **Guard before gather:** short-circuit checks (e.g. email uniqueness) come before expensive calls (e.g. password hashing).
- **Pure `domain/` stays synchronous** — entities, value objects, policies do no I/O.

### Package organization (`src/trocado/`)
- `core/` — shared kernel (same layer structure as a feature)
- `features/<context>/` — one package per context (`expenses`, `budgeting`, `identity`, `pairing`). **No `shared/`.**

### Layers inside each module
- `domain/` → `entities/`, `value_objects/`, `enums/`, `virtual_objects/`, `errors/` (+ `policies/`, `services/`)
- `application/` → `interfaces/` (ports, ABC), `data/`, `use_cases/`, `mappers/`, `services/`
- `infrastructure/` → `models/`, `mappers/`, `repositories/`, `gateways/`

**Infrastructure has exactly two buckets:**
- **`repositories/`** (+ `models/`, `mappers/`) — persistence
- **`gateways/`** — every other outbound adapter (hasher, clock, identifier, future: email/SMS/events). One file per adapter, flat. **Do not create subfolders per kind.**

### Naming conventions

| Concept | Folder | File | Class |
|---|---|---|---|
| Entity | `domain/entities` | `expense_entity.py` | `ExpenseEntity` |
| Value Object | `domain/value_objects` | `money_value_object.py` | `MoneyValueObject` |
| Enum | `domain/enums` | `person_status.py` | `PersonStatus` |
| Virtual Object | `domain/virtual_objects` | `active_budget_virtual_object.py` | `ActiveBudgetVirtualObject` |
| Error | `domain/errors` | `expense_not_found_error.py` | `ExpenseNotFoundError` |
| Interface (port) | `application/interfaces` | `expense_repository_interface.py` | `ExpenseRepositoryInterface` |
| Implementation | `infrastructure/repositories` | `expense_repository.py` | `ExpenseRepository` |
| Use case | `application/use_cases` | `record_expense_use_case.py` | `RecordExpenseUseCase` |
| Data (command/output) | `application/data` | `record_expense_data.py` | `RecordExpenseData` |
| Mapper entity↔model | `infrastructure/mappers` | `expense_model_mapper.py` | `ExpenseModelMapper` |
| Mapper entity→data | `application/mappers` | `expense_data_mapper.py` | `ExpenseDataMapper` |
| Model (table) | `infrastructure/models` | `expense_model.py` | `ExpenseModel` |

**Non-negotiable rules:**
- **`abc.ABC` + `@abstractmethod` for all interfaces.** No duck typing.
- **Never the lib's name in file or class.** `ExpenseRepository`, never `SqlAlchemyExpenseRepository`.
- **No abbreviations.** `value_objects` not `vos`; `MoneyValueObject` not `MoneyVO`.
- **No import aliases.** Never `import datetime as dt` or `from argon2 import PasswordHasher as Argon2PasswordHasher`. When a name would collide, import the **module** and qualify: `import argon2` → `argon2.PasswordHasher()`.
- **A dedicated mapper at every boundary** — always its own class, never inline.
- **Value objects must earn their existence.** Create a VO only when it enforces an invariant or carries behavior (validation, normalization, domain operation). A plain hash or opaque token is a `str` — primitive-wrapping is over-engineering. Symmetry is not a reason.
- **One concept per file.** Every VO, enum, error, port, use case, mapper: its own file. Tests obey the same rule.
- **Enums live in `domain/enums/`, never `value_objects/`.** No suffix in file or class (`person_status.py` → `PersonStatus`). When an enum grows an invariant, it graduates to a value object.
- **Do not use `in`/`out` in `data` names.** The request/response direction is web-layer only.

### The flow of a datum

```
Request → [RequestMapper] → Data → UseCase → Entity → [ModelMapper] → Model → DB
DB → Model → [ModelMapper] → Entity → [DataMapper] → Data → [ResponseMapper] → Response
```

### Mapper conventions

- **One class per boundary**, named after its destination: `PersonDataMapper`, `PersonModelMapper`.
- **Methods named `to_<target>`:** `to_data`, `to_entity`, `to_model`, `to_response`. Bidirectional mappers (`ModelMapper`) carry both on the same class.
- **`@staticmethod` by default** — mappers hold no state. Call as `PersonDataMapper.to_data(person)`.
- **No abstract base, no generic `Mapper[IN, OUT]`.** `abc.ABC` is reserved for ports. Concrete signatures give better type-safety than a generic `map()`.

### Repositories

- Interface in `application/interfaces`; implementation in `infrastructure/repositories`.
- Always receive/return domain entities; use `ModelMapper` internally.
- **Soft-delete is the repository's responsibility** — normal reads exclude `deleted_at IS NOT NULL`; only `list_including_removed` sees everything.
- `find_in_range(person, start, end)` on `ExpenseRepository` derives the expense→budget belonging with no FK.

### Determinism ports

Never call `uuid`/`datetime` inside an entity. Inject two ports into use cases:
- `IdentifierProviderInterface` → `async def generate() -> str` — adapter uses `uuid.uuid7()` (Python 3.14 stdlib, time-ordered)
- `ClockInterface` → `async def now() -> datetime` (timezone-aware)

The **entity factory** (e.g. `PersonEntity.create(...)`) is the only sanctioned constructor — fixes initial state so no caller can build an entity in an illegal state. **Entities are equal by `id`** — implement `__eq__`/`__hash__` on `id`.

### Domain error messages

Short, user-facing, **pt-BR**, must not leak sensitive data. Never echo the offending value: `EmailAlreadyInUseError` → `"E-mail já está em uso."` (never the address). Non-sensitive facts are fine (`WeakPasswordError` may state minimum length).

---

## The web edge (Litestar)

Litestar is the **inbound adapter** — lives under `features/<ctx>/infrastructure/http/` and the composition root only. `domain/`/`application/` never import it. **No `presentation/` layer.**

**HTTP-adapter shape per feature:**
```
infrastructure/http/
  controllers/   budget_controller.py      BudgetController(Controller): path="/budgets"
  requests/      create_budget_request.py  CreateBudgetRequest  (Pydantic v2)
  responses/     budget_response.py        BudgetResponse       (Pydantic v2)
  mappers/
    requests/    create_budget_request_mapper.py
    responses/   budget_response_mapper.py
  errors/        <feature>_status_error.py  <FEATURE>_STATUS_ERROR
```

**Controller rules:**
- Class controller, `path` on the class, one decorated method per operation. `@post()` → **201** by default.
- **Body parameter MUST be named `data`** — Litestar's reserved kwarg. Anything else silently breaks binding (500).
- Controller only binds, maps, delegates, frames — no business logic.
- Pydantic v2 DTOs with `Field(description=, examples=)` + model-level example for self-documenting OpenAPI.

**DI — native and layered:**
- Litestar's own DI, injected by name; mark with `NamedDependency[...]`.
- **App layer:** cross-cutting only — shared-kernel gateways via `register_core()`.
- **Each feature contributes a `Router`** with scoped providers — dependency keys never collide. Fresh `build()` ⇒ fresh singletons ⇒ isolated test apps.
- No Rodi, no global container.

**Versioning & docs:**
- All routes under `/v1` prefix owned by the composition root.
- OpenAPI at `/schema`; Swagger UI at `/schema/swagger`.

**Composition root** — `core/infrastructure/http/app.py::build()` returns a fresh `Litestar` per call.

---

## HTTP errors — unified envelope, pt-BR

Every error response is one shape:
```json
{ "status": 409, "code": "overlapping-budget", "message": "Já existe um orçamento neste período." }
{ "status": 422, "code": "validation", "message": "Dados inválidos.",
  "errors": [{ "key": "amount", "message": "Deve ser um número decimal." }] }
```
`errors` is **optional**, present only for field-level errors; serialize with `model_dump(exclude_none=True)`.

**Layered, mirroring the DI:**
- **Feature domain errors → scoped to the feature's `Router`.** Each feature owns `dict[type[Exception], int]` (`<FEATURE>_STATUS_ERROR`) containing **only its own errors**, unit-tested in plain Python. `code` ← class name in kebab (drop `Error`/`Exception`); `message` ← `str(exc)`. Table must cover every error the feature's handlers can raise — none falls through to a 500.
- **Core domain errors → app layer**, via `build_core_exception_handlers(CORE_STATUS_ERROR)`. Errors that can fire from any feature's handler (e.g. `InvalidMoneyError`, `InvalidSessionError`) live in `CORE_STATUS_ERROR` and are registered once at the app. Feature tables must **not** duplicate them.
- **Cross-cutting framework errors → app layer.** `ValidationException` → 422 with pt-BR per-field messages (translated from Pydantic `type`, never its English text). `HTTPException` fallback frames all framework HTTP errors in the same envelope with pt-BR message from status — never echo the framework's English `detail`.

**`errors/` layout:**
```
core/infrastructure/http/errors/
  responses/    error_response.py · error_detail_response.py
  handlers/     exception_handlers.py
  validations/  messages_validation.py   validation_message(pydantic_type) -> pt-BR
  http/         messages_http.py         http_message(status) -> pt-BR
  lookups/      error_code.py · core_status_error.py
```

**Transitional identity:** until real auth lands, `person_id` is a fixed placeholder in the request→command mapper. Replacing it is its own OpenSpec change.

---

## Testing conventions

- **One test file per unit, mirroring the source tree.** Never group multiple units in one file.
- **Use-case integration tests** — `tests/<context>/integrations/test_<verb>_<name>_integration.py`. Wire real adapters in pure Python, no HTTP server.
- **HTTP integration tests** — `tests/<context>/integrations/http/test_<resource>_http.py`. Drive real Litestar app via `TestClient(app=build())`. Controller has **no standalone unit test** — only these cover it.
- **Pure web pieces** (error→status table, `error_code`, pt-BR lookups) — plain-Python unit tests under `tests/<ctx>/infrastructure/http/errors/`.
- **Fakes** — `tests/<context>/fakes/fake_<name>.py` → `Fake<Name>`. **Prefer hand-written fakes over mocks** for ABC ports (mypy verifies the contract). Use `AsyncMock` only for simple stubs.
- `tests/` is a package (`__init__.py` throughout), `pythonpath = ["."]`. Async driven with `asyncio.run(...)`.
- **Load/stress tests** — `tests/stress/test_<flow>.py`, Locust `HttpUser` class, **not a pytest class**. `poe stress` runs headless (50 users, 5/s ramp-up, 60 s). `poe check` never includes it.

---

## Current build stage

**Web edge live on Litestar; ORM deferred.** A feature ships as a vertical slice: `domain/` + `application/` ports + in-memory repositories + real gateways + Litestar HTTP edge. No `Model`/`ModelMapper` until the ORM is chosen.

**Live:** identity HTTP edge (sign-up / sign-in / sign-out; Bearer token; 401 on missing/invalid token) + `POST /v1/budgets` + expenses HTTP edge (`POST`, `GET`, `PATCH`, `DELETE /v1/expenses`).  
**Deferred:** ORM/persistence and remaining HTTP endpoints (budgeting read/edit, pairing).

---

## Guardrails — commands & skills

| Tool | Kind | What it does |
|---|---|---|
| `/trocado:feature` | command | Feature flow spec-first: propose → scaffold → implement → guard → archive |
| `/trocado:endpoint` | command | Expose a use case over HTTP spec-first: propose → web-endpoint scaffold → guard |
| `/trocado:guard` | command | Audit diff against all non-negotiable rules → **PASS** / **CHANGES REQUIRED** |
| `feature-scaffold` | skill | Generate domain/application/infrastructure skeleton. **Refuses without an OpenSpec change.** |
| `web-endpoint` | skill | Scaffold Litestar HTTP edge (controller, DTOs, mappers, router, error table). **Refuses without an OpenSpec change.** |
| `feature-tests` | skill | Scaffold test suite: unit tests, fakes, use-case integration, HTTP integration |
| `load-test` | skill | Scaffold Locust `HttpUser` scenario in `tests/stress/` |
| `architecture-guard` | skill | Deep rule audit: async, dependency direction, naming, derive-don't-store, money, soft-delete, auth, web edge, test layout |
| `/trocado:stress` | command | Scaffold Locust scenario or run `poe stress` (requires `poe serve`) |

OpenSpec workflow: `openspec-explore`, `openspec-propose`, `openspec-apply-change`, `openspec-archive-change`.

---

## Stack and commands

Pure Python domain. Toolchain:
- **UV** — sole dependency manager; `uv.lock` committed; `requires-python = ">=3.14"`
- **Ruff** (lint + format), **pytest**, **mypy `--strict`**, orchestrated by **poethepoet**

| Command | Does |
|---|---|
| `uv sync` | recreate env from lockfile |
| `uv run poe check` | all gates: format-check → lint → mypy → pytest |
| `uv run poe lint` / `format` / `type` / `test` | single gate |
| `uv run poe serve` | uvicorn on `127.0.0.1:8000`, hot reload; Swagger at `/schema/swagger` |
| `uv run poe stress` | headless Locust (50 users, 5/s ramp-up, 60 s); requires `poe serve` |
| `uv add <pkg>` / `uv add --dev <pkg>` | add runtime / dev dependency |

Runtime deps: `argon2-cffi`, `litestar`, `pydantic`, `uvicorn`.  
Dev deps: `locust`, `pytest`, `mypy`, `ruff`.
