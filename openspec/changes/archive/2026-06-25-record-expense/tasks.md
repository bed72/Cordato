## 1. Shared kernel — Money (core/domain)

- [x] 1.1 Create `src/trocado/core/domain/__init__.py`, `core/domain/value_objects/__init__.py`, and
      `core/domain/errors/__init__.py` (first occupant of `core/domain/`)
- [x] 1.2 `core/domain/errors/invalid_money_error.py` → `InvalidMoneyError` (pt-BR, non-leaking message,
      e.g. `"Valor monetário inválido."`)
- [x] 1.3 `core/domain/value_objects/money_value_object.py` → `MoneyValueObject` (frozen, `Decimal value`;
      reject NaN/Infinity and >2 decimal places → `InvalidMoneyError`; normalize scale to 2 places; sign
      unconstrained; **no arithmetic yet**)
- [x] 1.4 Unit tests `tests/core/domain/value_objects/test_money_value_object.py` and
      `tests/core/domain/errors/test_invalid_money_error.py` (valid centavo amount preserved exactly,
      `19.9`→`19.90` normalization, NaN/Infinity rejected, >2 places rejected, zero & negative accepted,
      equality by value)

## 2. Expenses domain (pure, synchronous)

- [x] 2.1 Create `src/trocado/features/expenses/` with `domain/`, `application/`, `infrastructure/` and all
      sub-package `__init__.py` following the canonical layer structure
- [x] 2.2 `domain/errors/invalid_amount_error.py` → `InvalidAmountError` (pt-BR, e.g.
      `"Valor deve ser maior que zero."`)
- [x] 2.3 `domain/entities/expense_entity.py` → `ExpenseEntity` (`@dataclass(eq=False, slots=True)`;
      fields `id`, `created_at`, `person_id: str`, `amount: MoneyValueObject`, `date`,
      `description: str | None`, `deleted_at: datetime | None`; identity `__eq__`/`__hash__` on `id`;
      **no `budget_id`**). Pure `create(...)` factory: `deleted_at=None`, reject amount `<= 0` →
      `InvalidAmountError`, trim description and map blank → `None`
- [x] 2.4 Unit tests `tests/expenses/domain/entities/test_expense_entity.py` (factory happy path,
      non-positive amount rejected, description trimmed, blank description → `None`, `deleted_at` is
      `None`, identity equality) and `tests/expenses/domain/errors/test_invalid_amount_error.py`

## 3. Expenses application (async port, use case, data, mapper)

- [x] 3.1 `application/interfaces/expense_repository_interface.py` → `ExpenseRepositoryInterface`
      (`abc.ABC`): `async def create(expense: ExpenseEntity) -> None`
- [x] 3.2 `application/data/create_expense_data.py` → `CreateExpenseData` (`person_id: str`,
      `amount: Decimal`, `date`, `description: str | None`)
- [x] 3.3 `application/data/expense_data.py` → `ExpenseData` (`id`, `person_id`, `amount: Decimal`, `date`,
      `description`, `created_at`)
- [x] 3.4 `application/mappers/expense_data_mapper.py` → `ExpenseDataMapper` (`@staticmethod to_data`:
      `ExpenseEntity → ExpenseData`, unwrapping `MoneyValueObject` to `Decimal`)
- [x] 3.5 `application/use_cases/create_expense_use_case.py` → `CreateExpenseUseCase` (async): build
      `MoneyValueObject` from `command.amount` → get `id` from `IdentifierProviderInterface` and `now` from
      `ClockInterface` (core ports) → `ExpenseEntity.create(...)` → `repository.create(...)` → return
      `ExpenseData` via the mapper
- [x] 3.6 `tests/expenses/fakes/fake_expense_repository.py` → `FakeExpenseRepository` (hand-written,
      implements the port; exposes stored expenses for assertions). Reuse `tests/core/fakes/` `FakeClock`
      and `FakeIdentifierProvider`
- [x] 3.7 Unit tests `tests/expenses/application/use_cases/test_create_expense_use_case.py` covering every
      spec scenario: success (with/without description), non-positive amount rejected, invalid money
      (NaN/Infinity, >2 places) rejected, description trimmed, blank description → absent, returned data
      has no budget reference, `id`/`created_at` come from the injected ports

## 4. Expenses infrastructure (adapter)

- [x] 4.1 `infrastructure/repositories/expense_repository.py` → `ExpenseRepository` (in-memory `dict`
      keyed by `id`, implements the port; no lib/"in-memory" in the class name). **No
      `ExpenseModel`/`ExpenseModelMapper`** (no ORM yet)
- [x] 4.2 Unit test `tests/expenses/infrastructure/repositories/test_expense_repository.py` (created
      expense is retrievable/stored under its `id`)
- [x] 4.3 Integration test `tests/expenses/integrations/test_create_expense_integration.py` wiring the real
      `ExpenseRepository` + core `Clock` + `IdentifierProvider` through `CreateExpenseUseCase` for a
      successful recording

## 5. Verify

- [x] 5.1 Run the full gate: `uv run poe check` (format-check, lint, mypy strict, pytest) — all green
- [x] 5.2 Run `/trocado:guard` over the diff and confirm PASS (async port, dependency direction, naming, no
      lib names, dedicated mapper, derive-don't-store / no budget link, exact-decimal money, Money in core
      kernel, one-concept-per-file, value-object-earns-existence, pt-BR non-leaking errors, test layout)
