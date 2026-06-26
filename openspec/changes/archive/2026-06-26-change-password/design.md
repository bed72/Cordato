## Context

Identity already covers the full account boundary except credential rotation: `sign-up` (create),
`sign-in` / `validate-session` / `sign-out` (session lifecycle), `update-account` (edit name/email in
place), and `delete-account` (the nuclear, irreversible exit, which re-confirms the password and purges
*all* sessions). `update-account` deliberately left credentials alone and named `change-password` as its
own change "with its own re-confirmation semantics and likely session invalidation". This change adds that
missing arm: an authenticated person rotates their own password.

It is the close cousin of `delete-account` — both re-confirm identity with the *current* password before a
guarded effect — and reuses `delete-account`'s hasher guard and session-purge machinery almost verbatim,
differing only in the effect (overwrite the hash vs. erase the account) and the purge scope (all-except-one
vs. all). The slice is still ORM-deferred: pure `domain/` + `application/` ports + the in-memory
`PersonRepository` and `SessionRepository`.

## Goals / Non-Goals

**Goals:**
- An authenticated person replaces their own password, preserving `id`, `created_at`, `status`, `name`,
  and `email` — the only mutation is the stored hash.
- Re-confirm identity with the current password (`hasher.verify`), with a wrong password and an unresolved
  requester failing identically (`IncorrectPasswordError`, no oracle).
- Re-validate the new password against the policy (`PasswordValueObject` → `WeakPasswordError`), cheaply
  and before any hashing or verification.
- Hash the new password only past the identity guard (never pay for hashing a request the guard rejects).
- Purge every *other* session of the person and keep the acting one, dropping any pre-rotation token.
- Expose no secret: no plaintext, no hash, neither old nor new.

**Non-Goals:**
- **A "forgot password" / reset-by-email flow** — that is unauthenticated recovery via a one-time token,
  a separate capability with its own delivery gateway. This change is the *authenticated* rotation only.
- **Purging the acting session too (forced re-login)** — explicitly decided against; the device that just
  changed the password stays signed in. (Considered and rejected below.)
- **Password history / "can't reuse last N"** — no stored history exists; out of scope.
- **Edit auditing** — no `password_changed_at` field; adding one is a separate change.

## Decisions

### Re-confirm with the current password, exactly like `delete-account`
The guard is `person = find_active_by_id(requester_id)` then
`hasher.verify(current_password, person.password)`; `person is None or not verified` →
`IncorrectPasswordError`. The two failure causes (no active person / wrong password) collapse to one error
so nothing leaks which occurred — the same no-oracle shape `delete-account` already uses. A password
rotation, like account deletion, is a credential-sensitive action, so re-confirmation is warranted even
though the operation is reversible (unlike deletion).

### Both passwords are `PasswordValueObject`, mirroring `delete-account` and the hasher port
The `PasswordHasherInterface` speaks `PasswordValueObject` on both `hash(password)` and
`verify(password, hash)` — the domain hands it the validated VO, never a raw `str`. `delete-account`
already re-confirms with `password: PasswordValueObject`, so this change follows the same shape: the command
carries `current_password: PasswordValueObject` and `new_password: PasswordValueObject`, both built (and
policy-checked) at the data-building boundary, before the use case.
- *Doesn't policy-checking the current password risk rejecting a legitimate legacy credential?* No — there
  is no such credential. Every password ever stored was minted through `PasswordValueObject` at sign-up
  (min length 8), so a current password that could possibly verify is necessarily ≥ 8; the policy gate
  rejects only inputs that could never have been the stored secret anyway. And it leaks nothing useful: the
  length floor applies to the *caller's own* guess, not to the stored value.
- *Considered — a raw `str` current password + a verify-only path:* rejected; it would diverge from
  `delete-account` and force the hasher port to grow a second `verify` overload for no real gain.

### Ordering: cheap policy guard → identity guard → hash → persist + purge
1. Both `PasswordValueObject`s are constructed at the data boundary — pure, cheap; a weak new (or current)
   password is rejected with `WeakPasswordError` at zero I/O and zero hashing, before the use case runs.
2. Inside the use case: `find_active_by_id` + `hasher.verify(current_password, person.password)` — the
   identity guard.
3. Only past the guard, `hasher.hash(new_password)` — the expensive step, never reached by a rejected
   request (honoring "never pay for hashing that a prior check would have rejected").
4. `person.change_password(new_hash)`; then persist + purge.

Note the new-password VO is built *before* the guard while the new hash is computed *after* it: validation
is cheap and must reject early, hashing is expensive and must wait. The current-password verify cannot be
gathered with anything — it gates everything after it (a real data dependency), so it is awaited
sequentially, not via `gather`.

### Mutation lives in the entity: `PersonEntity.change_password(new_hash: str)`
A new entity method overwrites `password` with the already-computed hash and leaves
`id`/`created_at`/`status`/`name`/`email` untouched — the same shape as `update_account` and `delete`
owning their own transitions. The entity receives a finished hash (a plain `str`, no value object — a hash
carries no invariant, per the project's "earn its existence" rule); hashing is the gateway's job, done in
the use case.

### Session purge: new port method `purge_for_person_except(person_id, keep_token)`
`SessionRepositoryInterface` gains `async def purge_for_person_except(self, person_id: str, keep_token: str)
-> None`, the all-except-one sibling of the existing `purge_for_person`. It removes every session of the
person whose `token != keep_token`, irrespective of validity (live, revoked, or expired alike), and is
idempotent. The acting session is identified by its **token** — the bearer credential the caller already
holds and presents on the request — so the command carries `current_session_token`. Identifying by token
(not session id) means the use case needs no extra read to resolve the current session's id.
- *Alternative considered — reuse `purge_for_person` then let the caller re-issue a session:* rejected; it
  would log the acting device out for no reason and force an immediate silent re-sign-in, a worse UX and a
  wider blast radius than the security goal needs.
- *Alternative considered — exclude by session id:* rejected; the use case would have to first resolve the
  token → session to learn its id, an extra round-trip for no benefit since the token uniquely identifies
  the row.

### Effects past the guard are independent and gathered
`person.change_password(new_hash)` is a pure in-memory transition; the two **I/O** effects that follow —
`person_repository.update(person)` and `session_repository.purge_for_person_except(person.id,
current_session_token)` — consume no result of each other, so they are issued together with
`asyncio.gather`, exactly as `delete-account` gathers its independent effects.

### No read-model returned
The use case returns `None`. There is no secret to surface and nothing about the person changed that the
caller does not already know (the name/email it already has). This matches `sign-out`/`delete-account`
returning nothing. (If the web layer later wants a 200 body, it can re-read `PersonData` itself.)

## Risks / Trade-offs

- **No transaction at the in-memory stage**: the hash-update and the session purge are not atomic. →
  Acceptable and consistent with every other slice; the guard (the only pre-effect failure) runs strictly
  first, so a rejected request changes nothing, and the indivisible boundary arrives with the ORM behind
  these same ports. A crash between the two effects would leave the new password set but stale sessions
  un-purged — fail-safe-ish (the credential is already rotated); a retry re-purges idempotently.
- **Keeping the acting session means a thief who is *currently* on the acting session survives.** → The
  threat model for rotation is a *leaked older credential*; the person initiating the change is the
  legitimate holder of the acting session by assumption. Forced full re-login (the rejected alternative)
  remains available as a future toggle if the model changes.
- **Identifying the kept session by token couples the command to the bearer secret.** → The token is
  already in scope on every authenticated request (it is how `requester_id` was resolved upstream); passing
  it one layer further is no new exposure, and it never leaves for an external surface.
- **The current password is policy-checked too** (it is a `PasswordValueObject`), so a sub-minimum guess
  raises `WeakPasswordError` rather than `IncorrectPasswordError`. → Harmless and consistent with
  `delete-account`: every stored password was minted under the same policy, so a verifiable current password
  is always ≥ the minimum; the gate only rejects guesses that could never have been the stored secret, and
  the floor concerns the caller's own input, not the stored value.
