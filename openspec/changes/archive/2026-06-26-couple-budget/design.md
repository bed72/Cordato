## Context

`couple-expenses` shipped the pairing context's first couple-level read. This change ships its deliberate
sibling — the **couple budget (combined view)**, the panorama lens over both partners' *active* budgets.
It follows every prior slice's pattern (pure `domain/`, async ports in `application/`, in-memory / gateway
adapters, fully testable without web/ORM) and reuses the existing `PairRepository` as-is.

Two architectural questions are already settled by precedent and are simply applied here:
1. **Reading another context's data** (the partner's active budget) without a `pairing → budgeting`
   import — resolved exactly as couple-expenses reads expenses via its own `PartnerExpenseReaderInterface`
   and as budgeting reads spend via its own `SpendReaderInterface`: a consumer-owned anti-corruption
   **gateway** port.
2. **Where the derived read-time view lives** — a **Virtual Object** (`domain/virtual_objects/`), the third
   domain shape, exactly like `ActiveBudgetVirtualObject` and `CoupleExpenseVirtualObject`: it composes
   stored/cross-context state and derives values, has no identity, and is never persisted.

The genuinely new modeling is small: a per-partner `PartnerActiveBudgetVirtualObject`, a
`CoupleBudgetVirtualObject` that composes 1–2 of them and derives the panorama, a gateway port, two `data`
shapes, a mapper, and a read use case. **No new error** — `NotPairedError` is reused, and "no active
budget" is modeled as `None`, not an error.

## Goals / Non-Goals

**Goals:**
- Add `GetCoupleBudgetUseCase` returning the combined panorama (period `[min(start), max(end)]`, summed
  `amount` / `total_spent` / derived `remaining`) of both partners' active budgets for a day.
- Keep the period span and the money sums in the domain (the Virtual Objects), not in a mapper or the
  repository.
- Read partner active budgets **without coupling `pairing` to `budgeting`** — via a port pairing owns.
- Guard the view behind a live pair (reuse `NotPairedError`); model "no active budget" as `None`.
- The panorama spans whichever partners have an active budget (≥1 present); neither present → `None`.
- Ship a runnable vertical slice: reuse the in-memory `PairRepository`; a `FakePartnerBudgetReader` for
  tests; no production cross-context adapter yet.

**Non-Goals:**
- The **default budget ("No budget")** bucket — a missing active budget contributes nothing; it is never
  fabricated. (Its own change.)
- **dissolve-pair**, **delete-account**.
- The real budgeting-backed `PartnerBudgetReader` adapter and its composition-root wiring (no app
  bootstrap / ORM exists yet).
- Any pagination, write through the view, web handler, or ORM model/mapper.

## Decisions

**1. The "no active budget" question — `≥1` present, else `None`.**
The panorama is built from whichever partners have an active budget for the day. With **both** present it
spans both; with **one** present it equals that partner's span and figures; with **neither** present the
use case returns `None`. This mirrors the individual `GetActiveBudgetUseCase`, which returns `None` when
there is no active budget, and is consistent with couple-expenses (one partner's data when only one has
any; empty when neither does). A partner *without* an active budget contributes **nothing** — the "No
budget" default bucket is explicitly a separate change and is **not** fabricated here. Alternatives
rejected: *require both* (hides a useful panorama whenever one partner simply has not set a budget yet);
*fabricate a default budget for the missing partner* (drags the out-of-scope default-budget VO into this
change).

**2. `PartnerActiveBudgetVirtualObject` — pairing's read-time view of one partner's active budget.**
`features/pairing/domain/virtual_objects/partner_active_budget_virtual_object.py`. A frozen, slotted
dataclass holding `start_date: date`, `end_date: date`, `amount: MoneyValueObject`,
`total_spent: MoneyValueObject`, exposing a derived `remaining -> MoneyValueObject` (`amount − total_spent`,
negative when overspent) — exactly the derivation `ActiveBudgetVirtualObject` carries. It is pairing's own
projection of "a partner's active budget" (the anti-corruption counterpart of budgeting's
`ActiveBudgetVirtualObject`, which pairing may not import), holding `MoneyValueObject` to keep money
exact-decimal across the context boundary. A Virtual Object: no identity, never stored, composes +
derives. It earns its existence by the `remaining` derivation, not as a bare data carrier.

**3. `CoupleBudgetVirtualObject` — composes the present partner views, derives the panorama.**
`features/pairing/domain/virtual_objects/couple_budget_virtual_object.py`. A frozen, slotted dataclass
holding `budgets: tuple[PartnerActiveBudgetVirtualObject, ...]` (the **non-empty** tuple of present partner
views — the use case never constructs it empty), with derived properties:
- `period_start -> date` = `min(b.start_date for b in budgets)`
- `period_end -> date` = `max(b.end_date for b in budgets)`
- `amount -> MoneyValueObject` = sum of `b.amount`
- `total_spent -> MoneyValueObject` = sum of `b.total_spent`
- `remaining -> MoneyValueObject` = `amount − total_spent`

The span and the money sums are the domain rule and live here — matching *"keep money/derivation math in
the domain"* and the `ActiveBudgetVirtualObject` precedent. It composes other Virtual Objects (composition
is a Virtual Object's job). Summation uses `MoneyValueObject(...)` over `.value` (the established idiom in
`ActiveBudgetVirtualObject.remaining`). Alternative rejected: store the already-summed scalars and sum in
the use case — that would scatter the panorama's defining math into application orchestration; only the
*selection* of which budgets are present is orchestration (decision 6), the *combining* is the domain rule.

**4. Reading partner active budgets via a consumer-owned gateway port — never a cross-module import.**
`pairing` defines `PartnerBudgetReaderInterface` in `features/pairing/application/interfaces/` —
`async def active_for_person(person_id: str, day: date) -> PartnerActiveBudgetData | None`, returning the
person's **active** budget for the day (the adapter owns the live/active resolution), or `None` when they
have none. This is pairing's anti-corruption seam over "a person's active budget" — pairing speaks its own
vocabulary and depends only on this ABC. It is a **gateway**, not a repository (it reads data pairing does
not own and maps no entity to a table), exactly like the `PartnerExpenseReaderInterface` from
couple-expenses and budgeting's `SpendReaderInterface`. The concrete adapter — which will delegate to
budgeting's `GetActiveBudgetUseCase` — is wired at the **composition root** (the only layer permitted to
know both modules) and is **deferred** alongside the absent app bootstrap. A hand-written
`FakePartnerBudgetReader` satisfies the port in tests. Alternative rejected: return budgeting's own
`ActiveBudgetVirtualObject`/`ActiveBudgetData` — that would force a `pairing → budgeting` import, the exact
coupling the modular monolith forbids.

**5. `PartnerActiveBudgetData` — the cross-context read shape, in pairing's vocabulary.**
`features/pairing/application/data/partner_active_budget_data.py`: a frozen, slotted dataclass
(`person_id: str`, `start_date: date`, `end_date: date`, `amount: Decimal`, `total_spent: Decimal`) — the
shape the gateway returns (`Decimal`, the cross-context wire form, like `PartnerExpenseData`). It is an
application `data` read-model, carries no behavior, needs no value-object justification. The use case maps
each present one into a `PartnerActiveBudgetVirtualObject` (wrapping the two `Decimal`s in
`MoneyValueObject`); the virtual object never imports this application type, so the dependency rule holds.

**6. The use case: guard for the pair, read both, drop the absent, combine.**
`GetCoupleBudgetUseCase(pair_repository, partner_budget_reader)` with
`async def execute(reader_id: str, day: date) -> CoupleBudgetData | None`:
  1. `pair = await pair_repository.find_active_by_person(reader_id)`; if `None` → `NotPairedError`.
  2. `partner_id` = the *other* id of the pair (`person_b_id` if `reader_id == person_a_id`, else
     `person_a_id`).
  3. The two reads are independent → `reader_budget, partner_budget = await asyncio.gather(
     partner_budget_reader.active_for_person(reader_id, day),
     partner_budget_reader.active_for_person(partner_id, day))`.
  4. `present = [b for b in (reader_budget, partner_budget) if b is not None]`; if `present` is empty →
     return `None`.
  5. Map each present `PartnerActiveBudgetData` → `PartnerActiveBudgetVirtualObject` (wrapping `amount` and
     `total_spent` in `MoneyValueObject`); build `CoupleBudgetVirtualObject(tuple(views))`.
  6. `return CoupleBudgetDataMapper.to_data(view)`.

The guard (step 1) precedes the gathered reads, per the async rule that a short-circuiting check comes
before any independent work. Selecting the present budgets (step 4) is orchestration, not a domain rule, so
it lives in the use case; the *combining* of those present budgets is the domain rule and lives in the VO.

**7. `CoupleBudgetData` + `CoupleBudgetDataMapper` — the public read-model.**
`features/pairing/application/data/couple_budget_data.py`: a frozen, slotted dataclass (`period_start:
date`, `period_end: date`, `amount: Decimal`, `total_spent: Decimal`, `remaining: Decimal`). The money is
unwrapped to plain `Decimal`, mirroring how `ActiveBudgetDataMapper` unwraps money. `CoupleBudgetDataMapper.
to_data(view: CoupleBudgetVirtualObject) -> CoupleBudgetData` is the dedicated `@staticmethod` mapper, one
per file, reading the VO's derived properties.

**8. No new error, no new production adapter, no model/mapper.**
"No active budget" is `None`, not an error; "not in a live pair" reuses the existing `NotPairedError`. The
in-memory `PairRepository` is reused unchanged. The only new "adapter" is the test
`FakePartnerBudgetReader`. No `Model` / `ModelMapper` until an ORM is chosen.

## Risks / Trade-offs

- **Deferred real `PartnerBudgetReader` adapter.** → The view is fully specified and exercised via a fake;
  the production adapter (delegating to budgeting's `GetActiveBudgetUseCase`) and its composition-root
  wiring land with the app bootstrap. The port and contract exist now, so wiring later touches no domain or
  use-case code.
- **Panorama is deliberately approximate.** → When the two active budgets have different ranges, the
  spanned `[min(start), max(end)]` is wider than either, and the summed `total_spent` mixes spend measured
  over different windows. This is intended (a wide-angle lens; the exact figures live in each individual's
  active budget) and is stated as such in the domain (CLAUDE.md) and the spec.
- **Read-consistency across two budgets is non-transactional.** → The two `active_for_person` reads are not
  a snapshot. Harmless for a read-only view with no invariant spanning the two budgets.
- **`remaining` / sums derived per read, never stored.** → No stored aggregate to go stale; recomputed at
  read-time from the present active budgets, consistent with derive-don't-store.
- **A partner with no active budget silently contributes nothing.** → By decision 1 the panorama still
  renders from the other partner; the absent one is neither an error nor a fabricated bucket. If the
  product later wants the "No budget" bucket folded in, that is an additive change behind the same port.
