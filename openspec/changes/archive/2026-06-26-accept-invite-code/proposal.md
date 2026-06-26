## Why

A couple is the reason Trocado exists — *"a couple is a point of view, not an owner"* — and a couple is
born the instant an invite is **accepted**. The previous slice (`create-invite-code`) mints a single-use
token but nothing redeems it, so the `Pair` — the keystone the whole shared view hangs off — still does
not exist. This change closes that loop: **accepting a valid invite consumes the code and forms the
pair**, completing the core of the `pairing` context and unlocking every couple-level view that follows.

## What Changes

- Add the `pairing` context's second use case: **accept an invite code**. Given an invite `code` token
  and the accepting person (`accepter_id`), the system validates the code, **consumes** it (stamps
  `consumed_at`), and **creates a `Pair`** between the code's creator and the accepter — atomically, as a
  single-use redemption.
- Introduce the `PairEntity` — `id`, `created_at`, `person_a_id` (the creator), `person_b_id` (the
  accepter), `deleted_at` (soft-delete = dissolved). It owns no money, no budget, no expense: a thin link
  between two individuals, born live (`deleted_at = null`) via its `create(...)` factory, equal by `id`.
- Enforce the redemption invariants, each a domain rule with its own pt-BR non-leaking error:
  - the `code` must **match a known invite** (else `InviteCodeNotFoundError`);
  - it must **not be expired** — `expires_at` strictly after the redemption instant (else
    `InviteCodeExpiredError`);
  - it must **not already be consumed** (else `InviteCodeAlreadyConsumedError`);
  - the accepter must **not be the creator** — no self-pairing (else `SelfPairingError`);
  - **neither** the creator nor the accepter may already be in a live pair — the ≤1-active-pair invariant
    (else `AlreadyPairedError`, which never reveals *which* party is paired);
  - **both** the creator and the accepter must be **active people** (else `PersonNotActiveError`).
- Verify the active-person rule **without any cross-module dependency**. `pairing` defines its **own**
  consumer-owned port — `PersonDirectoryInterface` (`async def is_active(person_id) -> bool`) — an
  anti-corruption seam in pairing's vocabulary. The use case depends only on this ABC; the concrete
  identity-backed adapter is wired at the composition root (the only place allowed to know both modules),
  exactly as the determinism ports are shared via `core/` rather than imported across contexts. `pairing`
  never imports `identity`.
- Grow the existing pairing ports to support redemption (no behavior change to `create-invite-code`):
  - `InviteCodeRepositoryInterface` gains `find_by_token(code) -> InviteCodeEntity | None` and `consume`
    (persist the now-stamped code);
  - a new `PairRepositoryInterface` with `find_active_by_person(person_id) -> PairEntity | None`
    (soft-delete aware — live pairs only) and `create(pair) -> None`.
- Add the domain redemption behavior to `InviteCodeEntity`: `is_expired(reference)` and `is_consumed`
  query methods plus a `consume(at)` mutator — keeping the validity logic in the domain, not the use case.
- Ship a runnable, fully-tested vertical slice for the current stage: in-memory `PairRepository`, the
  in-memory `InviteCodeRepository` extended with the new reads/update, and (for tests) a hand-written fake
  `PersonDirectory`. Reuses the core determinism ports (`ClockInterface`, `IdentifierProviderInterface`).

- **Out of scope (deferred to their own changes):**
  - **dissolve-pair** (soft-deleting a live pair) and the couple views (couple budget / couple expenses).
  - The **real** identity-backed `PersonDirectory` adapter and the composition-root wiring (no app
    bootstrap / web framework exists yet — deferred, not skipped; the port and a fake stand in today).
  - revoking/listing codes; capping active codes; any HTTP handler; any ORM model/mapper for `Pair` or
    `InviteCode` (no ORM chosen — no `deleted_at` index, no DB uniqueness yet).

## Capabilities

### New Capabilities
- `accept-invite-code`: Redeeming a valid invite to form a pair — matching the token to a live, unexpired,
  unconsumed code; rejecting self-pairing, an already-paired creator or accepter, and inactive people;
  then atomically consuming the code (stamping `consumed_at`) and creating the live `Pair` between creator
  and accepter, returning the pair's public data.

### Modified Capabilities
<!-- None. `create-invite-code`'s requirements are unchanged: this slice adds new repository *methods*
     (find-by-token, consume) and new entity *behavior* (redemption), but the minting capability's
     spec-level behavior is untouched. The existing individual-core capabilities are unaffected. -->

## Impact

- **New domain:** `PairEntity` (+ `create(...)` factory fixing `deleted_at = null`); new pairing errors
  `InviteCodeNotFoundError`, `InviteCodeExpiredError`, `InviteCodeAlreadyConsumedError`,
  `SelfPairingError`, `AlreadyPairedError`, `PersonNotActiveError` (pt-BR, non-leaking). New behavior on
  `InviteCodeEntity` (`is_expired`, `is_consumed`, `consume`).
- **New + grown ports:** new `PairRepositoryInterface` and `PersonDirectoryInterface` (consumer-owned ACL
  port); `InviteCodeRepositoryInterface` gains `find_by_token` + `consume`. Reuses core `ClockInterface` /
  `IdentifierProviderInterface`.
- **New + grown adapters:** in-memory `PairRepository`; the in-memory `InviteCodeRepository` implements the
  new methods. No `PairModel` / `InviteCodeModel` (no ORM yet). The real `PersonDirectory` adapter is
  deferred to composition-root wiring.
- **New application shapes:** `AcceptInviteCodeData` (command — `code`, `accepter_id`), `PairData`
  (read-model — `id`, `person_a_id`, `person_b_id`, `created_at`), `PairDataMapper`. New
  `AcceptInviteCodeUseCase`.
- **No new dependency.** No web/ORM introduced; the slice runs and is tested entirely in-memory.
- **Tests:** unit tests for `PairEntity` (factory, identity), the new `InviteCodeEntity` behavior, every
  use-case scenario (happy path + each rejection, with fakes for both repositories, the person directory,
  clock, and id), the in-memory `PairRepository`, and the extended `InviteCodeRepository`; plus an
  integration test wiring the real in-memory repositories + core determinism adapters + a fake person
  directory through the use case. Adds `FakePairRepository` and `FakePersonDirectory` under
  `tests/pairing/fakes/`; extends `FakeInviteCodeRepository`.
