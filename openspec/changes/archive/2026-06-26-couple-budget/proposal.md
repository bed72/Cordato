## Why

The pairing context now renders its first couple-level read — **couple expenses**. Its deliberate sibling,
named three times in the domain as *"the couple budget (combined view)"*, is still missing: the
**panorama lens** over both partners' active budgets. This change delivers it — the second and final piece
of the shared *view*: a read-only, read-time projection that spans both individuals' active budgets without
storing, copying, or owning anything. It is *"deliberately approximate"* by design — the exact truth stays
in each person's own active budget; the couple view is the wide-angle picture on top.

## What Changes

- Add the pairing context's second **read** use case: **get couple budget**. Given the reader
  (`reader_id`) and a day, the system resolves the reader's **live pair**, reads **both** partners' active
  budget for that day, and returns the combined panorama: period `[min(start), max(end)]`, `amount` = sum,
  `total_spent` = sum, `remaining` = `amount − total_spent`.
- **Panorama over whoever has an active budget.** The view exists when **at least one** partner has an
  active budget for the day; it spans only the present ones (one partner without an active budget simply
  does not contribute). When **neither** partner has an active budget, there is no panorama → the use case
  returns **nothing** (`None`), exactly as the individual `get-active-budget` returns nothing when there is
  no active budget. The "No budget" default-budget bucket is **out of scope** (its own change); a missing
  active budget contributes nothing here, it is not fabricated.
- Model the panorama as Virtual Objects, never stored: a `PartnerActiveBudgetVirtualObject` (pairing's
  read-time view of **one** partner's active budget — `start_date`, `end_date`, `amount`, `total_spent`,
  derived `remaining`) and a `CoupleBudgetVirtualObject` that composes the **1–2** present partner views and
  derives the spanned period and the summed `amount` / `total_spent` / `remaining`. The money/period math
  lives in the domain, not in a mapper — exactly like `ActiveBudgetVirtualObject` and
  `CoupleExpenseVirtualObject`.
- Guard the view by the pairing invariant: the reader must be in a **live pair** (`deleted_at` null) where
  they are `person_a` or `person_b`; otherwise there is no couple to view → reuse the existing
  `NotPairedError` (pt-BR, non-leaking). A *missing active budget* is **not** an error (returns `None`); a
  *missing live pair* is. The view is **read-only** — pairing grants no write over a partner's data.
- Read each partner's active budget **without any cross-module dependency**. `pairing` defines its **own**
  consumer-owned gateway port — `PartnerBudgetReaderInterface`
  (`async def active_for_person(person_id, day) -> PartnerActiveBudgetData | None`) — an anti-corruption
  seam in pairing's vocabulary, exactly mirroring the `PartnerExpenseReaderInterface` shipped with
  couple-expenses and budgeting's own `SpendReaderInterface`. The use case depends only on this ABC; the
  concrete budgeting-backed adapter is wired at the composition root (the only layer allowed to know both
  modules). `pairing` never imports `budgeting`.
- Reuse the existing `PairRepositoryInterface.find_active_by_person` to resolve the reader's live pair and
  identify the partner. No new repository, no new entity, no new error, no behavior change to any prior
  slice.
- Ship a runnable, fully-tested vertical slice for the current stage: the new domain
  (`PartnerActiveBudgetVirtualObject`, `CoupleBudgetVirtualObject`), the application port +
  `GetCoupleBudgetUseCase` + `PartnerActiveBudgetData` / `CoupleBudgetData` + `CoupleBudgetDataMapper`,
  exercised through the existing in-memory `PairRepository` and a hand-written `FakePartnerBudgetReader`.

- **Out of scope (deferred to their own changes):**
  - The **default budget ("No budget")** bucket: a partner without an active budget contributes nothing
    here; it is never fabricated into the panorama.
  - **dissolve-pair** and **delete-account**.
  - The **real** budgeting-backed `PartnerBudgetReader` adapter and the composition-root wiring (no app
    bootstrap / web framework exists yet — deferred, not skipped; the port and a fake stand in today).
  - Any pagination, HTTP handler, or ORM model/mapper.

## Capabilities

### New Capabilities
- `couple-budget`: The read-only couple budget view over two individuals' active budgets — resolving the
  reader's live pair, reading both partners' active budget for a day, and returning the combined panorama
  (period `[min(start), max(end)]`, summed `amount` / `total_spent` / derived `remaining`) whenever at
  least one partner has an active budget; returning nothing when neither does; rejecting a reader who is in
  no live pair. Nothing is stored, copied, or owned by the pair.

### Modified Capabilities
<!-- None. couple-expenses, accept-invite-code, and create-invite-code keep their requirements verbatim;
     this slice only reads through the existing PairRepository port and adds a new pairing-owned gateway
     port. The individual budgeting/active-budget capability is untouched (read through an ACL port). -->

## Impact

- **New domain (pairing):** `PartnerActiveBudgetVirtualObject` (composes one partner's active budget in
  pairing's terms — `start_date`, `end_date`, `amount: MoneyValueObject`, `total_spent: MoneyValueObject`,
  derived `remaining`); `CoupleBudgetVirtualObject` (composes the non-empty tuple of partner views, derives
  the spanned period and summed money). No new error — `NotPairedError` is reused.
- **New port (pairing):** `PartnerBudgetReaderInterface` — a gateway ACL port returning
  `PartnerActiveBudgetData | None`; reuses existing `PairRepositoryInterface`. No core port needed.
- **New application shapes (pairing):** `PartnerActiveBudgetData` (the cross-context read shape the gateway
  returns), `CoupleBudgetData` (the public read-model), `CoupleBudgetDataMapper`, `GetCoupleBudgetUseCase`.
- **New adapters:** none in production for this stage — the budgeting-backed `PartnerBudgetReader` is
  deferred to composition-root wiring (a `FakePartnerBudgetReader` stands in for tests), exactly as the
  real `PartnerExpenseReader` was in couple-expenses. The in-memory `PairRepository` is reused as-is.
- **No new dependency.** No web/ORM introduced; the slice runs and is tested entirely in-memory.
- **Tests:** unit tests for `PartnerActiveBudgetVirtualObject` (derived `remaining`),
  `CoupleBudgetVirtualObject` (span + sums across two partners, and the single-partner span), and every
  use-case scenario (both present → combined panorama, one present → that partner's span only, neither
  present → `None`, reader-not-paired → `NotPairedError`, dissolved-only pair → `NotPairedError`) with
  fakes for the pair repository and the partner-budget reader; plus an integration test wiring the
  in-memory `PairRepository` + a `FakePartnerBudgetReader` through the use case. Adds
  `FakePartnerBudgetReader` under `tests/pairing/fakes/`.
