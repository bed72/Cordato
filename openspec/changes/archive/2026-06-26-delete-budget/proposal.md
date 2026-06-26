## Why

The domain names *"reversible without loss"* as one of its three pillars, and `Budget` — exactly like
`Expense` — was **born ready** for it: the entity already carries a `deleted_at` field that, until now, only
ever holds `null`. `delete-expense` delivered the first ordinary soft-delete on an individual entity; this
change closes the obvious asymmetry by giving `Budget` the same day-to-day removal (*"mistake recovery + audit
trail"*). It is also the cleanest demonstration that *"derive, don't store"* pays off a second time: because
nothing points at a budget — neither the owner's expenses (belonging is computed by date) nor the active-budget
derivation (it reads only *live* budgets) — soft-deleting one rewires nothing. The freed date range simply
reopens, and the expenses that fell inside re-resolve to the default *"No budget"* bucket, with no stored link
to fix up.

## What Changes

- Add the budgeting context's first **non-destructive removal** use case: **delete budget**. Given the
  requester (`requester_id`) and the target `budget_id`, the system resolves **the requester's own live
  budget** and stamps its `deleted_at`, retiring it from every normal read. The operation returns nothing
  (`None`): a soft-delete is a pure command whose only outcome is the row's disappearance from live views.

- **Authorization is the lookup — and the lookup does not leak.** The budget is resolved *scoped to the
  requester* (owner + id together): a non-owner, an unknown id, and an already-deleted budget are
  indistinguishable to the caller — all three resolve to "nothing" and reject with the same pt-BR,
  non-leaking `BudgetNotFoundError`. A person can only ever delete a budget they own; nobody can probe
  whether another person's budget exists. This honors *per-person authorization* exactly as `delete-expense`
  and `dissolve-pair` do (the lookup *is* the authorization), and the guard runs **first**, before any state
  is touched.

- **Soft-delete, not erase — the row stays for audit.** Unlike account deletion (the domain's only physical
  delete, which cascades budgets via `erase_for_person`), this sets `deleted_at` and **keeps the row**. It
  vanishes from normal reads but remains visible to an explicit audit read. Normal reads already exclude
  `deleted_at != null` (`list_live_for_person`, `find_active_for_person`); this change adds the matching audit
  read, `list_including_removed`, that sees live and removed alike.

- **No rewiring — the derived belonging makes this free.** Soft-deleting a budget touches nothing else: no
  expense is read or updated, no other budget is moved. Two derivations recompute correctly on the next read
  purely because they already reason over *live* budgets only:
  - **The non-overlap invariant reopens the date range.** `list_live_for_person` excludes the removed budget,
    so a new budget may now be created over the dates the deleted one occupied — no conflict, nothing to
    migrate.
  - **The covered expenses fall to the default bucket.** Because expense→budget belonging is computed by date
    at read-time and never stored, the expenses that fell inside the deleted budget's range now resolve to the
    default *"No budget"* bucket on the next read. No expense is touched; the grouping simply recomputes.

- **Idempotent re-deletion is a no-op rejection, not a double-stamp.** An already-soft-deleted budget is no
  longer *live*, so the scoped lookup does not return it — a second delete rejects with `BudgetNotFoundError`
  and changes nothing (the original `deleted_at` is never overwritten). Deletion has one direction; there is
  no "re-delete" that moves the timestamp.

- Add one domain transition to the **existing** `BudgetEntity` — `delete(at)` — a single state change that
  stamps `deleted_at`, mirroring `ExpenseEntity.delete` and `PairEntity.dissolve`. No new field (the entity
  already has `deleted_at`); the factory still births only live budgets, and `delete` is the sole path into
  the removed state.

- Ship a **runnable, fully-tested vertical slice** for the current stage: the new domain behavior
  (`BudgetEntity.delete`), the new `BudgetNotFoundError`, the application command + `DeleteBudgetUseCase` +
  `DeleteBudgetData`, and the two new `BudgetRepositoryInterface` methods (`find_active_by_id`, `delete`) plus
  the `list_including_removed` audit read — exercised through the in-memory `BudgetRepository` and the real
  determinism `clock` port (for the `deleted_at` instant).

- **Out of scope (deferred to their own changes):**
  - **Restoring** a soft-deleted budget (an "undo" that clears `deleted_at`) — a separate capability if ever
    wanted; this change only establishes removal.
  - **Editing** a budget (amount, dates, note) and **listing** a person's budgets for the UI — sibling
    lifecycle slices, each its own change.
  - Any notification emitted on deletion, the HTTP handler, and the ORM model/mapper (deferred with the web
    layer, behind the unchanged ports).

## Capabilities

### New Capabilities
- `delete-budget`: A person soft-deletes one of their **own** budgets. The system resolves the requester's
  live budget scoped to owner + id, stamps its `deleted_at`, and persists it — the row then disappears from
  every normal read while remaining visible to an explicit audit read (`list_including_removed`). An unknown
  id, a budget owned by someone else, and an already-deleted budget all reject identically with a pt-BR,
  non-leaking `BudgetNotFoundError`, changing nothing. Because the active-budget derivation and the
  non-overlap invariant both consider only live budgets, and expense→budget belonging is derived by date, the
  deletion rewires nothing: the freed date range reopens for a new budget, and the covered expenses re-resolve
  to the default "No budget" bucket on the next read, while no expense or other person's data is read or
  touched.

### Modified Capabilities
<!-- None at the requirement level. `create-budget` keeps its requirements verbatim (it already births
     budgets with `deleted_at = null` and checks non-overlap against `list_live_for_person`, which already
     excludes removed rows — a freed range is existing behavior, not a new rule). `active-budget` and
     `default-budget` are unchanged: they derive over live budgets via `find_active_for_person`, so a
     soft-deleted budget dropping out (and its expenses falling to the default bucket) is existing behavior.
     The repository gains methods, but no prior capability's behavior shifts. -->

## Impact

- **New domain behavior (budgeting):** `BudgetEntity.delete(at)` — stamps `deleted_at`, the sole transition
  into the removed state. No new field; mirrors `ExpenseEntity.delete` / `PairEntity.dissolve`. Identity
  equality (by `id`) intact.
- **New error (budgeting):** `BudgetNotFoundError` (pt-BR, non-leaking — e.g. `"Orçamento não encontrado."`),
  raised when the requester owns no live budget with the given id (unknown id, foreign owner, or already
  deleted — all indistinguishable to the caller).
- **Extended port (budgeting) — `BudgetRepositoryInterface`:** gains
  `find_active_by_id(person_id, budget_id) -> BudgetEntity | None` (resolve the requester's own live budget —
  the authorization lookup), `delete(budget) -> None` (persist the soft-deleted state), and
  `list_including_removed(person_id) -> list[BudgetEntity]` (the audit read that sees live and removed alike).
  `create`, `list_live_for_person`, `find_active_for_person`, and `erase_for_person` are unchanged. The
  in-memory `BudgetRepository` implements all three.
- **New application shapes (budgeting):** `DeleteBudgetData` (command input — `requester_id` + `budget_id`)
  and `DeleteBudgetUseCase` (resolve scoped → `BudgetNotFoundError` if absent → stamp `deleted_at` via the
  clock → persist → `None`). No read-model, no output mapper. The lookup is the guard and runs first; the
  clock and persist follow with a real data dependency, so no `asyncio.gather`.
- **Reused, unchanged:** the determinism `clock` port (for the `deleted_at` instant), the active-budget /
  default-budget derivations (they already read only live budgets), the non-overlap check in `create-budget`.
  No web/ORM introduced; the slice runs and is tested entirely in-memory.
- **Tests:** unit test for `BudgetEntity.delete` (stamps `deleted_at`, identity equality intact); unit test
  for `BudgetNotFoundError`; repository tests for `find_active_by_id` / `delete` / `list_including_removed`;
  use-case tests for every scenario (owner deletes own live budget → soft-deleted and gone from normal reads,
  present in audit read; unknown id → `BudgetNotFoundError`, nothing changed; budget owned by another person →
  `BudgetNotFoundError`, nothing changed; already-deleted budget → `BudgetNotFoundError`, original
  `deleted_at` untouched); and an integration test wiring the in-memory `BudgetRepository` + real `clock`
  through the use case, asserting the deleted budget drops out of `find_active_for_person` (so its day now has
  no active budget and a new budget may be created over the freed range) while still appearing in
  `list_including_removed`, and that no other person's budget is affected.
