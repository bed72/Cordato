## Context

`identity`'s domain groundwork for this is already in place: `PersonStatusEnum` already has `DELETED`,
explicitly reserved (per its own doc comment) "for the account-deletion cycle." What's missing is
everything above domain — the use case, the persistence operations, the cross-context cascade, and the
HTTP route. The other step-up operations already implemented (`update-own-email`, `update-own-password`)
establish the conventions this change reuses rather than invents: session + current-password confirmation,
a neutral `401` collapsing "wrong password" and "session points at a non-active person" into one
indistinguishable response, and — critically — no `@Transactional` anywhere in the codebase. Multi-write
"atomicity" today is achieved by **ordering** (irreversible/visible writes happen only after everything
that could still fail has succeeded), not by a database transaction spanning repositories. `UpdatePasswordUseCase`
is the worked example: it persists the new hash *before* revoking other sessions, so a failed write never
revokes a live session for nothing.

This change also crosses context boundaries for the first time in a *destructive* direction: `identity`
needs `budget` and `expense` to hard-delete everything a given person owns. ADR-0013 (Cross-context
communication) already establishes the pattern for this — the consumer defines its own port, the producer
exposes a public use case, an infrastructure adapter wires them together in-process — but every existing
instance of it (`couple → budget`, `couple → expense`) is read-only. This is the first write-cascade.

## Goals / Non-Goals

**Goals:**
- Specify the `identity`-owned `person-account-deletion` use case: password confirmation, all-live-sessions
  revocation, email neutralization + status transition, and triggering the ownership cascade — as one
  ordered sequence with a single point of no return.
- Specify the new hard-delete-all-for-person capability `budget` and `expense` each need to expose, and the
  ACL wiring `identity` uses to reach them, consistent with ADR-0013.
- Specify the new protected HTTP route and its request/response/error shape, consistent with the existing
  step-up routes.

**Non-Goals:**
- Pairing/couple dissolution. `couple` has no code yet (README only) — nothing exists to dissolve. Deferred
  to whichever change first implements `couple`.
- A real cross-repository database transaction. Out of scope — this change follows the codebase's existing
  ordering discipline instead (see Decisions).
- Any change to `budget-delete`'s existing soft-delete behavior for a person's own single-budget removal.
  The two deletion paths (self-service single budget, account-deletion cascade of all budgets) are
  deliberately different operations with different semantics (soft vs. hard).

## Decisions

### Ordering: cascade first, person write is the point of no return, sessions last

The sequence is: (1) resolve the active person, (2) verify the confirmation password, (3) hard-delete all
owned budgets, (4) hard-delete all owned expenses, (5) neutralize the email + transition status to
`DELETED` on the person row, (6) revoke every live session for the person.

The person write (step 5) is deliberately placed **after** the cascade, not before: if the cascade
(3–4) throws (an infrastructure exception, per the existing `create`-style convention where a datastore
failure never crosses back as a domain value), the person is still `ACTIVE`, the email is untouched, and
the caller — still holding a valid session and having just proven their password — can safely retry. If the
person write happened first, a failed cascade would leave a `DELETED` person with orphaned budgets/expenses
and no way to retry (their session and login are both gone). Session revocation (6) is last, mirroring
`UpdatePasswordUseCase`: the one part of this sequence that "closes the door" runs only once everything
that mutates data has already succeeded.

**Alternative considered**: wrap the whole sequence in a database transaction. Rejected — no code in this
repo uses `@Transactional` today, cross-context writes going through separate repository/use-case
boundaries would fight that pattern, and the ordering approach already gives the property that matters (no
half-visible destructive state survives a failure), consistent with the rest of the codebase.

### Cross-context cascade follows ADR-0013, in the write direction

`identity` defines a driven port in its own vocabulary (e.g. `PersonOwnedFinancialsPort` with a single
`deleteAllOwnedBy(personId)`, or two narrower methods — see Open Questions) in
`identity/application/driven/ports/`. `identity/infrastructure/adapters/` implements it by calling a new
public use case each on `budget` and `expense` (e.g. `DeleteAllOwnedBudgetsUseCase`,
`DeleteAllOwnedExpensesUseCase`), in-process, exactly like `couple`'s existing read-only adapters call
`budget`'s and `expense`'s use cases. `budget` and `expense` never import or reference `identity` — the
dependency arrow is one-way, `identity → budget` and `identity → expense`, same shape ADR-0013 already
uses for `couple`.

The new `budget`/`expense` use cases and their new `BudgetRepository`/`ExpenseRepository` methods return
`Unit`, mirroring `BudgetRepository.create`/`ExpenseRepository.create`: there is no caller-relevant
alternative outcome (deleting zero rows because the person owns nothing is a normal, silent no-op, not a
failure) — a datastore failure surfaces as an infrastructure exception, never a domain value.

**Alternative considered**: have `identity` reach directly into `budget`'s and `expense`'s repositories.
Rejected — skips the use-case layer ADR-0013 requires the adapter to call, and would let `identity`'s
infrastructure depend on another context's persistence internals instead of its public application API.

### Email neutralization format carries the person's own id, not a second column

Neutralizing the email means replacing the stored `EmailValueObject` with a value that (a) still satisfies
`EmailValueObject`'s own format rule — no special-casing in the value object for a "deleted" email, (b) can
never collide with a real signup, and (c) is traceable back to the deleted person. `deleted+<personId>@deleted.invalid`
(built with `EmailValueObject.of(...)`, which already accepts anything matching its regex) satisfies all
three: unique because `personId` is unique, syntactically valid, and identifiable by the same id every other
context already uses to reference a person — no new "original email" column needed, since the row itself
(same `id`, status `DELETED`) *is* the audit record. The original email string becomes unreadable from the
row, but the row's continued existence at its stable `id` is what "kept for audit history" means here — the
same anchor budgets/expenses already used before deletion.

**Alternative considered**: keep the original email in a second column and blank/replace only the
uniqueness-bearing one. Rejected as unnecessary — nothing in the spec requires the literal original string
to remain queryable, only that the record stay identifiable, which the stable `id` already provides.

### All sessions revoked, not "all except current"

Unlike `UpdatePasswordUseCase` (which spares the session that performed the rotation), account deletion
revokes **every** live session, including the one making the request — there is no account left for any
session, including this one, to belong to. This needs a new `SessionRepository.revokeAllForPerson(personId)`
(no exclusion), distinct from the existing `revokeAllForPersonExcept`.

### Route: `DELETE /persons/me` on `PersonController`, JSON body carries the confirmation password

Placed alongside the other self-service profile routes (`PATCH /persons/me/name`, `/email`, `/password`)
rather than on `AuthenticationController` (which owns session lifecycle, not person lifecycle) — deleting
the account is fundamentally an operation on the person resource, of which ending the session is one of
several effects. `DELETE` with a JSON body is unusual but valid HTTP and already how this codebase would
express "step-up-confirmed removal of `/persons/me`"; the alternative of a body-less `DELETE` plus a
separate re-auth step would split one atomic business operation across two requests for no benefit.

**Alternative considered**: `POST /persons/me/deletion` (avoiding a body on `DELETE`). Rejected — `DELETE
/persons/me` reads directly as "delete the resource `/persons/me`," matching this codebase's existing
`/persons/me/*` sub-resource convention, and Micronaut supports a request body on `@Delete` routes without
friction.

## Risks / Trade-offs

- **[Risk]** No real cross-repository transaction means a crash *between* steps 3–4 (budget cascade
  succeeded, expense cascade not yet attempted) leaves budgets gone but expenses intact, with the person
  still `ACTIVE`. → **Mitigation**: the operation is safely retryable in this state (person is still active,
  still logged in, already proved their password) — retrying re-runs the now-idempotent hard-delete (nothing
  left to delete is a no-op, not an error) and completes the rest of the sequence.
- **[Risk]** A crash *after* the person write (step 5) but *before* session revocation (step 6) leaves the
  account deleted but its sessions still resolvable at the token/session-table level. → **Mitigation**:
  every other identity operation that resolves a person from a session (`GET /persons/me`, name/email/password
  updates) already treats a session whose person is no longer active as the same neutral `401` a missing
  session produces (`PersonRepository.findById` collapses non-active to absent) — so a stray un-revoked
  session cannot be used for anything beyond that same neutral rejection until it naturally expires.
- **[Trade-off]** The hard-delete cascade is genuinely destructive and unrecoverable, unlike `budget-delete`'s
  soft delete. This is intentional per the `identity` README ("removidos de forma definitiva") and is called
  out as **BREAKING** in the proposal, not a bug to fix.

## Open Questions

- One combined `PersonOwnedFinancialsPort.deleteAllOwnedBy(personId)` vs. two separate ports/methods (one
  per producing context)? Leaning toward one port with two calls inside the adapter (keeps `identity`'s
  vocabulary simple — "delete everything I own" — while the adapter, not the port, knows it happens to be
  two contexts today) but leaving this for `/opsx:apply` to settle against how `couple`'s existing ports are
  shaped.
- Exact wire shape of the confirmation body — `{ "password": "..." }`, matching `UpdateEmailRequest`'s /
  `UpdatePasswordRequest`'s existing `password` field name — assumed, not re-litigated here.
