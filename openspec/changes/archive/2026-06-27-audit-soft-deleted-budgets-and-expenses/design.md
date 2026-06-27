## Context

Budgeting and expenses already expose their live reads (`ListBudgetsUseCase`, `ListExpensesUseCase`,
date-scoped `find_in_range`, active/default budget). Both repository ports already declare an explicit audit
read — `BudgetRepositoryInterface.list_including_removed(person_id) -> list[BudgetEntity]` and
`ExpenseRepositoryInterface.list_including_removed(person_id) -> list[ExpenseEntity]` — and both in-memory
adapters already implement them (returning live **and** soft-deleted rows, owner-scoped). Both entities carry
`deleted_at: datetime | None`. So the persistence side of the "visible in audit" promise is complete; what is
missing is a **reader**: a use case per feature, plus a read-model that actually exposes `deleted_at` (the
existing `BudgetData`/`ExpenseData` deliberately omit it). This change is almost entirely composition of
parts that already exist.

## Goals / Non-Goals

**Goals:**
- A read-only `AuditBudgetsUseCase` returning `list[AuditBudgetData]` and a read-only `AuditExpensesUseCase`
  returning `list[AuditExpenseData]`, each for a person, ordered most-recent-first, **including** soft-deleted
  records, scoped to the requester.
- Surface `deleted_at` on each item so live and removed records are distinguishable within one listing.
- Reuse the existing `list_including_removed` port methods and their adapters unchanged.

**Non-Goals:**
- No restore/undelete and no hard-delete here — this is a pure read. Mistake *recovery* beyond visibility is
  a separate future change.
- No spend enrichment on audited budgets (`total_spent`/`remaining` stay with the active-budget read), and no
  budget reference on audited expenses (belonging stays a date-range derivation).
- No couple/audit cross-view: the shared lens is read-only over *live* data and does not extend to a
  partner's audit trail.
- No pagination/filtering (couple = little data; consistent with the "NO cache" decision). No new port,
  entity, value object, enum, ORM, or web layer.

## Decisions

- **Reuse `list_including_removed`, add no port method.** Both ports already declare exactly this audit read,
  with the two-read contract documented on them; the adapters already return live + soft-deleted, owner-scoped.
  Adding anything new would duplicate an existing contract for no behavioral gain — against
  earn-its-existence discipline. This change is the consumer the orphaned ports were waiting for.
  *Alternative considered:* a boolean `include_removed` flag on the existing live reads — rejected: it would
  blur the deliberate two-read separation (a normal read must never surface `deleted_at != null`) and make
  the audit concern leak into every live caller.
- **Dedicated audit read-models, not extended `BudgetData`/`ExpenseData`.** `AuditBudgetData` =
  `BudgetData`'s fields **plus `deleted_at: datetime | None`**; `AuditExpenseData` = `ExpenseData`'s fields
  plus `deleted_at`. The plain read-models intentionally omit `deleted_at` (the create/list responses must
  not carry an always-null audit field); the audit listing intentionally carries it. This mirrors the
  existing split where `ActiveBudgetData` is a separate read-model from `BudgetData`.
  *Alternative considered:* add `deleted_at` to the existing `BudgetData`/`ExpenseData` — rejected: it would
  leak an audit-only concern into every normal read and force a null on the create response.
- **Dedicated mappers, `@staticmethod`.** `AuditBudgetDataMapper.to_data` / `AuditExpenseDataMapper.to_data`,
  one per file, pure entity→data shape map unwrapping money to `Decimal` and passing `deleted_at` through —
  same shape and rigor as the existing `BudgetDataMapper`/`ExpenseDataMapper`, just a different destination
  shape (one mapper per boundary, never reuse a mapper across two read-models).
- **Sort in the use case**, identical key to the live lists: budgets by `(start_date, created_at)` reversed,
  expenses by `(occurred_on, created_at)` reversed. The audit listing is a superset of the live list in the
  same order; `deleted_at` does not participate in ordering, so a removed record sits exactly where its date
  places it. Keeps "most-recent-first" consistent across live and audit reads.
- **`async def execute(self, person_id: str) -> list[Audit*Data]`.** Async by the I/O-boundary rule (the port
  is async); a single awaited port call, then a pure in-memory sort + map — one call, so no `asyncio.gather`.

## Risks / Trade-offs

- **[Unbounded listing as history grows]** → Acceptable now (couple = little data; same reasoning as the
  no-cache decision). Pagination is a future change behind the same use case if it ever matters. Soft-deleted
  rows accumulate, but account deletion hard-erases them (`erase_for_person`), bounding the worst case.
- **[Two near-identical read-models per feature]** → Deliberate: the audit field is genuinely audit-only, and
  the project already favors a read-model per nature (`ActiveBudgetData` vs `BudgetData`) over a single
  flag-laden shape. The duplication is one extra field, not behavior.
- **[Ordering lives in the use case, not the adapter]** → The in-memory adapter returns unordered; the use
  case is the single source of order. When the ORM lands it MAY push `ORDER BY` into SQL behind the same
  port — tests assert on the use case's output order, so the guarantee holds regardless of where the sort runs.
