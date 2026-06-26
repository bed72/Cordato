## Context

Two read-side gaps remain in the individual ledger. The `expenses` repository can read by range
(`find_in_range`, the budget-belonging derivation), by id (`find_active_by_id`), and everything for audit
(`list_including_removed`) — but there is no plain *"all my live expenses"* read. And the domain's
**default budget ("No budget")** — the bucket grouping expenses that fall in no real budget — has never been
built, so an expense outside every live budget belongs to nothing the application can name.

Both views are read-time derivations over already-stored facts; neither adds a stored entity. The build is
still at the **transitional stage**: pure `domain/` + `application/` ports + in-memory adapters + a fake for
any cross-context read; no ORM/web. The two closest precedents are `ActiveBudgetVirtualObject` /
`GetActiveBudgetUseCase` (a budget enriched with derived money) and `couple-expenses` (a cross-context read
through a context-owned ACL port, with the perspective rule kept in a Virtual Object).

## Goals / Non-Goals

**Goals:**
- A `list-expenses` read in the `expenses` context: a person's live expenses, most-recent-first, own data
  only, soft-deleted excluded.
- A `default-budget` read in the `budgeting` context: the leftover bucket of live expenses falling in no
  live budget, deriving exact-decimal `total_spent`, with no limit and no remaining.
- Keep both true to *derive, don't store* (no FK, no row) and to the dependency rule (no `budgeting` →
  `expenses` import).

**Non-Goals:**
- Editing/deleting budgets or expenses; notifications; pagination or date-range slicing of the list.
- The real expenses-backed adapter for budgeting's new reader port and composition-root wiring (deferred,
  as in `couple-expenses`).
- Any ORM model/mapper or HTTP handler.

## Decisions

### D1 — `list-expenses`: add the missing all-live read to the existing port
`ExpenseRepositoryInterface` gains `async def list_live_for_person(person_id) -> list[ExpenseEntity]` — the
all-live, no-range read, named exactly like budgeting's `BudgetRepositoryInterface.list_live_for_person`. It
sits between the range read and the audit read and is the natural home for the soft-delete exclusion (the
adapter's responsibility). `ListExpensesUseCase` calls it, sorts most-recent-first (`occurred_on` desc, then
`created_at` desc — sorting in the use case, exactly as `GetCoupleExpensesUseCase` does), and maps each
entity to the **existing** `ExpenseData` via the existing `ExpenseDataMapper`. No new domain.
- *Alternative rejected:* reuse `find_in_range` with a wide window — abuses a range query for an unbounded
  read and bakes in arbitrary bounds. *Alternative rejected:* reuse `list_including_removed` and filter in
  the use case — pushes the soft-delete rule out of the repository, breaking the two-read contract.

### D2 — The default budget is a Virtual Object, not an entity
`DefaultBudgetVirtualObject` lives in `budgeting/domain/virtual_objects/`. It is the third domain shape: no
identity, never stored, composes stored state and **derives** money. It carries the bucket's leftover
expenses (in budgeting's own terms — see D4) and derives `total_spent` as the exact-decimal
`MoneyValueObject` sum, keeping the money rule in the domain rather than a mapper — exactly how
`ActiveBudgetVirtualObject` derives `remaining`.

### D3 — Membership is date-containment, expressed as a domain method on `BudgetEntity`
An expense belongs to the default bucket exactly when its `occurred_on` is contained by **none** of the
person's live budgets' inclusive ranges. Add `BudgetEntity.covers(day: date) -> bool`
(`start_date <= day <= end_date`) — the single-day sibling of the existing `overlaps(other)`, and the same
containment the active-budget derivation reasons over. The use case selects leftovers with
`not any(budget.covers(expense_day) for budget in live_budgets)`. The *rule* (containment, inclusive on both
ends) is a domain method; applying it to filter is thin use-case orchestration, mirroring how
`GetCoupleExpensesUseCase` builds the union in the use case while the per-item rule lives in the VO.
- *Alternative rejected:* compute leftovers via repeated `SpendReaderInterface.total_spent` calls over gaps
  between budgets — fragile gap arithmetic, and it cannot return the expenses themselves, only sums.

### D4 — Budgeting reads expenses through its own new ACL port (not `SpendReaderInterface`)
The default bucket needs the **individual expenses**, not a sum. `SpendReaderInterface` is documented as
*"a total amount, never an expense"* and stays unchanged. Introduce a new budgeting-owned gateway port —
`ExpenseReaderInterface` with `async def list_for_person(person_id) -> list[LedgerExpenseData]` — returning a
budgeting-owned read shape (`LedgerExpenseData`: `id`, `person_id`, `amount`, `occurred_on`, `description`,
`created_at`), an anti-corruption seam in budgeting's vocabulary, mirroring pairing's
`PartnerExpenseReaderInterface`. The concrete expenses-backed adapter is deferred to composition-root
wiring; a `FakeExpenseReader` stands in for tests. `budgeting` never imports `expenses`.
- *Alternative rejected:* add `list_for_person` to `SpendReaderInterface` — overloads a port whose contract
  is explicitly "a total, never an expense"; the two needs (sum vs. enumerate) deserve two ports.

### D5 — Read-model shape and mapper hops
`GetDefaultBudgetUseCase` returns `DefaultBudgetData { total_spent: Decimal, expenses: list[LedgerExpenseData] }`
— the derived total plus the bucket's expenses. The use case: gathers live budgets and the ledger
(`asyncio.gather` — independent reads), filters leftovers via `BudgetEntity.covers`, builds the
`DefaultBudgetVirtualObject` from the leftover amounts, and a `DefaultBudgetDataMapper.to_data(virtual_object)`
produces the read-model from the single VO (the VO carries both the leftover expenses and the derived
total, honoring one-cohesive-input mappers). `total_spent` is a plain `Decimal` at the read-model edge, exact
to the cent; the VO holds it as `MoneyValueObject` internally.

### D6 — No `amount`, no `remaining` on the default budget
Unlike `ActiveBudgetVirtualObject`, the bucket has no limit, so it exposes neither `amount` nor `remaining`.
This is the structural difference that says "leftover bucket, not a real budget" in the types themselves.

## Risks / Trade-offs

- **[Two capabilities in one change.]** `list-expenses` (expenses) and `default-budget` (budgeting) ship
  together. → They share the read-the-individual-ledger theme and are small, independent slices touching
  disjoint contexts; each gets its own spec, use case, and tests, so they remain reviewable in isolation.
- **[`covers` vs. `overlaps` confusion.]** Two containment-ish methods on `BudgetEntity`. → Distinct
  signatures and docstrings: `overlaps(other: BudgetEntity)` guards the non-overlap invariant; `covers(day:
  date)` answers single-day membership. Both inclusive on both ends, consistent with the rest of budgeting.
- **[Deferred real reader.]** Budgeting's `ExpenseReader` has no production adapter yet, only a fake. → Same
  posture as `couple-expenses`; the port is the contract, the in-memory wiring lands with the app bootstrap.
- **[Read-model exposes the gateway's `LedgerExpenseData`.]** The public `DefaultBudgetData.expenses` reuses
  budgeting's own ACL shape rather than a separate public DTO. → Acceptable: it is budgeting-owned (no
  cross-module leak) and a dedicated public expense DTO can be introduced later without changing behavior if
  the shapes ever need to diverge.
