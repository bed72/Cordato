# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Cordato is a Kotlin backend at the design stage: the domain model is documented in READMEs, but only
`Main.kt` (an unmodified IntelliJ template stub) and the Konsist architecture test exist as code. There
is no `core/` module and no application/infrastructure layers yet. When implementing a feature, follow
the package/layer conventions below rather than inferring them from existing code.

## Spec-Driven Development — no feature without a spec

**This project follows Spec-Driven Development (SDD) via OpenSpec. No feature or change to domain
behavior may be implemented without an approved spec first. This is a hard rule, not a preference.**

Concretely, before writing any production code that adds or changes behavior:

1. There MUST be an OpenSpec change with its artifacts (`proposal.md`, `design.md`, `tasks.md`) created
   and reviewed. Create it with `/opsx:propose` (or `openspec new change <name>`); think first with
   `/opsx:explore` if the shape is unclear.
2. Implement only by working the tasks of an existing change — use `/opsx:apply`. Keep changes scoped to
   the tasks; if implementation reveals a gap, stop and update the spec, don't improvise behavior.
3. After implementation, reconcile the specs (`/opsx:sync`) and archive the change (`/opsx:archive`).

If asked to build a feature with no corresponding change, do NOT start coding: create (or ask to create)
the OpenSpec change first, then implement against it. Explore mode (`/opsx:explore`) is for thinking and
authoring artifacts only — never for writing production code.

What does NOT require a spec: non-behavioral chores — build/tooling/config, formatting, docs/READMEs,
and tests for already-specified behavior. When in doubt about whether something is "a feature," treat it
as one and write the spec.

Tooling: the `openspec` CLI (v1.4.1) is installed and the workflow lives in `.claude/skills/openspec-*`
and `.claude/commands/opsx/*`. OpenSpec must be initialized in the repo (`openspec init --tools claude`,
which creates the `openspec/` directory) before the commands work — do this once if `openspec/` is
absent.

## Commands

Build tool is Gradle (Kotlin DSL), Kotlin JVM plugin 2.3.21, JVM toolchain 25.

- Build: `./gradlew build`
- Run all tests: `./gradlew test`
- Run a single test class: `./gradlew test --tests "com.bed.cordato.features.identity.SomeTest"`
- Test framework: `kotlin("test")` on JUnit Platform (`useJUnitPlatform()`).

- Run the app: `./gradlew run` (the `application` plugin is configured, main class `com.bed.cordato.main.MainKt`).
  It boots the embedded Netty server after migrating the DB, so it needs a reachable PostgreSQL — `make db-up` first.

## Architecture

The domain design lives in `README.md` at the repo root plus one `README.md` per bounded context under
`src/main/kotlin/com/bed/cordato/features/<context>/`. Read those before changing domain behavior — they
are the source of truth for business rules, not this file. What follows is the structural skeleton that
ties them together.

### Module shape

- `core/` (not yet created) is the **shared kernel**: things every module needs — exact money
  arithmetic, determinism ports (clock, id generation). It follows the same three-layer structure as a
  feature.
- `features/<context>/` is a **bounded context**, one package per context, all with the same internal
  shape. There is deliberately no `shared/` package — cross-cutting code belongs in `core/`.
- The four contexts today: `identity` (the person — ledger anchor), `expense` (the atomic spend fact),
  `budget` (planned ceiling per date range, with derived spent/remaining), `couple` (a read-only pairing
  lens between two people).

### Three layers per module, dependencies point inward

```
infrastructure → application → domain
```

| Layer | Contents | Knows about the library/framework? |
|---|---|---|
| `domain/` | `entities/`, `value_objects/`, `virtual_objects/`, `enums/`, `errors/` — pure, synchronous code | never |
| `application/` | grouped by hexagon direction: `driving/` (`use_cases/`, `commands/`, `results/`) + `driven/` (`ports/`, `repositories/`, `outcomes/`), with `mappers/` neutral at the root — see below | no |
| `infrastructure/` | `repositories/` (+ `models/`, `mappers/`) and `adapters/` (everything else external) | only here |

`domain/` never imports anything from outside itself.

### Class naming — every type carries its category suffix

Type names are composed as `<Meaning><Category>`, where the suffix names the architectural
building block, matching the folder it lives in: `PersonEntity` (entities), `EmailValueObject`
(value_objects), `PersonStatusEnum` (enums), `SignUpError` (errors), `SignUpCommand` (command),
`SignUpResult` (result), `UpdateEmailOutcome` (outcomes), `SignUpUseCase` (use_cases),
`ClockPort`/`PasswordHasherPort` (ports), `SystemClockAdapter`/`BcryptPasswordHasherAdapter` (adapters).
Repositories keep the DDD term as their suffix (`PersonRepository`, `InMemoryPersonRepository`) rather than
`Port`/`Adapter`.

Naming is deliberately Hexagonal (Ports & Adapters), not generic: `application/ports/` holds the
contracts the application needs from the outside world (repositories, and cross-context contracts — see
below), and `infrastructure/adapters/` implements them. `infrastructure/repositories/` stays a distinct,
named subtype rather than folding into `adapters/`, since "repository" already carries specific DDD
meaning. These are all *driven* (secondary) ports — the app calling out. The *driving* (primary) side —
the outside world calling in — is already served by the public signatures of `use_cases/`; don't add a
redundant interface per use case unless a specific one genuinely needs multiple implementations or a
consumer needs to mock it.

**`application/` is grouped physically by hexagon direction, never by a generic bucket.** The terms are
Cockburn's Hexagonal Architecture (Ports & Adapters): the axis is *who initiates the call* — `driving`
(a.k.a. primary/inbound) is the world→app direction, `driven` (a.k.a. secondary/outbound) is the app→world
direction. The subfolders live under two meaningful grouping segments — `driving/` (primary/inbound, the
world calling the app: `use_cases/`, `commands/`, `results/`) and `driven/` (secondary/outbound, the app
calling the world: `ports/`, `repositories/`, `outcomes/`) — with `mappers/` kept **neutral at the root of `application/`**
(outside both sides), because an application mapper often crosses the two directions (e.g. translating a
driven `Outcome` into a driving `Result`/`Error`). This materializes the *driving*/*driven* distinction the
paragraph above already assumes. A generic bucket (`data/`, `dto/`, `models/`) is **forbidden**: it is not
Hexagonal naming and it would fuse opposite sides of the hexagon; if you group, you group by direction.
`driving`/`driven` are grouping segments with meaning (like `infrastructure/http/`), so they carry **no**
suffix of their own — the "leaf-folder = category suffix" rule (`<Meaning><Category>`) is untouched:
`commands/` still holds `SignUpCommand`, `outcomes/` still holds `UpdateEmailOutcome`. A module creates only
the sides it has and never an empty grouping folder: `core/` (determinism + persistence + session, no use
cases) has **only** `driven/`; a feature like `identity/` has both. `domain/` and `infrastructure/` are
unaffected by this grouping (in particular `infrastructure/http/mappers/` is a separate, unrelated slice).
The Konsist `ArchitectureTest` uses `..application..` globs, so its layer rules hold across the new nesting.

### The rule that cuts across every context: derive, don't store

The reference graph is deliberately flat. A link between entities only exists when it's an intrinsic
fact of ownership (a person owns a budget) — never for query convenience. Concretely: `Expense` never
references `Budget`. Whether an expense "belongs" to a budget is answered at read time by comparing the
expense's date against the budget's date range, not by a stored foreign key. This is why editing a
budget's dates, deleting a budget, or creating a new one never requires touching existing expenses — the
set of expenses that "belongs" to a budget just changes answer on the next query. The same
derive-don't-store pattern repeats for a budget's spent/remaining amounts and for the couple's combined
budget/expense views — none of these are persisted, all are recomputed from the raw expense facts.

### Context boundaries worth remembering

- **`expense`** never references `budget` in either direction from expense's side; the relationship is
  unidirectional (other contexts query expense by date range, expense never queries budget). An expense
  with no covering live budget isn't an error — it surfaces in the "no budget" catch-all view.
- **`budget`** enforces a non-overlap invariant: the same person can never have two *live* budgets that
  share even a boundary day (one ending the 15th and another also starting the 15th is a rejected
  overlap; ending the 15th and starting the 16th is fine). Only live (non-deleted) budgets compete for
  this check.
- **`couple`** owns no money, budget, or expense — it only exists to unlock a combined *read* view over
  two individuals' data. Pairing never grants write access to the other person's data, and unpairing is
  non-destructive (no data is touched, moved, or deleted on either side). A person is never in more than
  one live couple at once. Pairing works through single-use, unguessable, short-lived (~1 day) invite
  codes.
- **`identity`** is the anchor every other context references by id, never the owner of financial data.
  Account deletion is the only irreversible, destructive operation in the system: it requires both a
  live session and password confirmation, runs as one atomic operation (session invalidated, password
  checked, all owned budgets/expenses hard-deleted, email neutralized but kept for audit history and
  freed for reuse, status set to deleted, any live couple dissolved), and reusing the freed email later
  creates an unrelated new person — never a resurrection of the old one. This context must never leak
  whether a given email is registered: signup conflicts and login failures are worded so an attacker
  can't distinguish "email doesn't exist" from "email exists, wrong password."

## Design decisions

Settled architectural decisions (Virtual Objects, domain errors, port outcomes, money representation,
auth token shape, DI wiring, the HTTP error contract, i18n, OpenAPI, API versioning, edge authentication,
cross-context communication) live as individual ADRs in
[`docs/architecture/decisions/`](docs/architecture/decisions/README.md), not inline here — read the
index and open the ones relevant to what you're touching. They aren't in the domain READMEs either
(deliberately kept out, since the READMEs stay in business language); treat all of them as settled unless
the user says otherwise.

## Test doubles, fakes and fixtures live outside the test class — never inline

Reusable test collaborators are **never** declared as top-level classes inside a test file; they live in
dedicated files so a test class only holds `@Test` logic and its own file-private constants. The layout
mirrors the production convention (one package owns its own wiring), split by what the collaborator *is*:

- **Doubles/fakes and their factory helpers** go in the owning package's `factories/` package — e.g.
  `core/factories/FakeSessionRepository.kt` (the deterministic fake, mirroring identity's
  `FakePersonRepository`) and `core/factories/clockFixedAt`/`idGeneratorOf`/`session` builders. A fake's
  own tuning constants (the token it recognizes, the id it owns) are `const`s exported from *its* file, so
  the test imports them rather than re-declaring them.
- **The `@Factory @Replaces` wiring** that swaps a real bean for a double in a `@MicronautTest` also lives
  in `factories/` — e.g. `core/factories/FakeSessionRepositoryFactory.kt`, mirroring identity's
  `SignUpUseCaseMockFactory`. Never inline the `@Factory`/`@Replaces` in the test class. (These bean
  definitions are discovered globally across every `@MicronautTest`; that is expected and harmless when the
  replaced bean is unused by the other tests.)
- **Shared test *fixtures* that are neither doubles nor factories** — cross-cutting harnesses and probe
  beans — live in the `support/` package: `support/PostgresHarness.kt`, and `support/AuthProbeController.kt`
  (the `@Controller` with an open route and an `@Authenticated` route, used to drive the edge-auth guard
  end-to-end). A probe controller is a fixture, not a double, so it belongs in `support/`, not `factories/`.

Concretely, `AuthenticatedFilterTest` only injects the `HttpClient` and asserts; its fake session
repository, the `@Replaces` factory, and the probe controller are all separate files under `core/factories/`
and `support/`.
