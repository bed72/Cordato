## Why

Sign-in opens a session but nothing in the system can close one on request. A person has no way to end
their own session before its ~1-day TTL expires — the only existing session-ending path is the *side
effect* `UpdatePasswordUseCase` triggers on the person's *other* sessions. Logout is the missing,
explicit counterpart: let an authenticated person revoke their own current session.

## What Changes

- Add `SessionRepository.revoke(sessionId): Boolean` — revokes the single session identified by
  `sessionId`, symmetric to the existing `revokeAllForPersonExcept`. Idempotent: revoking an
  already-revoked or unknown session id is a valid `false`/no-op result, never an error.
- Implement `revoke` in `PersistenceSessionRepository` (jOOQ), mirroring `revokeAllForPersonExcept`.
- Add `SignOutUseCase` (identity) — takes the current `sessionId` from the already-resolved
  `AuthenticatedActor` (no new lookup of the person), calls `SessionRepository.revoke`, and returns a
  uniform success. No domain error case exists: an already-gone session still ends in the same client-
  visible outcome (logged out).
- Expose a new protected HTTP route, `POST /authentication/sign-out`, on `AuthenticationController`,
  guarded by the same `@Authenticated` filter as `PersonController`'s routes. Success responds `204 No
  Content`. Once revoked, the token that had authenticated this call resolves the same as a `401` on any
  subsequent request (per the existing `findActiveByToken` contract).

## Capabilities

### New Capabilities

(none — this change only adds requirements to existing capabilities)

### Modified Capabilities

- `session-management`: add a requirement for revoking a single, specific session by id (the
  counterpart to the existing "revoke all except one" requirement).
- `identity-http-api`: add the `POST /authentication/sign-out` protected endpoint requirement (request
  shape, success response, guard behavior — mirroring the conventions the other protected `/persons/me/*`
  routes already document).

## Impact

- `core/application/driven/repositories/SessionRepository.kt` — new `revoke` method on the port.
- `core/infrastructure/repositories/PersistenceSessionRepository.kt` — new jOOQ implementation.
- `features/identity/application/driving/use_cases/SignOutUseCase.kt` (new),
  `features/identity/application/driving/commands/SignOutCommand.kt` (new),
  `features/identity/application/driving/results/SignOutResult.kt` (new).
- `features/identity/infrastructure/http/controllers/AuthenticationController.kt` — new `@Post
  ("/sign-out")` route, `@Authenticated`.
- Out of scope (non-behavioral chores, done as follow-up per CLAUDE.md): tests and
  `AuthenticationControllerDoc`/OpenAPI + README updates — same split the `add-identity-sign-in` change
  used.
