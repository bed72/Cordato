# Trocado / Cordato

A personal-finance tool for **couples** that refuses to dissolve the individual into the relationship.
Each person owns their own money, budgets, and expenses. When two people pair up, a **shared view**
emerges on top of the individual data — a lens, not a merge. If the pair breaks up, the lens disappears
and each one keeps everything they had, intact.

> If you remember only one thing: **a couple is a point of view, not an owner.**

The three tensions kept on purpose:
- **Individual by default.** Every datum belongs to exactly one person.
- **Shared by consent.** Pairing adds a *read* perspective over two individuals.
- **Reversible without loss.** Unpairing never destroys nor moves anyone's data.

---

## Non-negotiable process rule: spec first, always

> If you remember only one thing here: **no line of a feature is born without an OpenSpec spec tied to it.**

**Every single feature — no exceptions — requires an approved OpenSpec change before any code.**
There is no "feature too small", no "obvious fix that skips the spec", no "I'll document it later".
The spec is the contract that precedes the implementation; the code is its consequence, never the other way around.

The flow is always, in this order:
1. **Propose** the change in OpenSpec (spec deltas + design + tasks) — use the `openspec-propose` skill
   (explore first with `openspec-explore` when the requirement is still fuzzy).
2. **Review and approve** the proposal — the spec describes *what* and *why* before *how*.
3. **Implement** following the change's tasks — `openspec-apply-change`.
4. **Archive** the change once complete — `openspec-archive-change`.

Rules that follow from this:
- **No spec, no PR.** Feature code without a corresponding change is work to be rejected, not reviewed.
- **The spec is the source of truth for behavior.** A divergence between code and spec is a bug in the spec
  *or* in the code — never "the spec is outdated, ignore it". Update the spec in the same change.
- **Behavior change = new change.** Altering a domain rule, a lifecycle, or an API contract starts with an
  OpenSpec change, not with a diff.
- Low-risk exceptions (pure refactor with no behavior change, build/infra tweaks, typo fixes) are not
  features and do not require a change — but when in doubt, **propose the change**.

> **Tooling that enforces this:** the `/trocado:feature` command drives the flow spec-first, and the
> `feature-scaffold` skill **refuses to generate code** unless an OpenSpec change covers it. See
> [Guardrails — commands & skills](#guardrails--commands--skills).

---

## Central modeling principle: derive, don't store

The reference graph is **deliberately flat**. Add a link only when the relationship is an
**intrinsic fact of ownership** (a person owns a budget), never for the convenience of a query.

> Prefer an **association derived from an attribute** (e.g., date containment) over a **stored reference**,
> whenever the association can be recomputed cheaply and would otherwise require maintenance on every change.
> **Store events; compute groupings.**

This principle already appears **three times** in the domain (expense→budget, budget-default, couple budget).
That repetition is the sign that the model is consistent with itself — keep it.

### The association that deliberately does NOT exist: `Expense ──╳── Budget`

An expense does **not** point to a budget. It belongs to a budget **dynamically**, by falling within
the budget's date range. The association is **computed at read-time, never stored**.

Why (preserve this reasoning):
1. **No rewiring.** Editing a budget's dates, deleting it, or creating another never touches an expense.
2. **An expense is a fact, not a filing.** The spend happened on a date, for an amount, by someone —
   a truth independent of how budgets are sliced afterward.
3. **No orphans, no dangling links, no double counting.** A derived link never goes stale.
4. **The same lightness scales to the shared view.**

---

## Stored entities

All have `id` (opaque identity — the ledger's anchor) and `created_at`.

### Person
`id`, `created_at`, `email` (unique), `name`, `password` (**stores the HASH — Argon2/bcrypt — never plaintext**),
`status` (`active` / `deleted`).
- Owns N Budget, N Expense, N InviteCode; is in ≤1 active Pair.
- **Hard-delete** (the domain's only physical deletion) — see Lifecycles.

### Budget
`id`, `created_at`, `person_id`, `amount` (exact decimal, cents, **BRL**), `start_date`, `end_date`
(inclusive on both ends, **date only — no time**), `note` (optional), `deleted_at` (**soft-delete**).
- Individual, always points to one Person. **Has no list of expenses** — spend is computed.
- **Non-overlap invariant:** two *live* budgets of the same person share no date, not even the
  boundary day (A ends on the 15th, B starts on the 16th ✅; B starts on the 15th ❌).
  This rule is what makes "the active budget" and date-based belonging **unambiguous**.

### Expense
`id`, `created_at`, `person_id` (who spent — that's all), `amount` (exact decimal), `occurred_on`
(the day the spend happened — **date only, no time**), `description` (optional), `deleted_at` (**soft-delete**).
- **Zero link to Budget.** Belonging is purely date-range.
- The day-field is named `occurred_on` (not `date`) — intention-revealing, and it avoids shadowing the
  `date` type so the entity imports `from datetime import date, datetime` plainly (per "No import aliases").

### Pair
`id`, `created_at`, `person_a_id`, `person_b_id`, `deleted_at` (**soft-delete** = dissolved).
- **Owns no money, no budget, no expense.** A thin link between two individuals, only to enable the view.
- **Invariant:** a person is in ≤1 pair with `deleted_at = null`. N dissolved ones in history is fine.

### InviteCode
`id`, `created_at`, `creator_id`, `code` (short token, **generated by a CSPRNG — a cryptographic source, never predictable**),
`expires_at` (~1 day), `consumed_at` (null = unused).
- Accepting a valid code (not expired, not consumed) → creates the Pair and sets `consumed_at`. Single-use.

---

## Virtual objects — computed at read-time, NEVER stored

- **Active budget (enriched):** the live budget whose range contains today + `total_spent`
  (sum of the owner's expenses in the range) + `remaining`.
- **Default budget ("No budget"):** a bucket fabricated on the fly to group the owner's expenses that
  fall into no real budget. Resolves the nullability in the application, with no row in the database.
- **Couple budget (combined view):** the period `[min(starts), max(ends)]` of both partners' active budgets,
  amount = sum, spend = sum. **A panorama lens, deliberately approximate** — the exact truth lives
  in the individual views. NOT an entity; the pair owns nothing.
- **Couple expenses:** the union of both partners' expenses, each marked `mine` / `theirs` for the current reader.

### Where they live: `domain/virtual_objects/` — a category of its own (not an entity, not a value object)

When one of these read-time views is modeled as a class, it is a **Virtual Object** and lives in
`domain/virtual_objects/` (`active_budget_virtual_object.py` → `ActiveBudgetVirtualObject`). It is pure
domain — the derivation (e.g. `remaining = amount − total_spent`) is a domain rule — but it is **neither
an entity nor a value object**, and forcing it into either is wrong:

| | Own identity (`id`) | References an entity? | Validates a value | Persisted |
|---|---|---|---|---|
| **Entity** | yes — the ledger anchor | — | — | yes |
| **Value Object** | no (equal by value) | **never** (breaks value semantics) | yes (invariant/normalization) | no |
| **Virtual Object** | no | **yes — that is its job** | no — it **composes + derives** | no — computed at read-time |

A Virtual Object is a **read-time projection over stored state**: it may hold an entity and carry derived
behavior, has no identity or lifecycle of its own, and is **never stored** (no row, no `Model`). It feeds a
dedicated `application/data` read-model through its own mapper, exactly like an entity does — keeping money
math in the domain instead of leaking into the mapper. This is the third domain shape; it earns the same
"one concept per file" and naming rigor as the other two.

---

## Lifecycles and the "no data loss" guarantee

### Dissolve a pair
Removes only the *shared view* (soft-delete of the Pair). Both keep every budget and expense intact.
The product goes back to behaving like two unpaired individuals who have history.

### Delete the account (hard-delete — the nuclear option)
A single, atomic, guarded action (requires re-confirming identity: a live session **and** the password). **No restore.**
The flat graph is what makes this **safe**: no one references a person's data besides themselves
(the pair owns nothing; the partner only had a *view*). So, in one indivisible operation:
- invalidate the session, verify the password against the hash;
- **physically delete (cascade) the person's budgets and expenses**;
- **neutralize the old account's email** (e.g., `deleted+<id>@…`), freeing the email for reuse;
- set `status = deleted` (no longer authenticates);
- **dissolve** any active pair as a consequence.
- Reusing the email creates a **new** Person (new id, empty ledger) — it does not resurrect the old one.

### Day-to-day soft-delete
`delete` on Budget/Expense/Pair = **soft-remove** (`deleted_at`, disappears from normal views; visible in
audit). Mistake recovery + audit trail. **Exception:** *account* deletion is physical (above).

---

## Cross-cutting expectations

- **Per-person authorization.** Each person reads/mutates only their own data, except for the pair's
  explicit shared views — which are **read-only** (pairing grants no write over the partner's data).
- **Money and dates are first-class.** Amounts in **exact decimal** (never float). Budget belonging is
  pure date-range logic. Keep both precise.
- **Derived numbers are cacheable but never authoritative.** `total_spent`, `remaining`, and the couple
  aggregates come from the events. **Current decision: NO cache** (a couple = little data, the sum is instant).

---

## Parking lot (decide later)

- **Joint couple goal:** if one day the couple wants to define a *genuine* joint budget (a new intent,
  not derivable from the individual ones), then it would be its own stored entity, with its own lifecycle.
  **Out of scope for now.**
- **Timezone/time in dates:** today we use pure `date` (no time). If timezone is ever needed, handle it later.
- **Postgres RLS as a defense-in-depth backstop (NOT a replacement for app authorization):** when Postgres
  lands, Row Level Security may be added as a *second wall* behind the repository — belt-and-suspenders, not
  the source of truth. Authorization stays a **domain rule**, expressed in `domain/`/repositories and tested
  in pure Python; RLS lives entirely at the infra edge, **behind the existing ports**, touching neither
  `domain/` nor `application/`. Two reasons it must not become the primary auth layer: (1) the **couple lens**
  is the core domain concept (*a couple is a point of view, not an owner*) — it is **not** `person_id =
  auth.uid()` but a `SELECT`-only policy joining **live** pairs (`deleted_at IS NULL`), never write over a
  partner's data; pushing it into SQL would invert the dependency rule (the innermost rule leaking to the
  outermost layer) and put it out of reach of the no-I/O domain tests. (2) `set local "auth.uid"` under an
  **async connection pool** is a real footgun (identity can leak across pooled connections unless scoped to
  the transaction and reset; PgBouncer transaction-mode complicates it). Decision: **adopt later, as
  defense-in-depth, via its own OpenSpec change** (it alters an infra contract + a cross-cutting behavior) —
  per-person policy on owned tables (`person_id = auth.uid()`, all ops) **plus** a separate `SELECT`-only
  couple-lens policy joining live pairs. Out of scope until the ORM/Postgres edge exists (deferred, not skipped).

---

## Architecture & conventions

Clean Architecture + tactical DDD + Ports & Adapters, in a **modular monolith**. The domain is
framework-independent and is tested without spinning anything up. The dependency rule always points
**inward**: `infrastructure → application → domain`. `domain/` imports nothing from outside.

### Async everywhere (non-negotiable)

**Every I/O boundary is `async`. No exceptions.** Anything that touches I/O — or orchestrates something
that does — is `async def` and is `await`ed end to end. There is no sync sibling, no "blocking version",
no `.run()` bridge buried in an adapter.

Concretely:
- **Ports (interfaces) are async by contract.** Repository ABCs declare `async def` methods returning
  awaitables. The contract is async, so every adapter is too.
- **Adapters (repositories, infra) are async.** They use the async driver/ORM API. No blocking call on
  the event loop; if a dependency is sync-only, it is wrapped off-loop (e.g., a thread executor) at the
  adapter edge — never leaked inward.
- **Use cases are async.** A use case that calls an async port is itself `async def`, all the way up.
- **Web handlers are async.** The whole request path is awaited.
- **Gather independent awaits.** Within a unit of work, when two or more awaited port calls are
  **independent** (no call consumes another's result), issue them together with `asyncio.gather(...)`
  instead of awaiting in sequence — e.g. `id, created_at = await asyncio.gather(identifier.generate(),
  clock.now())`. The use case thereby states the calls *may* overlap, honoring the async-maybe-I/O
  contract of the ports; the day an adapter becomes genuinely I/O-bound, the latency overlaps for free.
  Await **sequentially** only when there is a real **data dependency** (a later call uses an earlier
  result). And keep any short-circuiting **guard before** the gather — never pay for an expensive call
  (e.g. password hashing) that a prior check (e.g. email uniqueness) would have rejected.

The one place that stays **synchronous**: the **pure `domain/`** — entities, value objects, policies, and
domain services that do **no I/O**. They only compute over data already in memory, so there is nothing to
await; forcing `async` there would be empty ceremony and would break "the domain is pure Python, tested
without spinning anything up". **Async is about I/O, and pure domain has none.** The moment a domain
operation would need I/O, that I/O belongs to a port — and the port is async.

### Package organization (`src/trocado/`)
- `core/` — shared kernel: everything the other modules need. **Follows the same structure
  as a feature** (`domain/` · `application/` · `infrastructure/`).
- `features/<context>/` — one package per context (`expenses`, `budgeting`, `identity`,
  `pairing`). All follow the same format. **There is NO `shared/`.**

### Layers inside each module
- `domain/` → `entities/`, `value_objects/`, `enums/`, `virtual_objects/`, `errors/` (+ `policies/`, `services/` when present). Pure Python.
- `application/` → `interfaces/` (ports, ABC), `data/` (commands and read-models), `use_cases/`, `mappers/`, `services/`.
- `infrastructure/` → `models/`, `mappers/`, `repositories/`, `gateways/` (adapters). **The only place that knows the lib/ORM.**

> **Two buckets, by responsibility — never a folder per tool.** Infrastructure groups adapters by *what they
> are responsible for*, not by which library they use. There are exactly two homes, and the set does not grow
> as the feature grows:
> - **Persistence** → `repositories/` (+ `models/`, `mappers/`). The cluster that maps entity ↔ table.
> - **Everything else** → `gateways/`: every other outbound adapter implementing an application port —
>   password hasher, clock, identifier provider, and later email/SMS/push senders, token generators, event
>   publishers, payment gateways, etc. One file per adapter, flat inside `gateways/`.
>
> Do **not** create a folder per kind (`hashers/`, `providers/`, `clocks/`, `senders/`…). A new outbound
> capability is a new *file* in `gateways/`, not a new folder. This keeps `infrastructure/` flat and stable
> however large the module grows.

### Naming conventions (apply to ALL modules)
| Concept | Folder | File | Class |
|---|---|---|---|
| Entity | `domain/entities` | `expense_entity.py` | `ExpenseEntity` |
| Value Object | `domain/value_objects` | `money_value_object.py` | `MoneyValueObject` |
| Enum (closed domain set) | `domain/enums` | `person_status.py` | `PersonStatus` |
| Virtual Object (read-time view) | `domain/virtual_objects` | `active_budget_virtual_object.py` | `ActiveBudgetVirtualObject` |
| Error | `domain/errors` | `expense_not_found_error.py` | `ExpenseNotFoundError` |
| Interface (port) | `application/interfaces` | `expense_repository_interface.py` | `ExpenseRepositoryInterface` |
| Implementation | `infrastructure/repositories` | `expense_repository.py` | `ExpenseRepository` |
| Use case | `application/use_cases` | `record_expense_use_case.py` | `RecordExpenseUseCase` |
| Data (command/output) | `application/data` | `record_expense_data.py` / `expense_data.py` | `RecordExpenseData` / `ExpenseData` |
| Mapper entity↔model | `infrastructure/mappers` | `expense_model_mapper.py` | `ExpenseModelMapper` |
| Mapper entity→data | `application/mappers` | `expense_data_mapper.py` | `ExpenseDataMapper` |
| Model (table) | `infrastructure/models` | `expense_model.py` | `ExpenseModel` |

Non-negotiable rules:
- **Interfaces always via `abc.ABC` + `@abstractmethod`.** No duck typing — a signed, explicit contract.
- **Never the lib's name in the file or the class.** `ExpenseRepository`, never `SqlAlchemyExpenseRepository`. The tool stays hidden *inside* the file.
- **No abbreviations.** `value_objects` (not `vos`); `MoneyValueObject` (not `MoneyVO`).
- **No import aliases.** Never rename a symbol on import — no `import datetime as dt`, no
  `from argon2 import PasswordHasher as Argon2PasswordHasher`. Import the names plainly
  (`from datetime import date, datetime`) and call them by their real name; an alias is just an
  abbreviation in disguise and hides what is actually in scope. When the bare name would **collide**
  with a local one (e.g. the lib's `PasswordHasher` vs. our adapter `PasswordHasher`), import the
  **module** and qualify at the call site (`import argon2` → `argon2.PasswordHasher()`) — never reach
  for an `as` alias to dodge the clash.
- **A dedicated mapper at every boundary** — always its own class, never inline conversion.
- **A value object must earn its existence — no primitive-wrapping.** Create a value object only when it
  enforces an **invariant** or carries **behavior**: validation, normalization, or a domain operation
  (`EmailValueObject` validates + normalizes; `MoneyValueObject` is exact decimal; `PasswordValueObject`
  checks the policy and hides its plaintext). A class that merely stores a bare primitive with no rule
  (e.g. a password **hash**, an opaque token string) is **over-engineering — use the primitive (`str`) directly.**
  Symmetry is not a reason: it is fine for one concept to be a value object and a sibling to be a plain `str`.
- **One concept per file — simple and separated.** Every value object, enum, error, port, use case, and
  mapper lives in its own dedicated file (the `PersonStatus` enum → `domain/enums/person_status.py`;
  one error class per file under `domain/errors/`). Never bundle several related types into one module for
  convenience. **Tests obey the same rule** — see [Testing conventions](#testing-conventions).
- **An enum is its own domain shape — `domain/enums/`, never `value_objects/`.** A closed domain set
  (`PersonStatus`, `Perspective`) has no identity and is equal by value like a value object, but it
  **validates nothing and carries no behavior** — so by the "earn its existence" rule above it is *not* a
  value object. It is a category of its own: it lives in `domain/enums/`, the file and class carry **no
  suffix** (`person_status.py` → `PersonStatus`), and it stays pure (no I/O). The day an enum grows real
  behavior or an invariant, it graduates into a value object and moves to `value_objects/`.

> **Tooling that enforces this:** run `/trocado:guard` (the `architecture-guard` skill) on any diff to
> audit these rules — async boundaries, dependency direction, naming, the "never" rules, derive-don't-store,
> exact-decimal money, soft-delete, and authorization. See [Guardrails — commands & skills](#guardrails--commands--skills).

### The three data layers (each named after ITS own nature)
| Layer | Nature | Names |
|---|---|---|
| Web (controller) | request/response (validation, HTTP) | `RecordExpenseRequest`, `ExpenseResponse` |
| Application (`data`) | command / read-model | `RecordExpenseData`, `ExpenseData` |
| Domain | fact + rule | `ExpenseEntity`, `MoneyValueObject` |

- Input named after the **command** (plural, specific to the use case); output after what it **represents**.
- **Do not use `in`/`out`** in `data`: it implies a 1:1 symmetry that does not exist. The request/response direction lives only in the web layer.

### The flow of a datum (a dedicated mapper at each hop)
```
Request → [ExpenseRequestMapper] → Data → UseCase → Entity → [ExpenseModelMapper] → Model → DB
DB → Model → [ExpenseModelMapper] → Entity → [ExpenseDataMapper] → Data → [ExpenseResponseMapper] → Response
```

### Mapper conventions (concrete classes, NOT a generic `Mapper` interface)

A mapper is a **pure transformation between two layers' shapes** — `Entity → Data`, `Entity ↔ Model`,
`Request → Data`, `Data → Response`. It is the dedicated home for a hop in the flow above, and it follows
a fixed shape:

- **One dedicated class per boundary**, named after its *destination* shape:
  `PersonDataMapper`, `PersonModelMapper`, `PersonResponseMapper`, `PersonRequestMapper`. One per file,
  per the one-concept-per-file rule.
- **Methods named after the direction**, `to_<target>`: `to_data`, `to_entity`, `to_model`, `to_response`.
  A bidirectional mapper (typically the `ModelMapper`) carries both directions as two methods
  (`to_entity` / `to_model`) on the **same** class — never split into two classes.
- **`@staticmethod` by default.** A mapper holds no state and does no I/O, so it is a pure function and
  needs no `self`. Call it on the class: `PersonDataMapper.to_data(person)`. It only becomes an instance
  method (`__init__` + injected dependency) the day a transformation genuinely needs a collaborator —
  which for pure shape-mapping it does not.
- **No abstract base, no generic `Mapper[IN, OUT]` interface.** This is deliberate, and is the same
  "earn its existence / symmetry is not a reason" rule applied to mappers:
  - `abc.ABC` is **reserved for ports** — the I/O boundaries where an adapter actually swaps
    (in-memory ↔ ORM, fake ↔ Argon2). A mapper is not a port: there is no second adapter to plug in, so a
    contract would be ceremony over a boundary that does not move.
  - A generic `map(input: IN) -> OUT` buys **no** type-safety that mypy `--strict` does not already get
    from the concrete signature `to_data(person: PersonEntity) -> PersonData`.
  - A single `map()` cannot express the **multi-direction** mappers (`Entity ↔ Model`) and would force
    them to fragment into `EntityToModel` + `ModelToEntity`, losing the cohesive, directionally-named API.

  > Coming from a Kotlin/Java `interface Mapper<in IN, out Out>`: that abstraction pays for itself there
  > because it enables DI and polymorphic composition of mappers. Here mappers are static, concrete, and
  > called by name — the polymorphism it would abstract does not exist, so the concrete class is the
  > idiomatic choice.

### Repositories
- **Interface (port)** in `application`; **implementation (adapter)** in `infrastructure`.
- Always receive/return **domain entities**; use the `ModelMapper` internally.
- **Soft-delete is the repository's responsibility**: normal reads exclude `deleted_at != null`;
  only an explicit audit method (`list_including_removed`) sees everything.
- `find_in_range(person, start, end)` on the `ExpenseRepository` is the method that **derives** the
  expense→budget belonging — with no FK at all.

### Determinism, time, and identity (ports, never inside the domain)

The pure `domain/` must do no I/O **and** be deterministic under test, yet `id` and `created_at` are
non-deterministic. Resolve this with **two tiny application ports**, injected into the use case — never call
`uuid`/`datetime` inside an entity:
- `IdentifierProviderInterface` → `async def generate() -> str`. The adapter uses **`uuid.uuid7()`** (stdlib
  in Python 3.14): time-ordered, so the `id` primary key keeps good index locality when the ORM lands — at
  zero dependency cost. The id is an opaque `str`; the domain never inspects it.
- `ClockInterface` → `async def now() -> datetime` (timezone-aware).

The use case obtains `id` + `created_at` from these ports and passes them into the entity's factory. The
**entity factory** (e.g. `PersonEntity.create(...)`) is the only sanctioned constructor: it fixes the initial
state (e.g. `status = active`) so a caller can never build an entity in an illegal state. **Entities are equal
by identity** (`id`), not by field values — implement `__eq__`/`__hash__` on `id`.

### Domain error messages

Domain errors carry **short, user-facing messages in pt-BR**, and **must not leak sensitive domain data**.
Never echo the offending value into the message — revealing whether an email exists is account enumeration
(`EmailAlreadyInUseError` → `"E-mail já está em uso."`, never the address; `InvalidEmailError` →
`"E-mail inválido."`, never the input). Non-sensitive facts are fine (`WeakPasswordError` may state the
minimum length). The web layer frames it into the unified HTTP error envelope (see
[The web edge](#the-web-edge-litestar)); the domain only states the rule, generically.

### The web edge (Litestar)

The web framework is **Litestar** (chosen over FastAPI / BlackSheep for its **layered, native dependency
injection** and **class-based controllers** — and it dropped the extra Rodi container BlackSheep needed). It is
an **inbound (driving) adapter**: it lives only under `infrastructure/http/` and the composition root, may know
the lib, and **drives a use case** — the mirror of a repository. The inner `domain/`/`application/` never import
it; the framework-free, server-free testable unit stays the **use case**. There is **no `presentation/` layer**.

**HTTP-adapter shape** — per feature, under `features/<ctx>/infrastructure/http/`:
```
infrastructure/http/
  controllers/   budget_controller.py      class BudgetController(Controller): path="/budgets"; @post()
  requests/      create_budget_request.py  CreateBudgetRequest    (Pydantic v2 DTO)
  responses/     budget_response.py         BudgetResponse         (Pydantic v2 DTO)
  mappers/
    requests/    create_budget_request_mapper.py  CreateBudgetRequestMapper.to_data
    responses/   budget_response_mapper.py        BudgetResponseMapper.to_response
  errors/        <feature>_status_error.py  <FEATURE>_STATUS_ERROR  (pure error→status table)
```

Controller rules:
- Litestar-native class controller: `path` on the class, one decorated method per operation. `@post()` answers
  **201** by default. The class carries **no lib name** (`BudgetController`, never `LitestarBudgetController`).
- **The body parameter MUST be named `data`.** Litestar binds the validated body to the reserved `data` kwarg;
  `request` is also reserved (the ASGI `Request`). Naming the body anything else **silently breaks binding** and
  yields a 500.
- The controller only **binds, maps, delegates, frames** — no business rule: map the request DTO → the use
  case's `data`, `await` the use case, map the read-model → the response DTO.
- Request/response are **Pydantic v2** DTOs with `Field(description=, examples=)` + a model-level example, so the
  OpenAPI/Swagger schema is self-documenting.

**Dependency injection — native and layered (no separate container):**
- Litestar's own DI, resolved across layers (handler → controller → router → app), injected **by name**; mark an
  injected parameter with `NamedDependency[...]`.
- **App layer = cross-cutting only:** the shared-kernel gateways (`clock`, `identifier`) via `register_core()`.
- **Each feature contributes a `Router`** (its `main/<feature>_factory.py`) carrying its own controllers **and**
  its **scoped** providers — so a feature's dependency keys can never collide in a global namespace. App-scoped
  singletons (the in-memory repository) are a `Provide` over one instance built in the factory (a closure);
  use cases are **per-request**. A fresh `build()` ⇒ fresh singletons ⇒ isolated test apps.
- **No Rodi, no global container.** The composition root never even imports a feature's controller — the
  feature's router encapsulates it.

**Versioning & docs:**
- Every route is mounted under a single **`/v1`** prefix owned by the composition root (a controller declares
  only its bare resource path → `/v1/budgets`). A new API version is a new parent `Router`, not an edit across
  controllers — versioning is a cross-cutting transport concern.
- OpenAPI at `/schema`, **Swagger UI** at `/schema/swagger`, configured with title/version/description and a
  resource `Tag` per controller.

**Composition root** — `core/infrastructure/http/app.py::build()` returns a **fresh `Litestar` per call**:
app-layer `dependencies = register_core()`, `route_handlers = [Router("/v1", [register_<feature>(), …])]`, the
cross-cutting `exception_handlers`, and the OpenAPI config. `__main__.py` serves it via uvicorn — pass the app as
an **import string** so `--reload` works; `uv run poe serve` runs it with hot reload.

### HTTP errors — one unified envelope, pt-BR, layered like the DI

Every error answers in **one consistent JSON envelope** — the shape never varies by error kind:
```json
{ "status": 409, "code": "overlapping-budget", "message": "Já existe um orçamento neste período." }
{ "status": 422, "code": "validation", "message": "Dados inválidos.",
  "errors": [{ "key": "amount", "message": "Deve ser um número decimal." }] }
```
- `status` (HTTP), `code` (a stable, programmatic id of the error kind), `message` (**pt-BR**), and an
  **optional** `errors` (`[{key, message}]`) present **only** for field-level errors, omitted otherwise
  (handlers serialize with `model_dump(exclude_none=True)`).
- Wired via Litestar's **native `exception_handlers`** — *not* the Problem Details plugin (it produced an
  inconsistent shape and a low-value `type` URI). These lookups are **pure functions, not mappers** (a mapper is
  a transform between two *layers'* shapes; these are intra-layer key→value translations).

Layered, mirroring the DI:
- **Domain errors → scoped to the feature's `Router`.** Each feature owns a **pure, framework-free**
  `dict[type[Exception], int]` table (`<FEATURE>_STATUS_ERROR`), unit-tested in plain Python. Its factory builds
  the handlers from `{**CORE_STATUS_ERROR, **<FEATURE>_STATUS_ERROR}` (so shared-kernel errors it raises, like
  `InvalidMoneyError`, are framed where they occur) and registers them on its own router. The table must be
  **total** over the errors reachable at the boundary — none falls through to a 500. `code` ← the error class
  (kebab, `Error`/`Exception` suffix dropped); `message` ← the domain's own pt-BR `str(exc)`.
- **Cross-cutting → at the app layer.** `ValidationException` → **422** with pt-BR **per-field** messages
  (translated from the Pydantic error `type`, never its English text); an `HTTPException` fallback frames every
  framework-raised HTTP error (malformed JSON 400, unknown route 404, wrong method 405) in the **same** envelope
  with a pt-BR message derived from the **status** — never echoing the framework's English `detail` (which can
  leak parser internals like a byte offset).

`errors/` is organized **by role** (each its own subfolder, mirroring the http edge):
```
core/infrastructure/http/errors/
  responses/    error_response.py · error_detail_response.py   envelope DTOs (ErrorResponse, ErrorDetailResponse)
  handlers/     exception_handlers.py    build_domain_/build_core_exception_handlers  (the only framework-aware piece)
  validations/  messages_validation.py   validation_message(pydantic_type) -> pt-BR
  http/         messages_http.py         http_message(status) -> pt-BR
  lookups/      error_code.py · core_status_error.py   error_code(error) -> code · CORE_STATUS_ERROR
```

**Transitional identity:** until real auth lands, the acting `person_id` is a **fixed placeholder** in the
request→command mapper (no real authorization). Replacing it (a request-scoped `X-Person-Id`, then a validated
session token) is its **own** OpenSpec change and touches neither controller nor use case.

### Testing conventions

Tests are first-class and follow the same separation as production code:
- **One test file per unit, mirroring the source tree** — `tests/<context>/domain/value_objects/test_email_value_object.py`,
  `.../errors/test_invalid_email_error.py`, `.../infrastructure/repositories/test_person_repository.py`.
  Never a grouped `test_value_objects.py` covering several units at once.
- **Integration tests live at the test-module root** in `tests/<context>/integrations/` — they cross layers
  (real adapters wired through a use case), so they belong to no single layer.
- **Fakes/doubles in their own files** under `tests/<context>/fakes/`, one per file
  (`fake_person_repository.py` → `FakePersonRepository`). **Prefer hand-written fakes over mocks** for ABC
  ports: mypy verifies they satisfy the contract, and they carry real behavior. Reach for `unittest.mock`
  (`AsyncMock`) / `pytest-mock` only for simple stubs or interaction checks.
- `tests/` is a package (`__init__.py` throughout) with `pythonpath = ["."]`, so fakes are importable across
  test modules. Async is driven with `asyncio.run(...)` (no extra plugin).
- **Web edge:** the controller is a framework adapter, so it has **no standalone unit test** — its behavior is
  covered by an **HTTP integration test** through Litestar's `TestClient` against `build()` (the real app), in
  `tests/<ctx>/integrations/` (status, the unified error envelope, the in-memory store persisting across requests
  in one run). The **pure** web pieces — the error→status table, `error_code`, the pt-BR message lookups — get
  their own plain-Python unit tests mirroring the source (`tests/<ctx>/infrastructure/http/errors/...`), no server.

### Current build stage (transitional)

The **web edge is live on Litestar** (see [The web edge](#the-web-edge-litestar)); the **ORM is still deferred**.
So a feature ships as a **runnable, fully-tested vertical slice**: pure `domain/` + `application/` ports + an
**in-memory** `repositories/` adapter + real `gateways/` (e.g. an Argon2 password hasher whose sync call is
wrapped with `asyncio.to_thread` at the adapter edge) + a **Litestar HTTP edge** wired through the composition
root. **No `Model`/`ModelMapper` until the ORM is chosen** — they bridge a table that does not exist yet
(deferred, not skipped). When the ORM lands it slots in behind the existing ports without touching `domain/` or
`application/`. **Still deferred:** the **ORM/persistence**, real **authentication** (the acting `person_id` is a
fixed placeholder — no real authorization yet), and the remaining features' endpoints.

### Guardrails — commands & skills

The rules above are not just documentation; they are enforced by tooling under `.claude/`. Reach for these
instead of re-checking the rules by hand:

| Tool | Kind | Guarantees |
|---|---|---|
| `/trocado:feature` | command | Drives a feature **spec-first**: OpenSpec change → scaffold → implement → guard → archive. The entry point for any new work. |
| `/trocado:endpoint` | command | Exposes an existing use case over HTTP the **spec-first** way: OpenSpec change → `web-endpoint` scaffold (Litestar controller + DTOs + mappers + router wiring + error map) → guard. |
| `/trocado:guard` | command | Audits the current diff against every non-negotiable rule — domain **and the web edge** — and returns **PASS** / **CHANGES REQUIRED**. |
| `feature-scaffold` | skill | Generates a feature's `domain`/`application`/`infrastructure` skeleton in the canonical layering, naming, async ABC ports, dedicated mappers, `gateways/` bucket, determinism ports, and one-concept-per-file. **Refuses to scaffold without an OpenSpec change** — this is how spec-first is enforced at code-gen time. |
| `web-endpoint` | skill | Scaffolds the **Litestar** HTTP edge for a use case: native class controller (body bound to `data`, 201 by default), Pydantic request/response DTOs with OpenAPI docs, dedicated request/response mappers, the feature `Router` with **scoped** native DI + `/v1` mount, and the feature's pure error→status table with **router-scoped** handlers in the unified pt-BR envelope. **Refuses without an OpenSpec change.** |
| `feature-tests` | skill | Scaffolds a feature's test suite to the project's testing conventions: one file per unit mirroring the source, fakes in their own files, integration tests at the module root (incl. the HTTP edge via `TestClient`), fakes-over-mocks for ABC ports. |
| `architecture-guard` | skill | Reads code/diff and reports violations (spec-first, async everywhere, dependency direction, naming, no lib names, dedicated mappers, derive-don't-store, exact-decimal money, soft-delete, per-person authorization, one-concept-per-file, value-object-earns-existence, `gateways/` bucket, determinism ports, pt-BR non-leaking error messages, the **web edge** — Litestar confinement, `data`-bound body, layered/router-scoped DI & error handlers, `/v1` prefix, unified error envelope, `errors/` layout — and test layout), grouped by severity. |

Plus the OpenSpec workflow skills the process rule depends on: `openspec-explore`, `openspec-propose`,
`openspec-apply-change`, `openspec-archive-change`.

## Stack and commands

Domain in **pure Python** (no framework). Toolchain (capability `dev-environment`):

- **UV** is the sole project/dependency manager; `uv.lock` is committed; `requires-python = ">=3.14"`.
- **Ruff** (lint + format), **pytest**, **mypy `--strict`**, orchestrated by **poethepoet**.
- Quality gate — run before every commit and in CI:

| Command | Does |
|---|---|
| `uv sync` | recreate the env from the lockfile |
| `uv run poe check` | **all gates in sequence** (format-check → lint → mypy → pytest) |
| `uv run poe lint` / `format` / `type` / `test` | a single gate |
| `uv run poe serve` | run the app locally (uvicorn on `127.0.0.1:8000`, hot reload; Swagger at `/schema/swagger`) |
| `uv add <pkg>` / `uv add --dev <pkg>` | add a runtime / dev dependency |

Runtime deps so far: `argon2-cffi` (password hashing); **`litestar` + `pydantic` + `uvicorn`** (the web edge).
The web framework is **decided: Litestar** (see [The web edge](#the-web-edge-litestar)). **Still deferred:** the
ORM, and real **auth** (JWT vs server-side session) — they enter only at the edge behind existing ports. See
[Current build stage](#current-build-stage-transitional).
