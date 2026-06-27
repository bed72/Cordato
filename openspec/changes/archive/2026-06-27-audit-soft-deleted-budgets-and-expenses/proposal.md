## Why

CLAUDE.md promises that the day-to-day soft-delete keeps removed records out of normal views but **visible
in audit** ("`deleted_at`, disappears from normal views; visible in audit. Mistake recovery + audit
trail."). Both `BudgetRepositoryInterface.list_including_removed` and
`ExpenseRepositoryInterface.list_including_removed` already exist and are implemented by the in-memory
adapters — but **no use case ever calls them**. The audit promise has a port and an adapter and no reader:
a person currently has no way to see their own soft-deleted budgets or expenses, and the two audit ports
are orphaned (a declared contract with zero consumers). This closes that gap.

## What Changes

- Add a read-only **audit** capability per feature that returns a person's budgets / expenses **including
  soft-deleted ones**, each item carrying its own `deleted_at` so the caller can tell live from removed (and
  when it was removed). This is the explicit audit read — the only read that crosses the two-read contract.
- Each read is **read at request-time and never mutates** the ledger, and returns only the requester's own
  records (per-person authorization; the couple lens is a separate capability and does **not** extend to
  audit).
- Items are ordered **most-recent-first**, mirroring the live lists: budgets by `start_date` then
  `created_at` descending; expenses by `occurred_on` then `created_at` descending. Live and soft-deleted
  records interleave by date — the audit view is a superset of the live list, with `deleted_at` the only
  discriminator.
- New read-models (existing `BudgetData` / `ExpenseData` deliberately omit `deleted_at` and stay the plain
  reads): `AuditBudgetData` and `AuditExpenseData`, each with its own dedicated mapper. New use cases:
  `AuditBudgetsUseCase`, `AuditExpensesUseCase`, each wired to the already-existing `list_including_removed`
  port.
- No new entity, value object, enum, or port. No port signature changes. No ORM/web yet — ships as the
  current in-memory vertical slice; the audit read-models slot behind the existing ports.

## Capabilities

### New Capabilities

- `audit-budgets`: A person can list **all** their own budgets, live and soft-deleted alike, each carrying
  its `deleted_at`; read-only, owner-scoped, most-recent-period-first.
- `audit-expenses`: A person can list **all** their own expenses, live and soft-deleted alike, each carrying
  its `deleted_at`; read-only, owner-scoped, most-recent-first.

### Modified Capabilities

<!-- None. No existing requirement changes; the audit port methods are reused exactly as declared. -->

## Impact

- **New code (budgeting):** `application/data/audit_budget_data.py` (`AuditBudgetData`),
  `application/mappers/audit_budget_data_mapper.py` (`AuditBudgetDataMapper`),
  `application/use_cases/audit_budgets_use_case.py` (`AuditBudgetsUseCase`) — plus unit and integration tests.
- **New code (expenses):** `application/data/audit_expense_data.py` (`AuditExpenseData`),
  `application/mappers/audit_expense_data_mapper.py` (`AuditExpenseDataMapper`),
  `application/use_cases/audit_expenses_use_case.py` (`AuditExpensesUseCase`) — plus unit and integration tests.
- **Reused, unchanged:** `BudgetRepositoryInterface.list_including_removed`,
  `ExpenseRepositoryInterface.list_including_removed`, and their in-memory adapters; the `*Entity.deleted_at`
  fields.
- **No impact on** `domain/`, other features, dependencies, or the deferred ORM/web edge.
