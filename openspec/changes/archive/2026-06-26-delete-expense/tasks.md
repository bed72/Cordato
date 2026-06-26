## 1. Expenses domain

- [x] 1.1 Add `ExpenseNotFoundError` in `expenses/domain/errors/expense_not_found_error.py` — pt-BR,
  non-leaking message (e.g. `"Despesa não encontrada."`), one concept per file.
- [x] 1.2 Add an `ExpenseEntity.delete(at: datetime)` transition: stamps `self.deleted_at = at`, the sole path
  into the removed state. No new field (entity already has `deleted_at`); mirror `PairEntity.dissolve`,
  unconditional single stamp.

## 2. Expenses application ports

- [x] 2.1 Extend `ExpenseRepositoryInterface` with
  `async def find_active_by_id(self, person_id: str, expense_id: str) -> ExpenseEntity | None` — resolve the
  requester's own *live* expense (owner + id + not soft-deleted); document it as the authorization lookup.
- [x] 2.2 Extend `ExpenseRepositoryInterface` with `async def delete(self, expense: ExpenseEntity) -> None` —
  persist the soft-deleted state (stamped `deleted_at`).
- [x] 2.3 Extend `ExpenseRepositoryInterface` with
  `async def list_including_removed(self, person_id: str) -> list[ExpenseEntity]` — the audit read that returns
  the person's expenses live and soft-deleted alike; document the two-read contract (normal reads exclude
  `deleted_at != null`; only this audit read sees everything).

## 3. Expenses application use case

- [x] 3.1 Add `DeleteExpenseData` in `expenses/application/data/delete_expense_data.py` — command input:
  `requester_id: str` + `expense_id: str`.
- [x] 3.2 Add `DeleteExpenseUseCase` in `expenses/application/use_cases/delete_expense_use_case.py`: resolve
  via `find_active_by_id(requester_id, expense_id)` as the strict first guard (None → `ExpenseNotFoundError`);
  then `clock.now()` → `expense.delete(now)` → `repository.delete(expense)`. Strict data-dependency chain, no
  `asyncio.gather`. Returns `None`.

## 4. Expenses infrastructure (in-memory adapter)

- [x] 4.1 Implement `find_active_by_id` on the in-memory `ExpenseRepository` — match owner + id and exclude
  `deleted_at != null` (returns `None` for unknown id, foreign owner, or already-deleted, indistinguishably).
- [x] 4.2 Implement `delete` on the in-memory `ExpenseRepository` — persist the stamped entity in place
  (never overwrite an existing `deleted_at`; the scoped lookup already prevents re-deletion reaching here).
- [x] 4.3 Implement `list_including_removed` on the in-memory `ExpenseRepository` — return all of the person's
  expenses regardless of `deleted_at`. Leave `create`, `find_in_range`, `erase_for_person` untouched.

## 5. Tests

- [x] 5.1 Unit test `ExpenseEntity.delete` — stamps `deleted_at` with the supplied instant, identity equality
  (`__eq__`/`__hash__` on id) intact.
- [x] 5.2 Unit test `ExpenseNotFoundError` — pt-BR message, no sensitive data leaked (id/owner never echoed).
- [x] 5.3 Repository tests for `ExpenseRepository.find_active_by_id` (owner+live hit; miss for unknown id,
  foreign owner, already-deleted), `delete` (row stays, excluded from `find_in_range`), and
  `list_including_removed` (sees live + removed).
- [x] 5.4 Use-case tests for `DeleteExpenseUseCase`: owner deletes own live expense → soft-deleted, gone from
  normal reads, present in audit read; unknown id → `ExpenseNotFoundError`, nothing changed; expense owned by
  another person → `ExpenseNotFoundError`, that expense untouched and still live; already-deleted expense →
  `ExpenseNotFoundError`, original `deleted_at` not overwritten.
- [x] 5.5 Integration test under `tests/expenses/integrations/`: wire in-memory `ExpenseRepository` + real
  `clock` through the use case; record expenses inside a date range, delete one, assert it drops out of
  `find_in_range` (so a covering active budget's `total_spent` recomputes lower / `remaining` rises) while
  still appearing in `list_including_removed`, and no other person's expense is affected.

## 6. Guard & finalize

- [x] 6.1 Run `uv run poe check` (format → lint → mypy --strict → pytest) until green.
- [x] 6.2 Run `/trocado:guard` on the diff and resolve any reported violation (async boundaries, dependency
  direction, naming, no lib names, one-concept-per-file, derive-don't-store, soft-delete in the repository,
  per-person authorization, pt-BR non-leaking errors, test layout).
