## Context

Pairing has shipped invite creation, acceptance, dissolution, and both couple-level reads
(`couple-expenses`, `couple-budget`). What is still missing is the **status read of the relationship
itself** — "am I paired? with whom, since when?". Every couple view *presupposes* a resolved pair (each
raises `NotPairedError` when there is none) but none *reports* it. This change adds that read, following
every prior slice's pattern (pure `domain/`, async ports in `application/`, in-memory / gateway adapters,
fully testable without web/ORM) and reusing the existing `PairRepository` as-is.

Two questions of substance, both settled below: (1) what "not paired" means for a *status* read, and (2)
how to surface the partner's **name** without coupling `pairing` to `identity`.

## Goals / Non-Goals

**Goals:**
- Add `GetCurrentPairUseCase` returning the reader's live pair from their own perspective — `partner_id`,
  `partner_name`, `pair_id`, `paired_since` — or **nothing** when there is no live pair.
- Make "not paired" a first-class **answer** (`None`), never `NotPairedError`. This read is the deliberate
  inversion of the couple views.
- Keep the reader-relative partner resolution ("the member who is not the reader") in the **domain** — a
  `CurrentPairVirtualObject` — not in the use case or a mapper.
- Resolve the partner's name through pairing's existing identity ACL, **without** a `pairing → identity`
  import — by extending `PersonDirectoryInterface`.
- Ship a runnable vertical slice: reuse the in-memory `PairRepository`; extend the test `FakePersonDirectory`;
  no production identity-backed adapter yet.

**Non-Goals:**
- Any **write** through the view, **dissolve-pair**, or **delete-account** (those exist / are their own changes).
- The real identity-backed `PersonDirectory` adapter and its composition-root wiring (no app bootstrap /
  ORM exists yet — the port + fake stand in).
- Listing *past* (dissolved) pairs, pairing history, or invite-code status — separate reads.
- Any pagination, web handler, or ORM model/mapper.

## Decisions

**1. "Not paired" is `None`, not `NotPairedError` — the deliberate inversion of the couple views.**
`couple-budget` and `couple-expenses` raise `NotPairedError` because a *view over the couple* genuinely
cannot exist without a pair. This read is different in kind: it is the **status query** you run *to find
out whether* you are paired — so "no" is a valid, expected outcome, not an exceptional one. The use case
returns `CurrentPairData | None`, mirroring `GetActiveBudgetUseCase` returning `None` when there is no
active budget. Reuse of `find_active_by_person` makes a dissolved-only history indistinguishable from never
having paired — both yield `None`, which is exactly correct for a *current*-pair read. Alternative
rejected: raise `NotPairedError` for symmetry with the couple views — that would force every caller to wrap
the normal "you're single" case in a try/except, turning a status check into exception-driven control flow.

**2. `CurrentPairVirtualObject` — the reader-relative projection lives in the domain.**
`features/pairing/domain/virtual_objects/current_pair_virtual_object.py`. A frozen, slotted dataclass that
composes the stored `PairEntity` with the partner's resolved identity and derives the reader-relative view.
It holds `reader_id: str`, the `PairEntity`, and the partner's `partner_id` / `partner_name`, exposing:
- `pair_id -> str` = the pair's `id`
- `paired_since -> datetime` = the pair's `created_at`
- `partner_id -> str`, `partner_name -> str`

The defining rule — *the partner is the member of the pair who is not the reader* — is a domain truth about
reading a pair from one side, exactly the flavor of `CoupleExpenseVirtualObject`'s mine/theirs resolution,
so it belongs in a Virtual Object (the third domain shape: composes + derives, no identity, never stored),
not in the use case or the mapper. It earns its existence by that derivation, not as a bare carrier.

The construction shape keeps the reader-relative *selection* explicit. The use case resolves the partner id
(`pair.person_b_id if reader_id == pair.person_a_id else pair.person_a_id` — the established idiom from
`GetCoupleExpensesUseCase`), fetches the partner profile, and hands the VO `reader_id`, the entity, and the
partner's id+name. A self-check (the resolved partner id matches the fetched profile id) keeps the VO
internally consistent.

**3. The partner's name comes through `PersonDirectoryInterface`, extended — no `pairing → identity` import.**
`PersonDirectoryInterface` already *is* pairing's anti-corruption seam to `identity` (today: `is_active`).
A *directory* naturally maps id → person info, so broadening it from a bare active-check to an id→profile
lookup is the cohesive evolution, not a new responsibility. Add:
`async def find_active_profile(person_id: str) -> PartnerProfileData | None` — returns the **active**
person's `id` + `name`, or `None` for an unknown/inactive id (never raising, matching the port's existing
non-raising contract). `is_active` stays untouched; this is purely additive, so no prior capability's
behavior changes. `pairing` still never imports `identity`; the concrete adapter is wired at the
composition root. Alternatives rejected: (a) a *separate* `PartnerProfileReaderInterface` — duplicates the
seam that `PersonDirectory` already is, for the same id→identity question; (b) widening `couple-expenses`'
mine/theirs to carry names — orthogonal concern, and those reads are amount-centric, not identity-centric.

**4. `PartnerProfileData` — the cross-context read shape the directory returns.**
`features/pairing/application/data/partner_profile_data.py`: a frozen, slotted dataclass `(id: str, name:
str)`. It is the application-layer shape the gateway hands back (pairing's vocabulary for "an active
person's identity"), the counterpart of `PartnerExpenseData` / `PartnerActiveBudgetData`. A plain carrier —
no invariant, no behavior — so a `data` shape, not a value object (per "a value object must earn its
existence").

**5. A live pair guarantees an active partner; an unresolvable partner is an integrity error.**
`delete-account` dissolves any live pair, so a live pair implies both members are active — the partner
profile is **expected present**. If `find_active_profile` returns `None` for a partner of a *live* pair,
that is a data-integrity violation, not the routine single case (decision 1, which is about the *reader*
having no pair at all). The use case raises a plain `RuntimeError` with a non-leaking message rather than
fabricating a nameless pair or swallowing it as `None`. No new domain error class is introduced for this —
it is an invariant breach, not a domain rule a caller is expected to handle. (If a richer signal is ever
needed, it graduates to a named error in its own change.)

**6. Reuse `find_active_by_person`; no new repository, entity, or error.**
The reader's live pair is resolved with the existing `PairRepositoryInterface.find_active_by_person(reader_id)`
(already soft-delete-aware — it surfaces only `deleted_at`-null pairs), exactly as the couple reads do. The
only new production units are the Virtual Object, the `PersonDirectoryInterface` method + `PartnerProfileData`,
and the `CurrentPairData` read-model + `CurrentPairDataMapper` + `GetCurrentPairUseCase`.

**7. The flow.**
```
reader_id
  → PairRepository.find_active_by_person(reader_id)   # None → return None (single, not an error)
  → resolve partner_id (the member who is not the reader)
  → PersonDirectory.find_active_profile(partner_id)   # None on a live pair → integrity error
  → CurrentPairVirtualObject(reader_id, pair, partner_id, partner_name)
  → CurrentPairDataMapper.to_data(...)                # → CurrentPairData
```
The two reads have a real data dependency (the partner id comes from the pair), so they are awaited
**sequentially**, not gathered — honoring the "gather only independent awaits" rule.

## Risks / Trade-offs

- **A dissolved-only history reads identically to never-paired (both `None`).** Intentional for a
  *current*-pair read; surfacing past pairs is a separate history capability, explicitly a non-goal.
- **Extending `PersonDirectoryInterface` touches an existing port**, so the test `FakePersonDirectory` and
  any future identity-backed adapter must implement the new method. Additive and small; the alternative (a
  second near-identical directory port) is worse coupling for the same question.
- **The integrity-error path (decision 5) is asserted by the domain invariant, not enforced at the type
  level.** Acceptable: `delete-account` already guarantees it; the check is defensive, and a plain
  `RuntimeError` keeps from inventing a domain error for a state the domain says cannot occur.
- **No production identity-backed adapter yet** — the slice is proven end-to-end only through the fake,
  consistent with every prior pairing slice at this build stage (the port is the contract the real adapter
  will satisfy).
