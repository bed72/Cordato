## 1. Budgeting domain

- [x] 1.1 Add `BudgetNotFoundError` in `budgeting/domain/errors/budget_not_found_error.py` — pt-BR,
  non-leaking message (e.g. `"Orçamento não encontrado."`), one concept per file.
- [x] 1.2 Add a `BudgetEntity.delete(at: datetime)` transition: stamps `self.deleted_at = at`, the sole path
  into the removed state. No new field (entity already has `deleted_at`); mirror `ExpenseEntity.delete`,
  unconditional single stamp. Identity equality (`__eq__`/`__hash__` on id) unchanged.

## 2. Budgeting application ports

- [x] 2.1 Extend `BudgetRepositoryInterface` with
  `async def find_active_by_id(self, person_id: str, budget_id: str) -> BudgetEntity | None` — resolve the
  requester's own *live* budget (owner + id + not soft-deleted); document it as the authorization lookup and
  distinguish it from `find_active_for_person` (date-containment derivation) in the docstring.
- [x] 2.2 Extend `BudgetRepositoryInterface` with `async def delete(self, budget: BudgetEntity) -> None` —
  persist the soft-deleted state (stamped `deleted_at`).
- [x] 2.3 Extend `BudgetRepositoryInterface` with
  `async def list_including_removed(self, person_id: str) -> list[BudgetEntity]` — the audit read that returns
  the person's budgets live and soft-deleted alike; document the two-read contract (normal reads exclude
  `deleted_at != null`; only this audit read sees everything).

## 3. Budgeting application use case

- [x] 3.1 Add `DeleteBudgetData` in `budgeting/application/data/delete_budget_data.py` — command input:
  `requester_id: str` + `budget_id: str`.
- [x] 3.2 Add `DeleteBudgetUseCase` in `budgeting/application/use_cases/delete_budget_use_case.py`: resolve
  via `find_active_by_id(requester_id, budget_id)` as the strict first guard (None → `BudgetNotFoundError`);
  then `clock.now()` → `budget.delete(now)` → `repository.delete(budget)`. Strict data-dependency chain, no
  `asyncio.gather`. Returns `None`. Inject `BudgetRepositoryInterface` + `ClockInterface`.

## 4. Budgeting infrastructure (in-memory adapter)

- [x] 4.1 Implement `find_active_by_id` on the in-memory `BudgetRepository` — match owner + id and exclude
  `deleted_at != null` (returns `None` for unknown id, foreign owner, or already-deleted, indistinguishably).
- [x] 4.2 Implement `delete` on the in-memory `BudgetRepository` — persist the stamped entity in place
  (never overwrite an existing `deleted_at`; the scoped lookup already prevents re-deletion reaching here).
- [x] 4.3 Implement `list_including_removed` on the in-memory `BudgetRepository` — return all of the person's
  budgets regardless of `deleted_at`. Leave `create`, `list_live_for_person`, `find_active_for_person`,
  `erase_for_person` untouched.

## 5. Tests

- [x] 5.1 Unit test `BudgetEntity.delete` — stamps `deleted_at` with the supplied instant, identity equality
  (`__eq__`/`__hash__` on id) intact.
- [x] 5.2 Unit test `BudgetNotFoundError` — pt-BR message, no sensitive data leaked (id/owner never echoed).
- [x] 5.3 Repository tests for `BudgetRepository.find_active_by_id` (owner+live hit; miss for unknown id,
  foreign owner, already-deleted), `delete` (row stays, excluded from `list_live_for_person` and
  `find_active_for_person`), and `list_including_removed` (sees live + removed).
- [x] 5.4 Use-case tests for `DeleteBudgetUseCase`: owner deletes own live budget → soft-deleted, gone from
  normal reads, present in audit read; unknown id → `BudgetNotFoundError`, nothing changed; budget owned by
  another person → `BudgetNotFoundError`, that budget untouched and still live; already-deleted budget →
  `BudgetNotFoundError`, original `deleted_at` not overwritten.
- [x] 5.5 Integration test under `tests/budgeting/integrations/`: wire in-memory `BudgetRepository` + real
  `clock` through the use case; create a budget over a date range, delete it, assert it drops out of
  `find_active_for_person` (so its day has no active budget and a fresh budget can be created over the freed
  range with no overlap error) while still appearing in `list_including_removed`, and no other person's budget
  is affected.

## 6. Guard & finalize

- [x] 6.1 Run `uv run poe check` (format → lint → mypy --strict → pytest) until green.
- [x] 6.2 Run `/trocado:guard` on the diff and resolve any reported violation (async boundaries, dependency
  direction, naming, no lib names, one-concept-per-file, derive-don't-store, soft-delete in the repository,
  per-person authorization, pt-BR non-leaking errors, test layout).
