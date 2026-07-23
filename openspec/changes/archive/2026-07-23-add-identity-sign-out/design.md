## Context

Sessions are core's first persisted aggregate (`core/domain/entities/SessionEntity`), opened by
`SignInUseCase` and resolved by `SessionRepository.findActiveByToken` at every protected request. The only
existing way a session stops resolving before its TTL is `revokeAllForPersonExcept` — a *side effect* of
`UpdatePasswordUseCase`, revoking the person's *other* sessions while sparing the current one. There is no
operation for a person to end their own current session on request. This change adds that operation
end-to-end: repository method, use case, and HTTP route.

The authenticated HTTP edge already resolves an `AuthenticatedActor(personId, sessionId)` per request (via
`AuthenticatedFilter` + `AuthenticatedActorBinder`), so the current session's id is available to any
protected route handler without a new lookup.

## Goals / Non-Goals

**Goals:**
- Let an authenticated person end their own current session (logout).
- Add the minimal, symmetric repository primitive (`revoke(sessionId)`) the operation needs.
- Keep the behavior consistent with the project's existing revoke semantics: server-authoritative,
  idempotent, never throws, "nothing to revoke" is a valid outcome.

**Non-Goals:**
- Logging out *other* sessions/devices (already covered indirectly by `revokeAllForPersonExcept` on
  password change; no "log out everywhere" endpoint is in scope here).
- Any client-side token handling — the client is expected to discard the token after a successful
  sign-out; the server's only obligation is that the token stops resolving.
- Tests and documentation (`AuthenticationControllerDoc`/OpenAPI, README) — deferred as non-behavioral
  chores, same split `add-identity-sign-in` used.

## Decisions

**Route: `POST /authentication/sign-out`, protected by `@Authenticated`, on the existing
`AuthenticationController`.**
Alternative considered: a `DELETE /sessions/me` on a new controller, or moving it to `PersonController`.
Rejected — `AuthenticationController`'s own doc comment already scopes it to the flows that *mint* or *end*
a session (today: sign-up, sign-in), while `PersonController` is for operations on the person's own data
(name/email/password/profile). Sign-out is squarely an authentication-lifecycle operation, so it stays
alongside sign-in/sign-up rather than fragmenting the authentication surface across two controllers. `POST`
(not `DELETE`) matches the verb `sign-in` already uses for a state-changing auth action, keeping the two
symmetric.

**No new domain error; uniform success.**
`SignOutUseCase` has nothing to branch on: the session id comes from the edge guard's own resolution (the
request could not have reached the handler without a currently-live session), and revoking a session that
turns out to already be gone (a benign race — e.g. two concurrent logout calls) is still success from the
caller's perspective. So `SignOutResult` is a single `Success` case (or the use case could return `Unit` —
kept as a one-case sealed type only for symmetry with every other identity use case's result type, easing
future extension if that ever changes). This mirrors `revokeAllForPersonExcept` already treating "nothing
to revoke" as a valid, non-error outcome rather than inventing a `SessionNotFound` error nobody would act on.

**`SignOutCommand(sessionId)` only — no `personId`.**
Revoking by session id alone is sufficient and avoids the use case needing to check that the session
belongs to the caller (the edge guard already established that: the `sessionId` on `AuthenticatedActor` is
*the* session that authenticated this exact request, not an arbitrary id from client input). This is
different from `revokeAllForPersonExcept`, which is inherently person-scoped (a person's *other* sessions).

**Repository method: `revoke(sessionId: String): Boolean`.**
Symmetric, one-argument counterpart to `revokeAllForPersonExcept(personId, sessionId)`. Returns whether a
live session was actually revoked, for symmetry with `open`'s boolean return — but the use case does not
branch on it (see above); the boolean exists for the repository contract's own honesty, not because a
caller needs it yet.

**Success response: `204 No Content`.**
There is nothing to return (the session that authenticated the request no longer exists), and 204 is the
existing project convention (`http-response-envelope`/`http-error-handling` capabilities) for a state-
changing action with no representation to return — consistent with the `revoke` operation's nature rather
than reusing the `{ token, expiresAt }` shape sign-in uses, which is not applicable here.

## Risks / Trade-offs

- **Revoking a session on every logout call, including replays** → Mitigated by idempotency: a second
  sign-out call with the same (now-dead) token fails the `@Authenticated` guard with the ordinary neutral
  `401`, which is the expected, already-specified behavior for any orphaned/absent session — no special
  casing needed.
- **Single-session-only logout may surprise a user expecting "log out everywhere"** → Out of scope by
  design (see Non-Goals); `revokeAllForPersonExcept` already exists for the multi-session case and a
  future "log out all devices" change can reuse it without touching this one.

