## 1. Module scaffold

- [x] 1.1 Create `src/trocado/features/budgeting/` with `domain/`, `application/`, `infrastructure/` packages (each `__init__.py`), mirroring `expenses`
- [x] 1.2 Mirror the test tree under `tests/budgeting/` with `domain/`, `application/`, `infrastructure/`, `integrations/`, `fakes/` packages

## 2. Domain (pure, no I/O)

- [x] 2.1 Add `domain/errors/invalid_budget_range_error.py` → `InvalidBudgetRangeError` (pt-BR message, non-leaking)
- [x] 2.2 Add `domain/errors/overlapping_budget_error.py` → `OverlappingBudgetError` (pt-BR message, non-leaking)
- [x] 2.2b Add `domain/errors/invalid_budget_amount_error.py` → `InvalidBudgetAmountError` (discovered during impl: `MoneyValueObject` permits zero/negative for `remaining`, so the positive-amount rule lives in the entity — mirrors `expenses`)
- [x] 2.3 Add `domain/entities/budget_entity.py` → `BudgetEntity` (`id`, `created_at`, `person_id`, `amount: MoneyValueObject`, `start_date`, `end_date`, `note`, `deleted_at`), `eq=False` identity equality, `create(...)` factory enforcing `start_date <= end_date` and non-positive-amount rejection, born live
- [x] 2.4 Add a pure `overlaps(other: BudgetEntity) -> bool` on the entity using inclusive-range logic (`start <= other.end AND other.start <= end`)
- [x] 2.5 Unit-test the factory (valid, single-day, start-after-end, non-positive amount, note trim/blank→None) and `overlaps` (disjoint, adjacent, shared boundary, contained)

## 3. Application — create budget

- [x] 3.1 Add `application/data/create_budget_data.py` → `CreateBudgetData` (command: `person_id`, `amount: Decimal`, `start_date`, `end_date`, `note`)
- [x] 3.2 Add `application/data/budget_data.py` → `BudgetData` read-model (budget fields as plain `Decimal`/dates + `total_spent` + `remaining`)
- [x] 3.3 Add `application/mappers/budget_data_mapper.py` → `BudgetDataMapper` (`@staticmethod to_data`, with optional `total_spent`/`remaining` for the enriched read)
- [x] 3.4 Add `application/interfaces/budget_repository_interface.py` → async ABC with `create(budget)`, `list_live_for_person(person_id)`, and `find_active_for_person(person_id, day)` (live budget containing the day)
- [x] 3.5 Add `application/use_cases/create_budget_use_case.py` → `CreateBudgetUseCase`: mint id+`created_at` from ports, build `MoneyValueObject`, fetch person's live budgets, reject overlap via `OverlappingBudgetError`, persist, return `BudgetData`

## 4. Application — active budget (derived)

- [x] 4.1 Add `find_in_range(person_id, start, end)` to `ExpenseRepositoryInterface` (returns the owner's live expenses whose date is in the inclusive range) — additive, no record-expense behavior change
- [x] 4.2 Add `application/use_cases/get_active_budget_use_case.py` → `GetActiveBudgetUseCase`: find the live budget containing the day; if found, sum the owner's expenses in range via the expenses port, compute `remaining = amount − total_spent`, return enriched `BudgetData`; else return `None`

## 5. Infrastructure (in-memory adapters)

- [x] 5.1 Add `infrastructure/repositories/budget_repository.py` → `BudgetRepository` (in-memory, keyed by id; live-only reads exclude `deleted_at`; implements all port methods)
- [x] 5.2 Implement `find_in_range` in the in-memory `ExpenseRepository` (exclude soft-deleted, owner-scoped, inclusive range)

## 6. Tests

- [x] 6.1 Fakes: `tests/budgeting/fakes/fake_budget_repository.py` → `FakeBudgetRepository`; reuse/extend the expense fake for `find_in_range`
- [x] 6.2 Use-case unit tests for `CreateBudgetUseCase` (happy path; overlap rejected incl. shared boundary; adjacent allowed; soft-deleted ignored; other person's budget ignored)
- [x] 6.3 Use-case unit tests for `GetActiveBudgetUseCase` (active found + totals; none → `None`; soft-deleted not active; expenses outside range excluded; overspend → negative remaining; no expenses → full remaining)
- [x] 6.4 Integration test `tests/budgeting/integrations/` wiring real in-memory adapters + determinism gateways through both use cases (create then read active with derived spend)

## 7. Quality gate

- [x] 7.1 Run `/trocado:guard` on the diff and resolve any findings
- [x] 7.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) green

## 8. Virtual Object refactor (post-review: separate enriched read from create response)

- [x] 8.1 Codify the **Virtual Object** convention in `CLAUDE.md` (domain folder list, naming table row, the entity/VO/virtual-object distinction table) and update this change's `design.md`
- [x] 8.2 Add `domain/virtual_objects/active_budget_virtual_object.py` → `ActiveBudgetVirtualObject` (holds `BudgetEntity` + `total_spent`, derives `remaining`); unit-test it
- [x] 8.3 Split read-models: `BudgetData` back to plain (create response, no spend) + new `ActiveBudgetData` (non-nullable `total_spent`/`remaining`)
- [x] 8.4 Single-input mappers: `BudgetDataMapper.to_data(budget)` and new `ActiveBudgetDataMapper.to_data(active)`
- [x] 8.5 `GetActiveBudgetUseCase` builds the Virtual Object and returns `ActiveBudgetData | None`; update tests

## 9. Module independence (post-review: budgeting must depend only on core)

- [x] 9.1 Add `budgeting/application/interfaces/spend_reader_interface.py` → `SpendReaderInterface` (gateway port, `total_spent(person_id, start, end) -> MoneyValueObject`) in budgeting's own language
- [x] 9.2 Refactor `GetActiveBudgetUseCase` to depend on `SpendReaderInterface` (not `ExpenseRepositoryInterface`); budgeting now imports nothing from `expenses`
- [x] 9.3 `FakeSpendReader` for isolated use-case tests; move expense-filtering coverage (range/person/soft-delete) to `ExpenseRepository.find_in_range` tests where it belongs
- [x] 9.4 Integration test wires a composition-root bridge (`SpendReaderInterface` over the real expenses ledger); only the wiring layer knows both modules
- [x] 9.5 Record the DIP / gateway-not-repository / deferred-adapter decision in `design.md`
