---
name: feature-tests
description: Scaffold or extend a Trocado/Cordato feature's test suite to the project's testing conventions — one test file per unit mirroring the source tree, fakes in their own files under tests/<ctx>/fakes/, integration tests at the module root under tests/<ctx>/integrations/, hand-written fakes preferred over mocks for ABC ports, and async driven with asyncio.run. Use when adding tests for a new or existing feature, or when test files have grown into grouped catch-alls.
metadata:
  author: trocado
  version: "1.0"
---

# Feature Tests

Generate (or reshape) a feature's tests to the conventions in `CLAUDE.md` → "Testing conventions". Tests are
first-class and follow the **same separation as production code**: one concept per file, mirroring the source.

## Test tree (mirror the source, one file per unit)

```
tests/<context>/
  domain/
    value_objects/   test_email_value_object.py        # one file per value object
    entities/        test_person_entity.py             # one file per entity
    errors/          test_invalid_email_error.py       # one file per error (message: short pt-BR, no leak)
  application/
    test_<verb>_<name>_use_case.py                      # one file per use case (scenarios as functions)
  infrastructure/
    repositories/    test_person_repository.py          # the adapter, unit-tested directly
  integrations/      test_create_person_integration.py  # AT THE MODULE ROOT — crosses layers
  fakes/
    fake_person_repository.py    # FakePersonRepository  — one fake per file
    fake_password_hasher.py      # FakePasswordHasher
    fake_clock.py                # FakeClock(now)
    fake_identifier_provider.py  # FakeIdentifierProvider(value)
```

## Rules (bake these in)

1. **One test file per unit, mirroring the source path.** Never a grouped `test_value_objects.py` covering
   Email + Name + Password + Entity at once. If you find one, split it.
2. **Scenarios are plain functions** (`def test_...():`) — no wrapper `Test*` class just to group; the file is
   already the grouping.
3. **Integration tests live at the test-module root** (`tests/<ctx>/integrations/`), because they wire real
   adapters through a use case and so belong to no single layer. Unit tests of an adapter go under the
   mirrored layer path (`infrastructure/repositories/`), exercising the adapter **directly** (e.g. the
   repository's `create` and the active-only filter of `find_active_by_email`) — not only via the use case.
4. **Fakes/doubles in their own files** under `tests/<ctx>/fakes/`, one per file, named `fake_<thing>.py` →
   `Fake<Thing>`. Each implements the real ABC port (mypy verifies the contract). Never define fakes inline in
   a test module.
5. **Prefer fakes over mocks** for ABC ports — typed, behavior-rich. Use `unittest.mock` (`AsyncMock`) or
   `pytest-mock` only for simple stubs / interaction assertions (e.g. "the hasher was called once").
   `pytest-mock` is a dev dependency added via a spec-first `dev-environment` change, not ad hoc.
6. **Async is driven with `asyncio.run(...)`** inside the (sync) test function — no extra plugin.
7. **`tests/` is a package** — every test dir (including `fakes/`, `integrations/`) has `__init__.py`, and
   `pyproject.toml` sets `pythonpath = ["."]` so `from tests.<ctx>.fakes.fake_clock import FakeClock` resolves.
8. **Cover every spec scenario.** Each `#### Scenario` in the change's spec is at least one test — including
   the negative/edge ones (duplicate, malformed, normalization, freed-email reuse, blank/weak input).
9. **Error-message tests assert no leak** — the message equals the expected short pt-BR string and does not
   contain the offending value (e.g. `assert "@" not in str(EmailAlreadyInUseError())`).

## Fake template

```python
# tests/<ctx>/fakes/fake_person_repository.py
from trocado.features.<ctx>.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
# ... domain imports ...

class FakePersonRepository(PersonRepositoryInterface):
    """In-memory test double. Stores entities; reads honor the same rules as the real adapter."""

    def __init__(self) -> None:
        self.people: list[PersonEntity] = []

    async def find_active_by_email(self, email: EmailValueObject) -> PersonEntity | None:
        return next((p for p in self.people if p.status is PersonStatus.ACTIVE and p.email == email), None)

    async def create(self, person: PersonEntity) -> None:
        self.people.append(person)
```

## Flow

1. Read the change's spec to enumerate units and scenarios.
2. Create/extend the mirrored test files — one per unit; split any grouped file you find.
3. Put shared doubles in `tests/<ctx>/fakes/` (one per file); ensure `__init__.py` and `pythonpath` are set.
4. Run `uv run poe check` — all green (format, lint, mypy strict, pytest).
