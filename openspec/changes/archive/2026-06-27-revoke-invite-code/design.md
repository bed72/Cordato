## Context

Pairing begins when a person mints a single-use invite (`create-invite-code`) and ends a redemption when a
partner accepts it (`accept-invite-code`). The `InviteCodeEntity` today has exactly three lifecycle facts:
`created_at`, `expires_at` (fixed one day past creation, a domain rule), and `consumed_at` (null until
redeemed). The token (`code`) is an opaque CSPRNG **bearer** string — possession is sufficient to redeem.

The gap: once minted, a code can only leave the live state **passively** — redeemed or expired. The creator
has no active control. Because the token is a bearer secret, an accidental leak or a wrong recipient leaves a
pairing window open for up to a full day. This change adds creator-initiated invalidation.

The existing entity is the right place for the new state; the existing ports are the right seams. No web/ORM
exists yet — this ships as the in-memory vertical slice, exactly like the surrounding pairing capabilities.

## Goals / Non-Goals

**Goals:**
- Let the **creator** invalidate a pending invite immediately, by token, owner-scoped.
- Model "revoked" as a first-class lifecycle fact, distinct from "consumed", so the audit trail stays honest.
- Make `accept-invite-code` reject a revoked code, closing the redemption path the revoke is meant to shut.
- Keep the change behind the existing ports — one additive port method, no broken signatures.

**Non-Goals:**
- **Listing** a creator's pending invites (a separate capability; revoke here takes the token directly).
- **Un-revoking** / restoring a killed code (revocation is final; mint a new code instead).
- Turning `InviteCode` into a soft-delete entity — it gains `revoked_at`, not `deleted_at`; the
  derive-don't-store and soft-delete rules of other entities do not apply to it.
- Any ORM/web wiring (deferred project-wide).

## Decisions

### Decision 1: A dedicated `revoked_at` field, not a reuse of `consumed_at`
A new `revoked_at: datetime | None` on `InviteCodeEntity`, set null by the `create` factory, stamped by a new
`revoke(at)` method, exposed through an `is_revoked` property — mirroring `consumed_at`/`consume`/`is_consumed`.

*Why over reusing `consumed_at`:* "consumed" carries a precise meaning — *a pair was formed from this code*.
A revoked code formed no pair. Overloading `consumed_at` to also mean "killed" would make every reader (audit,
accept's guards, any future history view) unable to tell a redemption from a cancellation, and would corrupt
the audit trail. The lifecycle becomes `created → (consumed | revoked | expired)`, three mutually-exclusive
exits, each with its own timestamp where it has one.

*Why not `deleted_at` (soft-delete):* `InviteCode` is deliberately **not** a soft-delete entity in the domain
model. Soft-delete is for Budget/Expense/Pair (mistake recovery + audit visibility, `list_including_removed`).
A revoked invite is not "hidden but recoverable"; it is a terminal lifecycle state. Using `deleted_at` would
wrongly invite restore/audit semantics it does not have.

### Decision 2: Identify the code by **token**, authorize by **creator ownership**
The command is `RevokeInviteCodeData { code: str, requester_id: str }`. The use case resolves the code via the
existing `InviteCodeRepositoryInterface.find_by_token` (no new lookup method), then checks
`invite.creator_id == requester_id`.

*Why token, not a stored invite id:* it reuses `find_by_token` (the same seam `accept` uses), and the token is
precisely the thing being killed ("this token leaked — kill it"). There is no list-my-invites capability yet,
so an id-based lookup would need a new `find_by_id` port method for no extra value.

*Why a non-owner is treated as not-found:* per-person authorization forbids acting on another person's invite.
Returning a distinct "not yours" error would reveal that the token exists — account/token enumeration. So a
non-owner request raises the same `InviteCodeNotFoundError` as an unknown token, matching the non-leaking rule
`accept-invite-code` already follows.

### Decision 3: Revoke transition rules — consumed errors, revoked is idempotent, expiry is irrelevant
- **Consumed** code → raise `InviteCodeAlreadyConsumedError` (reused). A redeemed code is already a pair;
  revoke does not unwind pairs (dissolving is `dissolve-pair`).
- **Already-revoked** code → **idempotent no-op**: return success **without re-stamping** `revoked_at`, so the
  original revocation instant is preserved. Revoking twice reaches the same terminal state; erroring would be
  hostile for a retriable, end-state-converging action (DELETE-like semantics).
- **Expired** (but not consumed, not revoked) → revoke **succeeds**. Killing a token that is about to expire is
  still meaningful; expiry is an orthogonal, time-derived fact, not a transition the creator performed.

*Why idempotent on re-revoke but error on consumed:* the two differ in whether the end-state matches intent.
Re-revoking already yields "this token is dead" — the caller's goal — so it is a no-op. A consumed code's end
state is "a pair exists"; silently treating a revoke as success there would mislead the creator into thinking
they closed a window that is actually an active pairing. That deserves an explicit error.

### Decision 4: Guards live in the use case; the entity method just stamps
`revoke(at)` stamps `revoked_at` unconditionally, exactly as the existing `consume(at)` stamps `consumed_at`
without guarding. The precondition checks (found, owned, not consumed, idempotent-if-revoked) live in
`RevokeInviteCodeUseCase`. This matches the established style of the surrounding code and keeps the entity a
pure state holder; the use case orchestrates the policy.

### Decision 5: One additive port method `revoke`, mirroring `consume`
`InviteCodeRepositoryInterface` gains `async def revoke(self, invite_code) -> None`, persisting a code whose
`revoked_at` was just stamped. In the in-memory adapter it is the same keyed overwrite as `consume`/`create`,
but a distinct, intention-named method states the operation at the port (the same reason `consume` exists
separately from `create`). No existing signature changes.

### Decision 6: `accept-invite-code` gains a revoked guard, ordered with the other state checks
Accept already guards expired then consumed after resolving the token. A `if invite_code.is_revoked: raise
InviteCodeRevokedError()` check joins them. `InviteCodeRevokedError` carries a short, non-leaking pt-BR
message in the same family as `InviteCodeExpiredError` / `InviteCodeAlreadyConsumedError`.

## Risks / Trade-offs

- **A leaked token may be redeemed before the creator revokes** → revoke shrinks but cannot eliminate the
  window; it is creator-initiated and only as fast as the creator reacts. Accepted: the ~1-day expiry remains
  the backstop, and revoke is strictly better than today's "wait it out".
- **Token-based revoke needs the creator to still hold the token** → acceptable for this slice; a future
  `list-invite-codes` capability would let a creator revoke by selecting from their own pending invites.
- **Idempotent re-revoke could mask "I revoked the wrong code"** → low impact; the action is owner-scoped and
  the end state is the intended one. The preserved original `revoked_at` keeps the audit truthful.
- **New lifecycle field touches the shared entity** → `create-invite-code` and `accept-invite-code` specs are
  updated in the same change (initial null state; revoked rejected), keeping spec and code in lockstep.

## Migration Plan

Additive and behind existing ports; no data migration (no persistence store yet). Steps: extend the entity
(`revoked_at` + `revoke` + `is_revoked`, factory starts null) → add the error → add the port method and its
in-memory implementation → add the revoke command + use case → add the accept guard → tests → gate → guard →
archive. Rollback is reverting the change set; no external state is touched.

## Open Questions

None blocking. A future `list-invite-codes` (revoke-by-selection) and whether expiry should be surfaced
distinctly from revoked in any future read-model are deferred, not part of this change.
