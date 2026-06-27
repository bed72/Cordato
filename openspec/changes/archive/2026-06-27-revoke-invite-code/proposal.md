## Why

An invite `code` is a **bearer token**: anyone holding it can redeem it and pair with the creator. Today a
code can only die **passively** — by being redeemed (`accept-invite-code`) or by expiring ~1 day after it is
minted. The creator who shares a code with the wrong person, changes their mind, or suspects the token leaked
has **no way to kill it before then**, leaving an open pairing window for up to a full day. This change gives
the creator active control over the token they minted.

## What Changes

- Add a **`revoke-invite-code`** capability: the creator of a pending invite can invalidate it immediately,
  closing the redemption window on demand.
- Introduce a new `revoked_at: datetime | None` field on `InviteCodeEntity`, **distinct from `consumed_at`**:
  *revoked* means "killed by its creator", *consumed* means "redeemed into a pair". Conflating the two would
  lie in the audit trail. `InviteCode` remains **not** a soft-delete entity (no `deleted_at`); its lifecycle
  is `created → (consumed | revoked | expired)`.
- The revoke is **owner-scoped**: a code is identified by its token, and only its `creator_id` may revoke it.
  A request from anyone else is rejected as **not-found** — never revealing that the token exists (no
  enumeration), consistent with `accept-invite-code`.
- Revoke transition rules: revoking an **already-consumed** code is rejected (it is already a pair — it
  cannot be unwound here); revoking an **already-revoked** code is **idempotent** (a no-op that preserves the
  original `revoked_at`); expiry does not block a revoke (killing a soon-to-expire token is still valid).
- **`accept-invite-code` now also rejects a revoked code** (a new `InviteCodeRevokedError`), exactly as it
  already rejects expired and consumed codes — a revoked token is not redeemable.
- Ships as the current **in-memory vertical slice** behind the existing ports — no ORM, no web. One new port
  method (`revoke`) mirrors the existing `consume`; no port signature is broken.

## Capabilities

### New Capabilities

- `revoke-invite-code`: The creator of a pending invite code can revoke it by token, immediately and
  idempotently invalidating the bearer token; owner-scoped, rejecting a consumed code and a non-owner request.

### Modified Capabilities

- `accept-invite-code`: redemption now additionally rejects a **revoked** code (alongside unknown, expired,
  and consumed), so a creator-killed token can never form a pair.
- `create-invite-code`: a freshly minted code now starts **un-revoked** (`revoked_at` null), the initial
  state of the new lifecycle field.

## Impact

- **New code (pairing):** `domain/errors/invite_code_revoked_error.py` (`InviteCodeRevokedError`);
  `application/data/revoke_invite_code_data.py` (`RevokeInviteCodeData`);
  `application/use_cases/revoke_invite_code_use_case.py` (`RevokeInviteCodeUseCase`).
- **Modified code (pairing):** `domain/entities/invite_code_entity.py` gains `revoked_at`, `is_revoked`, and a
  `revoke(at)` method, with the factory starting it null; `application/interfaces/invite_code_repository_interface.py`
  gains an async `revoke` method; `infrastructure/repositories/invite_code_repository.py` implements it;
  `application/use_cases/accept_invite_code_use_case.py` adds the revoked-code guard.
- **Tests:** unit tests for the new error, the entity transitions, the revoke use case, and the extended
  accept guard; integration tests wiring `RevokeInviteCodeUseCase` (and the accept-rejects-revoked path) to
  the real in-memory repository.
- **No impact on** `domain/` of other features, dependencies, or the deferred ORM/web edge. No new value
  object (the token stays a plain `str`), enum, or virtual object.
