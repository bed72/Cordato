## Why

A couple is the heart of Trocado — *"a couple is a point of view, not an owner"* — and a couple is born
the moment one person **invites** another and the other **accepts**. Nothing of the shared view (couple
budget, couple expenses) can exist until a `Pair` exists, and a `Pair` is only ever created by consuming
a valid invite. The invite code is therefore the natural keystone after the individual core is complete:
it is the lowest-coupling entity of the `pairing` context (it points only to its creator, owns no money)
and it produces the single artifact the *accept* step will later consume to form the pair. This change
introduces the `pairing` context by its first, smallest slice: **creating** the invite code.

## What Changes

- Introduce the `pairing` context with its first use case: **create a new invite code** for a creator
  (`creator_id`) — a short, single-use token a partner will later redeem to form the pair.
- Enforce the domain rules for an `InviteCode` at creation time: the `code` is a short token produced by
  a **CSPRNG** (a cryptographic source — never predictable, never sequential); `expires_at` is set to
  roughly **one day** after `created_at` (the TTL is a domain rule, fixed by the entity factory);
  `consumed_at` starts **null** (unused); the code receives an opaque `id` and a `created_at` from the
  determinism ports. The code starts live and unconsumed.
- Define the ports this use case depends on:
  - an async `InviteCodeRepositoryInterface` for persistence;
  - a new async `TokenGeneratorInterface` (a **gateway** port) that yields the CSPRNG token — async by
    contract, exactly like the existing determinism ports, so the day it becomes a genuine external token
    service it slots in behind the same contract. Reuse the existing core `ClockInterface` and
    `IdentifierProviderInterface` — no new determinism ports.
- Provide working adapters for the current (framework-less, ORM-less) stage: an **in-memory** invite-code
  repository and a **CSPRNG token generator** gateway backed by the stdlib `secrets` module (its sync
  call wrapped off-loop at the adapter edge). This yields a vertical slice that runs and is fully
  testable today.
- The `code` is stored as a plain `str` — an opaque token carries no invariant and no behavior, so per
  *"a value object must earn its existence"* it is **not** wrapped in a value object.
- **Out of scope (deferred to their own changes):**
  - **accept-invite** — validating a code (not expired, not consumed, not self-invite, neither party
    already paired) and creating the `Pair` while stamping `consumed_at`. This is the next slice and is
    where `PairEntity`, the pairing invariants, and the expiry/consumption *checks* live.
  - listing or looking up a person's codes; revoking a code; limiting how many active codes a person may
    hold; verifying `creator_id` refers to an existing/active person (authorization arrives with auth).
  - any HTTP/web handler (no framework chosen) and any ORM-backed persistence / `InviteCodeModel` (no ORM
    chosen).

  This change only *mints* an invite code.

## Capabilities

### New Capabilities
- `create-invite-code`: Minting a new single-use invite code for a creator — generating a short,
  unpredictable CSPRNG token; fixing the ~1-day expiry from the creation instant as a domain rule;
  starting it unconsumed; assigning identity and timestamp; persisting it; and returning the code's
  public data.

### Modified Capabilities
<!-- None. This is a new domain capability; the existing individual-core capabilities
     (register-person, record-expense, create-budget, active-budget, core-determinism,
     dev-environment) are unaffected. -->

## Impact

- **New module:** `src/trocado/features/pairing/` with `domain/`, `application/`, `infrastructure/`.
- **New domain:** `InviteCodeEntity` (with its `create(...)` factory fixing the TTL and `consumed_at =
  null`). No domain error is needed at *creation* — token generation cannot fail and `creator_id` is
  stored as given (its authorization check is deferred). Expiry/consumption errors arrive with
  *accept-invite*.
- **New ports + adapters:**
  - `InviteCodeRepositoryInterface` (port) + in-memory `InviteCodeRepository` (adapter).
  - `TokenGeneratorInterface` (port) + `TokenGenerator` (gateway adapter, CSPRNG via `secrets`).
  - Reuses core `ClockInterface` / `IdentifierProviderInterface` and their existing adapters.
- **New application shapes:** `CreateInviteCodeData` (command — `creator_id`), `InviteCodeData`
  (read-model), `InviteCodeDataMapper`.
- **No new dependency.** `secrets` is stdlib; no web/ORM dependency added; no `InviteCodeModel` /
  `InviteCodeModelMapper` (no table yet).
- **Tests:** unit tests for `InviteCodeEntity` (factory: TTL, unconsumed, identity), the use case (every
  scenario, with fakes for the repository, token generator, clock, and id), the in-memory repository, and
  the CSPRNG token generator gateway; plus an integration test wiring the real in-memory repository + real
  token generator + core determinism adapters through the use case. Reuses `tests/core/fakes/` (clock,
  id) and adds `FakeInviteCodeRepository` and `FakeTokenGenerator` under `tests/pairing/fakes/`.
