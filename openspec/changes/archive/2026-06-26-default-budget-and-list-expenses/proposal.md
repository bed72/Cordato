## Why

The individual ledger still has two holes the domain has always promised to fill. First, there is **no way
to list a person's expenses** — every expense read so far is either range-scoped (`find_in_range`, the
budget-belonging derivation) or audit-only (`list_including_removed`). Second, the **"No budget" default
budget** described in the domain — *"a bucket fabricated on the fly to group the owner's expenses that fall
into no real budget"* — does not exist, so an expense that lands outside every live budget belongs to
nothing the application can name. This change delivers both: the flat ledger read, and the leftover bucket
that resolves the nullability of *"where does this expense belong?"* — both **computed at read-time, never
stored**, true to *derive, don't store*.

## What Changes

- Add the `expenses` context's first **list read**: **list expenses**. Given `person_id`, return the
  person's **live** expenses (soft-deleted excluded), ordered most-recent-first (`occurred_on` desc, then
  `created_at` desc) as `ExpenseData`. A person reads only their own ledger (per-person authorization).
  - Extend `ExpenseRepositoryInterface` with `list_live_for_person(person_id) -> list[ExpenseEntity]` — the
    all-live, no-range read (mirroring budgeting's `BudgetRepositoryInterface.list_live_for_person`), filling
    the gap between the range read and the audit read. Implement it on the in-memory adapter.
- Add the `budgeting` context's **default budget ("No budget")**: a `DefaultBudgetVirtualObject` fabricated
  at read-time, **never stored** — it groups the owner's live expenses that fall within **no** live budget's
  inclusive range, and derives `total_spent` (the exact-decimal sum of exactly those expenses). Unlike
  `ActiveBudgetVirtualObject` it has **no `amount` and no `remaining`** — there is no limit; it is a pure
  leftover bucket, not a real budget. Neither entity (no identity) nor value object (it composes + derives)
  — a Virtual Object, the project's third domain shape.
- The "falls in no live budget" rule is a **domain rule**: an expense belongs to the default bucket exactly
  when its `occurred_on` is contained by none of the person's live budgets' inclusive ranges — the same
  date-containment logic the active-budget derivation already reasons over, applied as a complement. It
  lives in the domain (the Virtual Object's derivation), never in a mapper or the adapter.
- Read the owner's expenses into budgeting **without any cross-module dependency**. `budgeting` defines its
  **own** consumer-owned gateway port returning expenses (not just a sum) — an anti-corruption seam in
  budgeting's vocabulary, exactly as `couple-expenses` reads partner expenses via its own
  `PartnerExpenseReaderInterface`. The existing `SpendReaderInterface` stays as-is: it states *"a total
  amount, never an expense"* and the default bucket genuinely needs the individual expenses, so this is a
  new port, not a method bolted onto the wrong one.
- Ship two runnable, fully-tested vertical slices for the current stage: the new domain
  (`DefaultBudgetVirtualObject`), the application ports + use cases (`ListExpensesUseCase`,
  `GetDefaultBudgetUseCase`) + read-models + mappers, exercised through the existing in-memory repositories
  and a hand-written fake for budgeting's new expense-reader port.

- **Out of scope (deferred to their own changes):**
  - **edit/update** of an expense or budget, **delete-budget** (soft-delete), and any **notification**.
  - The **real** expenses-backed adapter for budgeting's new reader port and the composition-root wiring
    (no app bootstrap / web framework exists yet — deferred, not skipped; the port and a fake stand in
    today), exactly as the real `PartnerExpenseReader` was deferred in `couple-expenses`.
  - Pagination, date-range slicing of the list, any HTTP handler, or ORM model/mapper.

## Capabilities

### New Capabilities
- `list-expenses`: The per-person read of an individual's own ledger — returning their live expenses,
  most-recent-first, excluding soft-deleted ones. The flat list the ledger has always implied; reads only
  the requester's own data.
- `default-budget`: The "No budget" leftover bucket — a read-time virtual object grouping the owner's live
  expenses that fall within no live budget's range, deriving the exact-decimal `total_spent` of exactly
  those expenses. No limit, no remaining; nothing stored. Resolves the nullability of an expense that
  belongs to no real budget.

### Modified Capabilities
<!-- None at the requirement level. `record-expense` and the soft-delete/audit reads keep their behavior
     verbatim; this slice only ADDS a new `list_live_for_person` method to the existing expense repository
     port and a new budgeting-owned reader port. `active-budget`/`create-budget` are untouched. -->

## Impact

- **New domain (budgeting):** `DefaultBudgetVirtualObject` — composes the leftover live expenses (those in
  no live budget's range) and derives `total_spent` as a `MoneyValueObject`; no `amount`, no `remaining`.
- **New port (budgeting):** a consumer-owned gateway port returning the owner's expenses in budgeting's own
  read shape (`async def list_for_person(person_id) -> list[...]`), an ACL seam mirroring
  `PartnerExpenseReaderInterface`; `SpendReaderInterface` unchanged.
- **Modified port (expenses):** `ExpenseRepositoryInterface` gains `list_live_for_person` (all live, no
  range); the in-memory `ExpenseRepository` implements it. No behavior change to existing methods.
- **New application shapes:** `ListExpensesUseCase` (returns `list[ExpenseData]`, reusing the existing
  `ExpenseData`/mapper); `GetDefaultBudgetUseCase` + `DefaultBudgetData` (read-model: `total_spent` plus the
  bucket's expenses) + its data mapper; budgeting's own cross-context expense read shape for the new port.
- **New adapters:** none in production for this stage — budgeting's real expenses-backed reader is deferred
  to composition-root wiring (a fake stands in for tests). The in-memory `ExpenseRepository` and
  `BudgetRepository` are reused (the former gains one method).
- **No new dependency.** No web/ORM introduced; both slices run and are tested entirely in-memory.
- **Tests:** unit tests for `DefaultBudgetVirtualObject` (leftover filtering across before/inside/after a
  budget, multiple non-overlapping budgets, empty ledger, all-covered → empty bucket, `total_spent` exact
  sum) and both use cases (ordering, own-data-only, empty cases); plus integration tests wiring the
  in-memory repositories (and budgeting's fake expense reader) through each use case. Adds the budgeting
  fake reader under `tests/budgeting/fakes/`.
