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

**DI** is Micronaut's compile-time DI (annotation processing via KSP, no reflection), and each domain
package owns its own wiring in a `main/` subpackage: one `@Factory` class per package —
`core/main/CoreFactory.kt` (the shared kernel — determinism ports plus persistence) and
`features/<context>/main/<Context>Factory.kt` (e.g. `identity/main/IdentityFactory.kt`). Each factory
exposes `@Singleton` methods that construct and return the port types, taking their collaborators as
method parameters (the `@Factory` method is the single explicit place a pure, unannotated class is
constructed — Micronaut never discovers `application`/`domain` types by introspection). Each factory
wires only what its own package owns; a feature factory inherits core's bindings (e.g. the `DSLContext`)
rather than re-declaring them. The root `com.bed.cordato.main` package holds only `Main.kt`, the entry
point, which starts one Micronaut `ApplicationContext` (`ApplicationContext.run()`) — the context
discovers every package's `@Factory` into a single object graph. Micronaut singletons are lazy, so
`Main` eagerly resolves the `DataSource` bean to force the Flyway migrations to run at boot (fail-fast).
DI is deliberately *not* a per-feature `infrastructure/di/` concern: a package's `main/` subpackage is
the one place its wiring may reach across its own layers. `domain/` and `application/` never import
Micronaut or any DI annotation (`io.micronaut.context.annotation.*`, `jakarta.inject.*`) — they stay
framework-agnostic per the layer table above, enforced by the Konsist architecture test. (Infrastructure
still owns the adapters/config the factories wire — e.g. `DatabaseConfiguration` stays in
`core/infrastructure/persistence/`; only the Micronaut wiring lives in `main/`.) The classpath now also
carries `micronaut-http-server-netty` + `micronaut-serde-jackson` (compile-time JSON via `@Serdeable`, no
reflection) and `micronaut-validation` (edge Bean Validation) so `Main` starts an embedded server after
migrating. Micronaut applies AOP by subclassing, so the `kotlin("plugin.allopen")` plugin opens any type
carrying an `@Around`-meta annotation (e.g. `@Validated`); pure classes stay `final`.

**HTTP driving adapters are the one annotation-bearing exception to the "adapters are annotation-free,
wired in `main/`" rule.** A `@Controller` in `features/<context>/infrastructure/http/controllers/` (the
*driving*/inbound side, kept separate from the *driven* `infrastructure/adapters/`) carries Micronaut
routing annotations (`@Controller`, `@Post`, `@Body`, `@Validated`) and is discovered directly — the
router registers routes by scanning for them at compile time, so there is no `@Factory` way to declare a
route. It still depends only on the pure use case (the factory-provided bean, constructor-injected), so no
`application`/`domain` type gets introspected; the exception is scoped to the controller alone.

The rest of a feature's HTTP slice lives in `requests/`, `responses/`, `mappers/` (its `errors/` mapper,
e.g. identity's `SignUpErrorResponseMapper`, maps that context's own domain errors to a status + body).
Request/response DTOs are `@Serdeable` data classes. **Validation runs in two places on purpose, but from
one definition:** the request carries Bean Validation constraints (`@NotBlank`/`@Size`/`@Pattern`) for
early, per-field `400`s, while the domain value object stays the single, unbypassable authority for the
invariant. Every edge constraint that mirrors a domain rule *references the value object's own
`const`/pattern* (e.g. `@Size(max = NameValueObject.MAX_LENGTH)`, `@Pattern(regexp =
EmailValueObject.PATTERN)`) — never a copied literal — so the two can't drift; the edge is a
deliberately-equal-or-stricter guard (it sees the raw value, before the value object's trim/lowercase). A
field with **no** value object (pure transport: paging, filters) is validated *only* at the edge.

**The HTTP error contract is cross-cutting, so it lives in `core/infrastructure/http/`, not in any
feature**, split by kind the same way a feature's HTTP slice is: the shared response DTOs —
`ErrorResponse(code, message, errors)` with an optional `errors: List<FieldErrorResponse>` (each `field` +
`message`) that stays empty for scalar failures — plus the shared response builders that shape that body
at a status (`badRequest` for the edge/malformed `400`, `unprocessable` for the domain-rejection `422`,
`internalError` for the unexpected `500` — new statuses slot in the same way) live in
`core/infrastructure/http/responses/`, so nothing constructs the body inline; the generic
`ExceptionHandler`s that produce that body live in `core/infrastructure/http/errors/handlers/`.
Those handlers are the *same* annotation-bearing exception as
the controllers: Micronaut discovers each `ExceptionHandler` by exception type (`@Singleton`/`@Produces`,
`@Replaces` over a framework default), so there is no `@Factory` way to declare them and `CoreFactory` never
wires them; `ErrorResponse`/`FieldError` are plain `@Serdeable` DTOs. Every HTTP failure path exits in this
one shape: a failed `@Valid` throws `ConstraintViolationException` → `400` with **one `FieldErrorResponse`
per violated field** (never concatenated; `field` is the property path's final node, so the internal
`method.arg` prefix never leaks); a body that can't be read — invalid JSON (`JsonSyntaxException`), a shape
that fails deserialization before validation (`ConversionErrorException`), or an absent required body
(`UnsatisfiedRouteException`) — maps to a scalar `400` (`MALFORMED_REQUEST`); and any otherwise-unhandled
`Throwable` maps to a neutral `500` (`INTERNAL_ERROR`) whose detail is **logged only, never serialized**,
honouring the non-leak invariant. A domain rejection stays **fail-fast**: the feature's error mapper emits
a single scalar `422` via core's shared `unprocessable` builder — the builder owns the *shape*, the mapper
owns the *policy* (which error → which code/message). Identity's `EmailAlreadyInUse` is never turned into a
`FieldErrorResponse(field = "email")`, which would reintroduce the account-discovery oracle. **The HTTP
*status code is itself part of the non-leak invariant*: every domain rejection of a context shares one
status (`422` for identity), so the status can never signal *which* rejection happened. Giving one error a
distinct status — e.g. a "textbook" `409 Conflict` for `EmailAlreadyInUse` while the sibling rejections stay
`422` — leaks exactly what the generic code/message hide: the odd-status-out tells an attacker the e-mail is
registered. It is the same oracle as a per-field error, just carried by the status line. So the `400`/`422`
split is by *kind of failure* (malformed/edge vs. well-formed-but-domain-rejected), never per business rule;
a rule-specific status is only ever acceptable if it is applied uniformly to *all* of a context's domain
rejections at once (an all-or-nothing contract decision, not a per-error tweak) — and even then `422` is the
better semantic fit than `400`, since the payload is syntactically valid.** Constraint
violations, malformed bodies, and internal failures are genuinely *thrown*, unlike the domain's sealed
result, which is branched over.

**HTTP response text is resolved by key from a message bundle, never inlined — i18n-ready.** Every
human-readable response message comes from `src/main/resources/i18n/messages.properties` (pt-BR default;
a new language is just a `messages_<locale>.properties` sibling, no code change). `CoreFactory` exposes one
`@Singleton MessageSource = ResourceBundleMessageSource("i18n.messages")` (kept in `CoreFactory`, not a
second `@Factory`, per the "one `@Factory` per package" rule); micronaut-http-server layers a
request-scoped, `Accept-Language`-aware `LocalizedMessageSource` on top of it — injectable into the
`@Singleton` error handlers and the controller, falling back to the default bundle for an absent/unknown
header (never failing the request). The **message** is resolved by key at the policy call site through the
one shared helper `core/infrastructure/i18n/resolve` (fallback-to-key so a missing key never throws
on a response path); the **error `code`** (`INVALID_NAME`, `MALFORMED_REQUEST`, …) stays an inline constant
— it is the machine contract, not presentation text, and is never localized. The shared `badRequest`/
`unprocessable`/`internalError` builders still receive already-resolved strings (they own only shape). Edge
Bean Validation follows the same single origin: each constraint's `message` is a `{key}` into the *same*
bundle (`@NotBlank(message = "{signup.request.name.notBlank}")`), which the validator's interpolator
resolves against the `MessageSource` and re-interpolates for the nested constraint placeholders (`{max}`,
`{min}`); the `regexp`/`max`/`min` bounds still reference the value objects' own constants so the edge
can't drift. The non-leak invariant survives localization: `EmailAlreadyInUse` resolves a generic message
in any language and stays scalar, and the `500` resolves only a generic message with no internal detail.

**OpenAPI is generated at compile-time (KSP, no runtime reflection) and the doc annotations live on a
`<Controller>Doc` interface, not the controller.** `build.gradle.kts` adds `ksp("io.micronaut.openapi:
micronaut-openapi")` (processor) + `compileOnly(...:micronaut-openapi-annotations)` (the
`io.swagger.v3.oas.annotations`), pinned like the other KSP processors (the `ksp` config doesn't inherit
the BOM). The build emits the document and Swagger UI under `META-INF/swagger`, served via
`static-resources` mappings in `application.properties` (`/swagger/**`, `/swagger-ui/**`). Global document
metadata (`@OpenAPIDefinition` title/version) lives once in `core/infrastructure/http/openapi/` — cross-
cutting, alongside the error contract. Per route, the `@Operation`/`@ApiResponse`/`@Tag` annotations live on
an interface `features/<context>/infrastructure/http/controllers/docs/<Controller>Doc.kt` that the
controller **implements**: Micronaut inherits the interface's annotation metadata onto the implementing
method, so the controller keeps only routing/validation (`@Controller`/`@Post`/`@Validated`/`@Body`/
`@Valid`) and delegation while the documentation stays off it. Response *body* schemas are declared on that
interface's `@ApiResponse`s via `@Content(schema = @Schema(implementation = …))` (e.g. `201 → PersonResponse`,
`4xx/5xx → ErrorResponse`); field-level docs (`@Schema(description, example)`) live on the request/response
DTOs themselves, since a data class's fields have no interface to hang them on — this is also where you set
a sane `example` so the generator doesn't synthesize a garbage one from a `@Pattern` regex. Because the
handler returns `HttpResponse<*>` (varying status/body), annotate the success method with
`@Status(HttpStatus.CREATED)` so the generator documents `201` as the success response instead of emitting a
spurious `200` — it is inert at runtime (the explicit `HttpResponse` status always wins). This interface is
a **documentation artefact of infrastructure**, not an application port — it introduces no driving-side
contract and never duplicates the use case's signature. Apply the same `<Controller>Doc` split to every new
context's controller.

**Edge authentication is a declarative guard, cross-cutting so it lives in `core`, not any feature.**
Sign-in *mints* the session (opaque token, `hashToken` stored); the consuming side lives in
`core/infrastructure/http/authentication/` and turns a presented Bearer into an authenticated actor. It is
organized by kind, each in its own subpackage: `actors/AuthenticatedActor.kt` (the **authenticated actor**
— the edge category naming the driving-side answer to "who is calling this route?"; a plain `data class`
carrying **only** the `personId`, not a value class, to dodge the typed-binding pitfall; its `internal const
ATTRIBUTE` request-attribute key lives in the type's `companion`, namespaced under the type it transports
rather than as a scattered top-level constant — `personId` is a raw `String` throughout the domain, so this
is edge-binding machinery, not a domain type), `annotations/Authenticated.kt` (the marker annotation on a
`@Controller`/handler that declares the route protected — declaring it is what protects, decoupled from
whether the handler reads the actor), `filters/AuthenticatedFilter.kt` (the `@ServerFilter` guard, with a
file-private `bearerToken()` extension), and `binders/AuthenticatedActorArgumentBinder.kt` (the honest
binder). The
**`@ServerFilter` is the same annotation-discovered driving exception as the controllers and
`ExceptionHandler`s** — there is no `@Factory` way to declare a filter, so it wires itself and is *not* in
`CoreFactory`; it reads the matched route via `RouteAttributes.getRouteMatch(request)` (the non-deprecated
MN4 accessor), skips any route without `@Authenticated` (sign-up/sign-in stay open, no session resolution),
and on a protected route resolves the live session through `SessionRepository.findActiveByToken(token,
clock())` (injected as `BeanProvider` so building the singleton at boot doesn't realize the `DataSource`).
A live session → the person id is stashed in a request attribute and the request proceeds; **no live
session → the filter *returns* (never throws) the neutral `401` directly via the shared `unauthorized(...)`
builder** (code `UNAUTHENTICATED`, message by i18n key `error.authentication.message`, **no**
`WWW-Authenticate`, token never echoed). Returning-not-throwing mirrors how identity's sign-in mapper
already emits the identical `401` and sidesteps any dependence on filter-thrown exceptions reaching a
handler — so there is deliberately **no** `UnauthenticatedException`/handler. Absent, malformed, expired and
revoked tokens collapse to one response, so neither status nor body reveals the cause. The
`AuthenticatedActorArgumentBinder` is annotation-free and wired in `CoreFactory` (a `@Singleton
TypedRequestArgumentBinder<AuthenticatedActor>`); it **only reads** the attribute the filter set — no
session lookup, no `401` — so an absent attribute (a handler asking for the actor on a route that isn't
`@Authenticated`) is an unsatisfied binding, a programming error with no legitimate request path.

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
