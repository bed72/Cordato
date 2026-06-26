## Why

The domain names *"reversible without loss"* as one of its three pillars, and `Expense` was **born ready**
for it — the entity already carries a `deleted_at` field that, until now, only ever holds `null`. But there
is no way to set it: a person can record an expense, never un-record one. The day-to-day soft-delete that
CLAUDE.md promises (*"mistake recovery + audit trail"*) has **zero implementation** on the individual
entities — only `Pair` (dissolve) and `Person` (the hard-delete) can be removed today. This change delivers
the first ordinary soft-delete: **delete-expense**, a person retiring one of their own expenses. It is also
the cleanest possible demonstration that *"derive, don't store"* pays off — because nothing points at an
expense, soft-deleting one rewires nothing: the active budget's `total_spent` and `remaining` simply
recompute without it, with no stored link to fix up.

## What Changes

- Add the expenses context's first **non-destructive removal** use case: **delete expense**. Given the
  requester (`requester_id`) and the target `expense_id`, the system resolves **the requester's own live
  expense** and stamps its `deleted_at`, retiring it from every normal read. The operation returns nothing
  (`None`): a soft-delete is a pure command whose only outcome is the row's disappearance from live views.

- **Authorization is the lookup — and the lookup does not leak.** The expense is resolved *scoped to the
  requester* (owner + id together): a non-owner, an unknown id, and an already-deleted expense are
  indistinguishable to the caller — all three resolve to "nothing" and reject with the same pt-BR,
  non-leaking `ExpenseNotFoundError`. A person can only ever delete an expense they own; nobody can probe
  whether another person's expense exists. This honors *per-person authorization* exactly as `dissolve-pair`
  does (the lookup *is* the authorization), and the guard runs **first**, before any state is touched.

- **Soft-delete, not erase — the row stays for audit.** Unlike account deletion (the domain's only physical
  delete), this sets `deleted_at` and **keeps the row**. It vanishes from normal reads but remains visible to
  an explicit audit read. This change establishes both halves of soft-delete on an individual entity for the
  first time: normal reads exclude `deleted_at != null`; a new `list_including_removed` audit method sees
  everything.

- **No rewiring — the derived budget belonging makes this free.** Because an expense points at no budget
  (belonging is computed by date at read-time), soft-deleting one touches nothing else: no budget is read or
  updated, no link goes stale. The active budget's `total_spent`/`remaining` recompute correctly on the next
  read simply because `find_in_range` already returns only **live** expenses. The same lightness that lets a
  budget's dates change without touching expenses lets an expense leave without touching budgets.

- **Idempotent re-deletion is a no-op rejection, not a double-stamp.** An already-soft-deleted expense is no
  longer *live*, so the scoped lookup does not return it — a second delete rejects with `ExpenseNotFoundError`
  and changes nothing (the original `deleted_at` is never overwritten). Deletion has one direction; there is
  no "re-delete" that moves the timestamp.

- Add one domain transition to the **existing** `ExpenseEntity` — `delete(at)` — a single state change that
  stamps `deleted_at`, mirroring `PairEntity.dissolve(at)`. No new field (the entity already has
  `deleted_at`); the factory still births only live expenses, and `delete` is the sole path into the removed
  state.

- Ship a **runnable, fully-tested vertical slice** for the current stage: the new domain behavior
  (`ExpenseEntity.delete`), the new `ExpenseNotFoundError`, the application command + `DeleteExpenseUseCase`
  + `DeleteExpenseData`, and the two new `ExpenseRepositoryInterface` methods (`find_active_by_id`,
  `delete`) plus the `list_including_removed` audit read — exercised through the in-memory `ExpenseRepository`
  and the real determinism `clock` port (for the `deleted_at` instant).

- **Out of scope (deferred to their own changes):**
  - **Restoring** a soft-deleted expense (an "undo" that clears `deleted_at`) — a separate capability if ever
    wanted; this change only establishes removal.
  - **Editing** an expense, **deleting a budget**, and **listing** a person's expenses for the UI — sibling
    lifecycle slices, each its own change.
  - Any notification emitted on deletion, the HTTP handler, and the ORM model/mapper (deferred with the web
    layer, behind the unchanged ports).

## Capabilities

### New Capabilities
- `delete-expense`: A person soft-deletes one of their **own** expenses. The system resolves the requester's
  live expense scoped to owner + id, stamps its `deleted_at`, and persists it — the row then disappears from
  every normal read while remaining visible to an explicit audit read (`list_including_removed`). An unknown
  id, an expense owned by someone else, and an already-deleted expense all reject identically with a pt-BR,
  non-leaking `ExpenseNotFoundError`, changing nothing. Because expense→budget belonging is derived by date,
  the deletion rewires nothing: the owner's active-budget `total_spent`/`remaining` recompute without the
  removed expense on the next read, and no other person's data is read or touched.

### Modified Capabilities
<!-- None. `record-expense` keeps its requirements verbatim (it already births expenses with `deleted_at = null`).
     `active-budget` is unchanged at the requirement level: `total_spent` already sums only live expenses via
     `find_in_range`, so a soft-deleted expense dropping out of the sum is existing behavior, not a new rule —
     the repository gains methods, but no prior capability's behavior shifts. -->

## Impact

- **New domain behavior (expenses):** `ExpenseEntity.delete(at)` — stamps `deleted_at`, the sole transition
  into the removed state. No new field; mirrors `PairEntity.dissolve`. Identity equality (by `id`) intact.
- **New error (expenses):** `ExpenseNotFoundError` (pt-BR, non-leaking — e.g. `"Despesa não encontrada."`),
  raised when the requester owns no live expense with the given id (unknown id, foreign owner, or already
  deleted — all indistinguishable to the caller).
- **Extended port (expenses) — `ExpenseRepositoryInterface`:** gains
  `find_active_by_id(person_id, expense_id) -> ExpenseEntity | None` (resolve the requester's own live
  expense — the authorization lookup), `delete(expense) -> None` (persist the soft-deleted state), and
  `list_including_removed(person_id) -> list[ExpenseEntity]` (the audit read that sees live and removed
  alike). `create`, `find_in_range`, and `erase_for_person` are unchanged. The in-memory `ExpenseRepository`
  implements all three.
- **New application shapes (expenses):** `DeleteExpenseData` (command input — `requester_id` + `expense_id`)
  and `DeleteExpenseUseCase` (resolve scoped → `ExpenseNotFoundError` if absent → stamp `deleted_at` via the
  clock → persist → `None`). No read-model, no output mapper. The lookup is the guard and runs first; the
  clock and persist follow with a real data dependency, so no `asyncio.gather`.
- **Reused, unchanged:** the determinism `clock` port (for the `deleted_at` instant), the `MoneyValueObject`,
  the `find_in_range`-driven active-budget computation. No web/ORM introduced; the slice runs and is tested
  entirely in-memory.
- **Tests:** unit test for `ExpenseEntity.delete` (stamps `deleted_at`, identity equality intact); unit test
  for `ExpenseNotFoundError`; use-case tests for every scenario (owner deletes own live expense → soft-deleted
  and gone from normal reads, present in audit read; unknown id → `ExpenseNotFoundError`, nothing changed;
  expense owned by another person → `ExpenseNotFoundError`, nothing changed; already-deleted expense →
  `ExpenseNotFoundError`, original `deleted_at` untouched); and an integration test wiring the in-memory
  `ExpenseRepository` + real `clock` through the use case, asserting the deleted expense drops out of
  `find_in_range` (so a covering active budget's `total_spent` recomputes lower) while still appearing in
  `list_including_removed`.
