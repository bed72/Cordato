## Context

The `identity` context has a fully wired `SignUpUseCase` (constructed by `IdentityModule`, a Micronaut
`@Factory`), but no way to invoke it from outside the JVM. `Main.kt` only starts an `ApplicationContext`
and resolves the `DataSource` to force Flyway migrations — there is no HTTP server. `build.gradle.kts`
carries **only** `micronaut-inject` + its KSP processor ("no HTTP server yet — that is a later change").

This change adds identity's first **driving (primary, inbound)** adapter. Two project conventions shape
every decision here:

- **Driven vs driving separation.** `infrastructure/adapters/` is documented as *driven* (the app calling
  out: Postgres, bcrypt). A controller is the opposite — the outside calling in — so it lands in a new
  sibling package `infrastructure/http/`, not in `adapters/`.
- **DI lives in `main/`, adapters stay annotation-free.** Today `PasswordHasherAdapter` and
  `PersistencePersonRepository` are plain, unannotated classes *constructed* inside `IdentityModule`'s
  `@Factory` methods. Nothing in `infrastructure/` currently carries a Micronaut annotation.

## Goals / Non-Goals

**Goals:**
- Expose `POST /sign-up` backed by the existing `SignUpUseCase`, unchanged.
- Keep domain validation in the use case; the HTTP layer does structural validation only.
- Never leak the password hash in a response.
- Map the sealed `SignUpResult` to HTTP without exceptions, upholding identity's non-leak invariant as far
  as an unverified-signup endpoint allows.
- Add the HTTP server to the build and give the app a real, runnable server entry point.

**Non-Goals:**
- Login, logout, account deletion — no use case nor session concept exists yet (belongs in `core/`).
- Bean-Validation (`@NotBlank`, regex) on the request — that would duplicate domain rules.
- Fully closing the signup account-existence oracle (needs deferred email verification — see Risks).
- Auth, rate limiting, OpenAPI docs, CORS, content negotiation beyond JSON.

## Decisions

### 1. `PersonController` carries `@Controller`/`@Post`, discovered directly (not factory-built)

Micronaut's router registers routes by scanning beans for `@Controller` and reading `@Post`/`@Get` on
methods — there is no factory-based way to register HTTP routes. So `PersonController` **must** be an
annotated, directly-discovered bean, taking `SignUpUseCase` via constructor injection (Micronaut supplies
the factory-produced bean).

This is a deliberate, documented exception to "adapters are annotation-free, wired only in `main/`." The
rationale behind that convention is that Micronaut must never *introspect pure `application`/`domain`
types* — and it still won't: `SignUpUseCase` stays factory-constructed. The controller is a pure
framework-integration object living in `infrastructure/`, the one layer allowed to know the framework, so
annotating it is consistent with the layer table, not a violation of it. *Alternative rejected:* a
`@Factory`-built controller — impossible, routing needs the annotation scan.

### 2. Bean Validation at the edge, sourced from the domain (one definition, two references)

`SignUpRequest` carries `jakarta.validation` constraints and the controller is `@Validated` with a
`@Valid @Body`, so the body is checked before the use case runs. This is a deliberate reversal of the
first cut (which kept validation domain-only): the team's call is to validate at the HTTP edge **as well**,
for earlier, per-field `400`s and a uniform "every request is validated" model — accepting that this is an
*ergonomics/consistency* gain, not a security one (the value object is the unbypassable enforcement point
on every path; the edge check only guards HTTP).

The duplication is made safe by never copying a rule — only *referencing* the domain's own definition:

- `@field:Size(max = NameValueObject.MAX_LENGTH)` and `@field:Size(min = PasswordValueObject.MIN_LENGTH)`
  — the value objects' `const val`s, so a bound change propagates to both sites automatically.
- `@field:Pattern(regexp = EmailValueObject.PATTERN)` — the value object exposes its regex as a
  `const val String`; the annotation reuses that exact pattern instead of a second regex.
- `@field:NotBlank` on name/email (presence + non-blank). **Not** on password: the domain deliberately
  does not trim passwords, so an all-whitespace 8-char password is valid — only `@Size(min)` guards it.

Because the constraints mirror the domain, the domain's `InvalidName`/`InvalidEmail`/`WeakPassword` become
the *inner* guard: for HTTP they are normally pre-empted by the edge `400`, but they remain reachable (and
still map to `422`) in the one case the edge can't mirror — **normalization**. `EmailValueObject.of`
trims + lowercases before validating; the annotation sees the *raw* value, so an input like
`" Alice@Example.COM "` is rejected at the edge (`400`) though the domain would accept it. The edge is thus
intentionally a *strict superset* of the domain rule, never a looser or divergent one. *Alternative
rejected:* copying literals (`@Size(max = 32)`, a second `@Email` regex) — that is the drift the reference
approach removes; the earlier example that motivated this had `max = 100` against a domain max of 32.

### 2b. Constraint failures reuse the `ErrorResponse` shape

A failed `@Valid` throws `ConstraintViolationException`, which Micronaut would render in its own
`_embedded.errors` shape — a second error format. A `@Singleton ExceptionHandler` (replacing Micronaut's
default) maps it to a `400` in the same neutral `ErrorResponse` body, so the API has exactly one error
shape. This is the correct place for an exception handler: constraint violations are genuinely *thrown* by
the framework, unlike the domain's sealed `SignUpResult` which is never thrown (Decision 3 still holds for
the use-case path).

### 3. Error mapping: exhaustive `when` over `SignUpResult`, no `@ExceptionHandler`

The controller calls `useCase(command)` and branches over the sealed result. Because the domain never
throws, there is nothing for an `@ExceptionHandler` to catch — the mapping is a plain `when` returning an
`HttpResponse`. Status table:

| Outcome | Status | Body |
|---|---|---|
| `Success(person)` | `201 Created` | `PersonResponse` (id, name, email) |
| `InvalidEmail` | `422 Unprocessable Entity` | neutral `ErrorResponse` |
| `InvalidName` | `422 Unprocessable Entity` | neutral `ErrorResponse` |
| `WeakPassword(minLength)` | `422 Unprocessable Entity` | `ErrorResponse` that MAY state the public min length |
| `EmailAlreadyInUse` | `422 Unprocessable Entity` | **generic** `ErrorResponse`, no email echoed, wording never confirms registration |

`EmailAlreadyInUse` deliberately shares the same `422` **status** as the input rejections (rather than a
distinctive `409 Conflict`) and gets a generic message — so neither the status code nor the body text acts
as "this email is registered" signal. *Alternative rejected:* `409 Conflict` + "e-mail já cadastrado" —
textbook account-discovery oracle, directly against identity's non-leak rule.

`ErrorResponse` is a small shared shape (e.g. `message: String`, optional stable `code: String`), the same
type for every failure so the body structure itself isn't a tell.

### 4. Mappers are internal extension functions

Per the repo's mapper convention: `internal fun SignUpRequest.toCommand(): SignUpCommand` and
`internal fun PersonEntity.toResponse(): PersonResponse` (or from `SignUpResult.Success`), living in
`infrastructure/http/mappers/`. No mapper object/interface. `toResponse` reads only id/name/email — the
hash is structurally absent from `PersonResponse`, so a leak is impossible by construction, not by
discipline.

### 5. Build + entry point

- Add `implementation("io.micronaut:micronaut-http-server-netty")` (embedded Netty server) to the
  existing platform BOM, plus a JSON body binder (Micronaut Serde or `micronaut-jackson-databind`) if the
  server artifact doesn't bring one transitively — confirm at implementation.
- Give the app a runnable server: start the embedded server (`io.micronaut.runtime.Micronaut.run(...)` or
  resolving the `EmbeddedServer` bean) so routes are actually served. Keep the eager `DataSource` resolve
  so migrations still run fail-fast at boot. Add the Gradle `application` plugin so `./gradlew run` works
  (today there is none). *Alternative considered:* IDE-only run — rejected, an HTTP service needs a real
  launch task.

## Risks / Trade-offs

- **Residual signup oracle** → An unverified signup endpoint inherently distinguishes a registered email
  (rejection) from an unregistered one (`201`). Status/wording choices minimize the *incremental* leak but
  cannot fully close it. Real mitigation is a future deferred email-verification flow (respond identically
  — e.g. `202 Accepted` — regardless of existence, differing only in the email sent). Out of scope here;
  flagged as an open question so it's a conscious deferral, not an oversight.
- **Generic conflict message hurts UX** → A legitimate user re-registering an email gets an unhelpful
  "could not complete signup." This is the documented security-over-convenience tradeoff the identity
  README already accepts; noted so it isn't "fixed" later by leaking.
- **Controller annotations vs the annotation-free-adapter convention** → Mitigated by scoping the
  exception narrowly (only the controller, only because routing demands it) and documenting it in Decision
  1 and the CLAUDE.md follow-up, so it doesn't erode into "annotate adapters freely."
- **Konsist coverage** → The existing rules allow `infrastructure → application`; they don't yet assert
  that only `infrastructure/http/` (not `domain`/`application`) imports `io.micronaut.http.*`. Consider a
  follow-up rule so a stray HTTP import into an inner layer fails the build. Non-blocking.

## Open Questions

- Exact `ErrorResponse` field set and the stable `code` vocabulary (e.g. `INVALID_EMAIL`,
  `SIGNUP_REJECTED`) — settle during implementation; must keep `EmailAlreadyInUse`'s code/message generic.
- JSON binder: does `micronaut-http-server-netty` pull a serializer transitively under this BOM, or is an
  explicit `micronaut-serde-jackson` needed? Verify when adding the dependency.
- Route base path: bare `/sign-up` vs a versioned/context prefix (`/identity/sign-up`, `/api/...`). Deferred
  to implementation; the spec only fixes the `POST` + `/sign-up` leaf.
