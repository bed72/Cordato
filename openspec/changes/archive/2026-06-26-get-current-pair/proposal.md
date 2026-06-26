## Why

Pairing can already create an invite, accept it (forming the pair), dissolve it, and read the two
couple-level panoramas (`couple-expenses`, `couple-budget`). But there is **no slice that reads the
relationship itself** — nothing answers the most basic question the UI asks before it can render anything
shared: *"am I paired? with whom, and since when?"*. The couple views all **presuppose** a resolved pair
(they raise `NotPairedError` when there is none); none of them *reports* the pair. This closes the last
read gap in pairing — the status read that the whole "couple" surface hangs off of.

## What Changes

- Add a read-only capability that returns the reader's **current pair**: the live pair they belong to,
  resolved from their own perspective — the **partner's identity** (`partner_id`, `partner_name`) plus the
  pair's `pair_id` and `paired_since` (the pair's `created_at`).
- **"Not paired" is a valid answer, not an error.** This is the deliberate inversion of `couple-budget` /
  `couple-expenses`: a *status* read asks "am I paired?" precisely because the answer may be no. With no
  live pair the use case returns **nothing** (`None`) — it never raises `NotPairedError`. That error stays
  the guard for the couple *views*, which genuinely cannot exist without a pair.
- **Reader-relative.** The partner is "the member of the pair who is not the reader" — a domain rule, not a
  mapper detail. Model it as a `CurrentPairVirtualObject` (read-time projection over the stored
  `PairEntity` + the partner's identity; never stored), mirroring `CoupleExpenseVirtualObject`'s
  mine/theirs resolution. The use case is `reader`-scoped: it only ever reads the reader's own pair.
- Resolve the partner's **name** through pairing's existing identity ACL — extend
  `PersonDirectoryInterface` with `async def find_active_profile(person_id) -> PartnerProfileData | None`,
  the natural broadening of a *directory* (already pairing's seam to `identity`) from a bare active-check
  to id→profile. `pairing` still never imports `identity`; the concrete adapter is wired at the
  composition root. A new `PartnerProfileData` (id, name) is the cross-context read shape it returns.
- A live pair guarantees an active partner (account deletion **dissolves** the pair — see `delete-account`),
  so the partner profile is expected present; the use case treats an unresolvable partner as an integrity
  violation, not a routine `None`.
- Reuse the existing `PairRepositoryInterface.find_active_by_person` as-is to resolve the live pair. No new
  repository, no new entity, no new error, no behavior change to any prior slice.
- Ships as the current in-memory vertical slice: new domain `CurrentPairVirtualObject`, the application
  `CurrentPairData` read-model + `CurrentPairDataMapper` + `GetCurrentPairUseCase`, the
  `PersonDirectoryInterface` extension + `PartnerProfileData`, exercised through the existing in-memory
  `PairRepository` and a hand-written `FakePersonDirectory`. No ORM/web yet.

- **Out of scope (deferred):** the real identity-backed `PersonDirectory` adapter and composition-root
  wiring (no app bootstrap exists yet — the port + fake stand in, exactly as for the other ACL ports); any
  HTTP handler, pagination, or ORM model/mapper.

## Capabilities

### New Capabilities

- `current-pair`: A person can read their own current pair — the live pair resolved from their
  perspective, returning the partner's identity (`partner_id`, `partner_name`) and the pair's `pair_id` and
  `paired_since`; returning nothing (not an error) when they are in no live pair; scoped to the requester.

### Modified Capabilities

<!-- None. accept-invite-code keeps its requirements verbatim; this slice only *adds* a method to the
     shared PersonDirectoryInterface port (an additive, non-behavioral extension of an existing seam) and
     reads through the existing PairRepository port. No prior capability's REQUIREMENTS change. -->

## Impact

- **New domain (pairing):** `CurrentPairVirtualObject` — composes the stored `PairEntity` + the partner's
  identity, derives the reader-relative partner (`partner_id`, `partner_name`) and exposes `pair_id` /
  `paired_since`. No identity, no lifecycle, never stored. No new error.
- **Port change (pairing):** `PersonDirectoryInterface` gains `find_active_profile(person_id) ->
  PartnerProfileData | None` (additive; `is_active` untouched). New application shape `PartnerProfileData`.
- **New application shapes (pairing):** `CurrentPairData` (the public read-model), `CurrentPairDataMapper`,
  `GetCurrentPairUseCase`. `PairRepositoryInterface.find_active_by_person` reused as-is.
- **New adapters:** none in production this stage — the identity-backed `PersonDirectory` stays deferred to
  composition-root wiring; a `FakePersonDirectory` (extended with the profile lookup) stands in for tests.
  The in-memory `PairRepository` is reused unchanged.
- **No new dependency.** No web/ORM introduced; the slice runs and is tested entirely in-memory.
- **Tests:** a unit test for `CurrentPairVirtualObject` (partner resolution when the reader is `person_a`
  and when the reader is `person_b`); use-case tests for every scenario (paired as `person_a` → partner is
  `person_b`; paired as `person_b` → partner is `person_a`; no live pair → `None`; dissolved-only pair →
  `None`; partner unresolvable → integrity error); an integration test wiring the in-memory `PairRepository`
  + `FakePersonDirectory` through the use case. Extends `FakePersonDirectory` under `tests/pairing/fakes/`.
