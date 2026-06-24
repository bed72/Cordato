## 1. Establish the `core/` shared kernel

- [x] 1.1 Create `src/trocado/core/` with `__init__.py` and the sub-packages `application/__init__.py`,
      `application/interfaces/__init__.py`, `infrastructure/__init__.py`, `infrastructure/gateways/__init__.py`
- [x] 1.2 Move `ClockInterface` to `core/application/interfaces/clock_interface.py` (unchanged contract)
- [x] 1.3 Move `IdentifierProviderInterface` to `core/application/interfaces/identifier_provider_interface.py`
      (unchanged contract)
- [x] 1.4 Move `Clock` adapter to `core/infrastructure/gateways/clock.py` (import the port from `core`)
- [x] 1.5 Move `IdentifierProvider` adapter to `core/infrastructure/gateways/identifier_provider.py` (import the
      port from `core`)
- [x] 1.6 Delete the vacated files under `identity/application/interfaces/` and `identity/infrastructure/gateways/`

## 2. Repoint identity onto the kernel

- [x] 2.1 Update `create_person_use_case.py` to import `ClockInterface` / `IdentifierProviderInterface` from `core`
- [x] 2.2 Update `tests/identity/integrations/test_create_person_integration.py` to import `Clock` /
      `IdentifierProvider` from `core`
- [x] 2.3 Grep the tree for any remaining `identity...clock`/`identifier_provider` import and fix it

## 3. Enforce the Person creation invariant

- [x] 3.1 In `person_entity.py`, remove the `status` default so the field is required; keep
      `create(...)` setting `status=PersonStatus.ACTIVE` as the only registration path
- [x] 3.2 Confirm existing direct constructions (test `_seed`/`_person`, future mapper) still pass `status`
      explicitly; adjust any that relied on the default

## 4. Tests: mirror the tree and cover the gateways

- [x] 4.1 Move the determinism fakes to `tests/core/fakes/` (`fake_clock.py` → `FakeClock`,
      `fake_identifier_provider.py` → `FakeIdentifierProvider`) with `tests/core/__init__.py` +
      `tests/core/fakes/__init__.py`; update importers in `tests/identity/`
- [x] 4.2 Relocate `tests/identity/application/test_create_person_use_case.py` to
      `tests/identity/application/use_cases/test_create_person_use_case.py` (+ `use_cases/__init__.py`)
- [x] 4.3 Add `tests/core/infrastructure/gateways/test_clock.py` — asserts `now()` is timezone-aware
- [x] 4.4 Add `tests/core/infrastructure/gateways/test_identifier_provider.py` — asserts two `generate()` calls
      yield distinct, non-empty, well-formed ids
- [x] 4.5 Add `tests/identity/infrastructure/gateways/test_password_hasher.py` — asserts the digest differs from
      the plaintext and carries the Argon2 marker

## 5. Verify

- [x] 5.1 Run `uv run poe check` (format-check, lint, mypy --strict, pytest) — all green
- [x] 5.2 Run `/trocado:guard` over the diff and confirm PASS (dependency direction, no lib names, naming,
      one-concept-per-file, determinism ports owned by `core`, test layout)
- [x] 5.3 Confirm no `identity` module imports determinism plumbing from another feature, and the spec deltas
      match the implemented behavior
