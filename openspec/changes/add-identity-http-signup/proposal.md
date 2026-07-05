## Why

The `identity` context has a working `SignUpUseCase`, but nothing drives it from the outside — the
only entry point is `Main.kt`, which just wires the object graph and runs migrations. There is no HTTP
surface, so a client cannot actually register a person. This change adds the first driving (primary,
inbound) adapter: a REST endpoint that exposes the existing sign-up behavior, without changing that
behavior.

## What Changes

- Add a new **driving/inbound** sub-layer under identity's infrastructure: `infrastructure/http/` with
  category folders `controllers/`, `requests/`, `responses/`, `errors/`, `mappers/`. Kept deliberately
  separate from `infrastructure/adapters/`, which the architecture docs reserve for **driven** (secondary,
  outbound) adapters.
- Add `PersonController` exposing `POST /sign-up`, calling `SignUpUseCase.invoke` (its documented driving
  side — no extra interface).
- Add `SignUpRequest` (structural validation only — body present, fields are non-null strings) and a
  mapper to `SignUpCommand`. Domain validation (email format, name, password policy) stays owned by the
  use case; the request layer never re-implements it.
- Add `PersonResponse` (success read-model, returned on 201) derived from `SignUpResult.Success`. It never
  exposes the password hash.
- Add HTTP error mapping: the controller branches exhaustively over the sealed `SignUpResult` (no thrown
  exceptions, so no `@ExceptionHandler`) and maps each `SignUpError` to an HTTP status plus a shared,
  neutral `ErrorResponse` body. The mapping preserves identity's non-leak invariant: an
  `EmailAlreadyInUse` conflict is worded so it cannot be used as an account-discovery oracle.
- **Build chore (non-behavioral):** add a Micronaut HTTP server + runtime to the classpath (today only
  `micronaut-inject` is present) and, if needed, the `application` plugin / a runnable server entry point.

## Capabilities

### New Capabilities
- `identity-http-api`: The HTTP/REST entry layer for the `identity` context. Covers the `POST /sign-up`
  endpoint — request shape and structural validation, the success response contract (201, no hash
  leaked), and the mapping of each domain sign-up outcome to an HTTP status and neutral error body that
  upholds the non-leak invariant. Scoped to sign-up only; login/logout/account-deletion are out of scope
  (no use case nor session concept exists yet).

### Modified Capabilities
<!-- None. `person-signup` describes the domain/use-case behavior, which is unchanged — this change only
     adds an HTTP delivery surface over it. -->

## Impact

- **New code:** `features/identity/infrastructure/http/**` (controller, request, response, error body,
  mappers).
- **Wiring:** identity's `main/IdentityModule` and/or `Main.kt` — depending on whether the controller is
  discovered directly by Micronaut or constructed by a `@Factory` (resolved in design.md); a runnable
  server entry point may be introduced.
- **Build:** `build.gradle.kts` gains a Micronaut HTTP server dependency (+ Netty runtime) and possibly
  the `application` plugin.
- **Architecture test:** the new `infrastructure/http/` code must satisfy the existing Konsist rules
  (infrastructure may import application/domain; identity must not import sibling contexts).
- **Unchanged:** all `domain`/`application` code, the `person-signup` behavior, and every other bounded
  context.
