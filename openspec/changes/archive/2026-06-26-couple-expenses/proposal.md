## Why

A couple is *"a point of view, not an owner"* — and the previous slice (`accept-invite-code`) finally
brought the `Pair` into existence without yet rendering anything through it. This change delivers the
**first couple-level view**, the payoff the pairing context was built for: **couple expenses** — the union
of both partners' spending, each item seen *from the reader's perspective* (`mine` / `theirs`). It is a
**lens, not a merge**: nothing is copied, nothing is owned by the pair, nothing is stored — the view is
computed at read-time over each individual's own ledger and vanishes the day the pair dissolves.

## What Changes

- Add the `pairing` context's first **read** use case: **get couple expenses**. Given the reader
  (`reader_id`), the system resolves the reader's **live pair**, gathers **both** partners' live expenses,
  and returns their union with each expense marked `mine` (the reader's own) or `theirs` (the partner's),
  ordered most-recent-first (`occurred_on` desc, then `created_at` desc).
- A couple is a point of view: introduce a `Perspective` enum (`MINE` / `THEIRS`, in `domain/enums/`) — the
  reader-relative ownership of an expense — and a `CoupleExpenseVirtualObject` that composes one partner
  expense with the reader's id and **derives** its `perspective`. Read-time projection, never stored:
  neither entity (no identity) nor value object (it composes + derives) — a Virtual Object, exactly like
  `ActiveBudgetVirtualObject`.
- Guard the view by the pairing invariant: the reader must be in a **live pair** (`deleted_at` null) where
  they are `person_a` or `person_b`; otherwise there is no couple to view → `NotPairedError` (pt-BR,
  non-leaking). The union is **read-only** — pairing grants no write over a partner's data.
- Read the partners' expenses **without any cross-module dependency**. `pairing` defines its **own**
  consumer-owned gateway port — `PartnerExpenseReaderInterface` (`async def list_for_person(person_id) ->
  list[PartnerExpenseData]`) — an anti-corruption seam in pairing's vocabulary, mirroring how budgeting
  reads spend via its own `SpendReaderInterface` and how pairing already checks activity via
  `PersonDirectoryInterface`. The use case depends only on this ABC; the concrete expenses-backed adapter
  is wired at the composition root (the only layer allowed to know both modules). `pairing` never imports
  `expenses`.
- Reuse the existing `PairRepositoryInterface.find_active_by_person` to resolve the reader's live pair and
  identify the partner (the *other* id in the pair). No new repository, no new entity, no behavior change
  to `accept-invite-code` or `create-invite-code`.
- Ship a runnable, fully-tested vertical slice for the current stage: the new domain (`Perspective`,
  `CoupleExpenseVirtualObject`, `NotPairedError`), the application port + `GetCoupleExpensesUseCase` +
  `PartnerExpenseData` / `CoupleExpenseData` + `CoupleExpenseDataMapper`, exercised through the existing
  in-memory `PairRepository` and a hand-written fake `PartnerExpenseReader`.

- **Out of scope (deferred to their own changes):**
  - **couple-budget** (the combined `[min(starts), max(ends)]` panorama) and **dissolve-pair**.
  - The **real** expenses-backed `PartnerExpenseReader` adapter and the composition-root wiring (no app
    bootstrap / web framework exists yet — deferred, not skipped; the port and a fake stand in today). The
    matching `list`-all method on the `expenses` side lands with that wiring, not here.
  - Any date-range slicing of the union, pagination, HTTP handler, or ORM model/mapper.

## Capabilities

### New Capabilities
- `couple-expenses`: The read-only couple view over two individuals' ledgers — resolving the reader's live
  pair, gathering both partners' live expenses, and returning their union with each item marked `mine` /
  `theirs` from the reader's perspective, ordered most-recent-first; rejecting a reader who is in no live
  pair. Nothing is stored, copied, or owned by the pair.

### Modified Capabilities
<!-- None. accept-invite-code and create-invite-code keep their requirements verbatim: this slice only
     reads through the existing PairRepository port and adds a new pairing-owned gateway port. The
     individual expenses/budgeting capabilities are untouched. -->

## Impact

- **New domain (pairing):** `Perspective` enum (`MINE` / `THEIRS`, in `domain/enums/`);
  `CoupleExpenseVirtualObject` (composes a partner expense + `reader_id`, derives `perspective`, holds
  `MoneyValueObject` to keep money exact-decimal); `NotPairedError` (pt-BR, non-leaking).
- **New port (pairing):** `PartnerExpenseReaderInterface` — a gateway ACL port returning
  `list[PartnerExpenseData]`; reuses existing `PairRepositoryInterface`. No core port needed.
- **New application shapes (pairing):** `PartnerExpenseData` (the cross-context read shape the gateway
  returns), `CoupleExpenseData` (the public read-model, `perspective` as a plain string),
  `CoupleExpenseDataMapper`, `GetCoupleExpensesUseCase`.
- **New adapters:** none in production for this stage — the expenses-backed `PartnerExpenseReader` is
  deferred to composition-root wiring (a `FakePartnerExpenseReader` stands in for tests), exactly as the
  real `PersonDirectory` was in `accept-invite-code`. The in-memory `PairRepository` is reused as-is.
- **No new dependency.** No web/ORM introduced; the slice runs and is tested entirely in-memory.
- **Tests:** unit tests for `Perspective`, `CoupleExpenseVirtualObject` (perspective derivation for
  reader-owned vs partner-owned), `NotPairedError`, and every use-case scenario (happy-path union +
  marking + ordering, empty ledgers, reader-not-paired rejection) with fakes for the pair repository and
  the partner-expense reader; plus an integration test wiring the in-memory `PairRepository` + a fake
  `PartnerExpenseReader` through the use case. Adds `FakePartnerExpenseReader` under `tests/pairing/fakes/`.
