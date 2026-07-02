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

Note: no `application` plugin is configured, so there is no `./gradlew run` task — `Main.kt` is only
runnable from the IDE. Add the plugin if a runnable entry point becomes necessary.

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
| `application/` | `ports/` (contracts), `command/` (input commands), `result/` (output read-models), `use_cases/`, `mappers/` | no |
| `infrastructure/` | `repositories/` (+ `models/`, `mappers/`) and `adapters/` (everything else external) | only here |

`domain/` never imports anything from outside itself.

### Class naming — every type carries its category suffix

Type names are composed as `<Meaning><Category>`, where the suffix names the architectural
building block, matching the folder it lives in: `PersonEntity` (entities), `EmailValueObject`
(value_objects), `PersonStatusEnum` (enums), `SignUpError` (errors), `SignUpCommand` (command),
`SignUpResult` (result), `SignUpUseCase` (use_cases), `ClockPort`/`PasswordHasherPort` (ports),
`SystemClockAdapter`/`BcryptPasswordHasherAdapter` (adapters). Repositories keep the DDD term as
their suffix (`PersonRepository`, `InMemoryPersonRepository`) rather than `Port`/`Adapter`.

Naming is deliberately Hexagonal (Ports & Adapters), not generic: `application/ports/` holds the
contracts the application needs from the outside world (repositories, and cross-context contracts — see
below), and `infrastructure/adapters/` implements them. `infrastructure/repositories/` stays a distinct,
named subtype rather than folding into `adapters/`, since "repository" already carries specific DDD
meaning. These are all *driven* (secondary) ports — the app calling out. The *driving* (primary) side —
the outside world calling in — is already served by the public signatures of `use_cases/`; don't add a
redundant interface per use case unless a specific one genuinely needs multiple implementations or a
consumer needs to mock it.

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

These aren't in the domain READMEs yet (or are deliberately kept out of them, since the READMEs stay in
business language) — treat them as settled unless the user says otherwise.

**Virtual Objects** (`domain/virtual_objects/`) are a third category alongside `entities/` and
`value_objects/`: a projection computed at read time from real entities, with no identity of its own,
never persisted, recomputed on every ask. Unlike a value object, it composes/references entities; unlike
an entity, it's never tracked or referenced over time. Examples: the enriched active budget (live budget
+ spent + remaining), the "no budget" catch-all bucket, the couple's combined budget panorama, the
couple's combined expense view. Keep the implementation boring — a plain `data class` assembled by a
domain function/service, no base class or marker interface for the sake of taxonomy. If one starts
needing identity or mutation, that's a sign it slipped into being an entity, not a reason to formalize
the category further.

**Domain errors** are `sealed class`/`sealed interface` hierarchies returned from use cases, not thrown
exceptions — keeps error paths exhaustively checked by the compiler in `when` and testable without
`assertThrows`.

**Money** is BRL-only — no multi-currency abstraction, that complexity isn't needed here. Represent it
internally as an integer number of cents (or a fixed-scale `BigDecimal`), never `Double`: the domain's
repeated "exact value" invariant (an expense/budget amount is always exact) is a floating-point
correctness requirement, not a style preference. Display formatting (`R$ 1.234,56`) is a presentation
concern, kept out of the value object's construction/arithmetic.

**Auth** is an opaque token, not a self-describing one (JWT). Deliberate: identity's account-deletion
rule requires the session to be invalidated *immediately* as part of the atomic delete, which an opaque
token (deleted server-side on revoke) satisfies trivially — a self-contained token would need a blocklist
or very short TTLs to fake the same guarantee. The token/session concept belongs in `core/` (identity's
README already calls it "domínio compartilhado") once that module exists.

**DI** is Koin, wired only at the composition root (infrastructure / entry point). `domain/` and
`application/` never import Koin or any DI annotation — they stay framework-agnostic per the layer table
above.

**Cross-context communication** uses an Anti-Corruption Layer, never a direct import between contexts'
`domain`/`application`, and never data duplication. Concrete case: `couple`'s combined views need
per-person data owned by `budget` and `expense`.
- Dependency direction is one-way: `couple → budget` and `couple → expense`, never the reverse. `budget`
  and `expense` must never reference `couple` — they don't know pairing exists.
- The consumer (`couple`) defines the contract it needs, in its own vocabulary, as a port in
  `couple/application/ports/` (e.g. a `PersonFinancialsPort`).
- `couple/infrastructure/adapters/` implements that port by calling `budget`'s and `expense`'s existing
  public use cases directly (an in-process call — no need for HTTP inside one deployable) and mapping the
  result into couple's own shape.
- `couple`'s own `domain`/`application` never import `budget` or `expense` types — only the port.
- No duplication: combined views (`orçamento do casal`, `gastos do casal`) are never stored, only ever
  recomputed live through the port — derive-don't-store applied across contexts, not just across
  entities.
- `couple` owns composing these combined views; `budget` and `expense` only ever answer their existing
  single-person query, called once per person in the pair. (The `expense` and `budget` READMEs currently
  describe the couple-combined view as if they compute it — that phrasing describes the user-visible
  effect, not implementation ownership; the READMEs have been updated to point this at `couple`.)
