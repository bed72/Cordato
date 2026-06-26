## Why

The pairing context can now form a pair and render every couple-level read on top of it
(couple-expenses, couple-budget). What it still cannot do is **end** the relationship. The pair's whole
reason to exist is to be a *reversible* lens — *"a couple is a point of view, not an owner"* and
*"reversible without loss"*. Without dissolve, that promise is only asserted, never exercised: there is no
way to take the shared view down, and a person who pairs is paired forever. This change delivers the
**pairing lifecycle's closing move** — soft-dissolving the pair so the shared view disappears while every
budget and expense each partner owns stays untouched.

## What Changes

- Add the pairing context's first **lifecycle/mutation** use case: **dissolve pair**. Given the requester
  (`requester_id`), the system resolves the requester's **live pair**, stamps it dissolved (soft-delete),
  and persists that. Afterwards the couple reads (couple-expenses, couple-budget) find no live pair and the
  shared view is simply gone — both people are back to behaving like two unpaired individuals who have
  history.
- **No data is moved or destroyed.** Dissolve touches **only** the `Pair` row's `deleted_at`. Not one
  budget, expense, or invite is read, copied, rewired, or deleted. This is the literal embodiment of
  *"unpairing never destroys nor moves anyone's data"* — the flat reference graph is what makes it a
  one-field write.
- **Authorization is intrinsic, not bolted on.** The pair is resolved **by the requester** via the
  existing `PairRepositoryInterface.find_active_by_person(requester_id)`, which returns only a live pair the
  requester belongs to (`person_a` or `person_b`). A person therefore can only ever dissolve *their own*
  live pair; there is no lookup path to someone else's. A requester in no live pair has no couple to
  dissolve → reuse the existing `NotPairedError` (pt-BR, non-leaking). No new authorization machinery.
- **The ≤1-live-pair invariant is reaffirmed, not changed.** Dissolving is the only way out of the live
  state for a pair; once dissolved it never blocks a future pairing (`find_active_by_person` already
  excludes soft-deleted pairs), so the same two people — or either with someone new — can pair again later,
  forming a *new* `Pair` (new id), leaving the dissolved one in history. N dissolved pairs in a person's
  past is fine; at most one is ever live.
- Add a domain mutation to the **existing** `PairEntity` — `dissolve(at)` — that stamps `deleted_at`,
  mirroring `InviteCodeEntity.consume(at)` exactly: a simple, single state transition; the live-pair guard
  lives at the use-case boundary (you can only reach a live pair through `find_active_by_person`), so the
  method needs no defensive guard and **no new field is added** (`deleted_at` already exists).
- Extend the `PairRepositoryInterface` with a `dissolve(pair)` method that persists a pair whose
  `deleted_at` has just been stamped — mirroring `InviteCodeRepositoryInterface.consume(invite_code)`. The
  in-memory `PairRepository` implements it (re-store by id). No new repository, no new entity, no new error.
- Ship a runnable, fully-tested vertical slice for the current stage: the new domain behavior
  (`PairEntity.dissolve`), the application command + `DissolvePairUseCase` + `DissolvePairData`, exercised
  through the existing in-memory `PairRepository` and the real determinism `Clock` gateway. The use case
  returns nothing (`None`): dissolve is a pure command whose only outcome is the absence of the shared
  view, so there is no read-model to return and thus no output mapper.

- **Out of scope (deferred to their own changes):**
  - **delete-account** (the hard-delete "nuclear option"), which dissolves any live pair *as a
    consequence*. This change ships the reusable dissolve building block first; account deletion composes
    it later.
  - Re-pairing flow changes — none are needed; `accept-invite-code` already forms a fresh pair once no live
    pair exists.
  - Any notification emitted on dissolve, pagination, HTTP handler, or ORM model/mapper.

## Capabilities

### New Capabilities
- `dissolve-pair`: Soft-dissolving the requester's live pair — resolving the live pair the requester
  belongs to, stamping it `deleted_at` (soft-delete), and persisting that, so the shared couple view
  disappears while both partners keep every budget and expense intact. Rejects a requester who is in no
  live pair (`NotPairedError`). Nothing besides the pair's `deleted_at` is touched; the ≤1-live-pair
  invariant is preserved and re-pairing later forms a new pair.

### Modified Capabilities
<!-- None. accept-invite-code, create-invite-code, couple-expenses, and couple-budget keep their
     requirements verbatim. This slice adds a new entity mutation and a new repository method, but changes
     no prior capability's behavior — the couple reads already key off "live pair", which dissolve simply
     makes false. -->

## Impact

- **New domain behavior (pairing):** `PairEntity.dissolve(at)` — stamps `deleted_at`, the only transition
  out of the live state (mirrors `InviteCodeEntity.consume`). No new field; `deleted_at` already exists.
- **Modified port (pairing):** `PairRepositoryInterface` gains `dissolve(pair) -> None` (persist a
  just-dissolved pair), mirroring `InviteCodeRepositoryInterface.consume`. `find_active_by_person` and
  `create` are unchanged.
- **New application shapes (pairing):** `DissolvePairData` (command input — the `requester_id`),
  `DissolvePairUseCase` (resolve live pair → `NotPairedError` if none → `dissolve(now)` → persist →
  `None`). No read-model, no output mapper.
- **Modified adapter (pairing):** the in-memory `PairRepository` implements `dissolve` (re-store by id).
- **Reused, unchanged:** `NotPairedError`, the `Clock` gateway, `find_active_by_person`. No new error, no
  new dependency, no web/ORM introduced; the slice runs and is tested entirely in-memory.
- **Tests:** unit test for `PairEntity.dissolve` (stamps `deleted_at`; identity equality intact); use-case
  tests for every scenario (live pair as `person_a` → dissolved + persisted; live pair as `person_b` →
  dissolved + persisted; requester in no live pair → `NotPairedError`; requester whose only pair is already
  dissolved → `NotPairedError`); and an integration test wiring the in-memory `PairRepository` + real
  `Clock` through the use case, asserting the pair is gone from `find_active_by_person` afterward and that
  re-pairing the same person then succeeds. Reuses the existing `FakePairRepository` (or the in-memory
  `PairRepository`) under `tests/pairing/`.
