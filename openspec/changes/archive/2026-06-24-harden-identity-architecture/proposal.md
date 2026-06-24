## Why

An architecture audit of the `identity` module surfaced two real deviations from the project's own
non-negotiable rules. First, the determinism ports `ClockInterface` and `IdentifierProviderInterface` — needed
by **every** future feature, since every entity carries an `id` and a `created_at` — live inside `identity`
instead of the `core/` shared kernel that CLAUDE.md mandates. The next context to need them would be forced to
either import from `identity` (coupling unrelated bounded contexts and breaking the modular-monolith boundary)
or duplicate the port + adapter (violating DRY and the Dependency Inversion Principle). Second, CLAUDE.md
claims `PersonEntity.create(...)` is "the only sanctioned constructor … so a caller can never build an entity
in an illegal state", but the `status` field defaults to `active`, so the bare dataclass constructor produces
the same result and the invariant is fictional — a code↔spec divergence the project rules say must be
reconciled. Fixing both is cheapest now, with a single consumer, before more features inherit the debt.

## What Changes

- Introduce the `core/` shared kernel package (`src/trocado/core/`) following the same layer structure as a
  feature (`application/` · `infrastructure/`).
- **BREAKING (import paths):** relocate the determinism ports and adapters out of `identity` into `core`:
  - `ClockInterface`, `IdentifierProviderInterface` → `core/application/interfaces/`
  - `Clock`, `IdentifierProvider` → `core/infrastructure/gateways/`
  - `identity` (the `CreatePersonUseCase` and the integration test) imports them from `core`. No behavior
    changes — only ownership and import paths.
- `PasswordHasherInterface` / `PasswordHasher` **stay in `identity`**: password hashing is an
  authentication-specific concern, not a universal kernel capability.
- **Enforce the Person creation invariant:** remove the `status` default on `PersonEntity` so the bare
  constructor can no longer silently produce an `active` person. `PersonEntity.create(...)` becomes the only
  birth path that fixes `status = active`; the explicit constructor remains for legitimate rehydration (the
  future `ModelMapper` reconstructing a stored person with its persisted status).
- Relocate `tests/identity/application/test_create_person_use_case.py` to
  `tests/identity/application/use_cases/` so the test tree mirrors the source tree (testing convention).
- Move the determinism-port fakes (`fake_clock`, `fake_identifier_provider`) to `tests/core/fakes/` to match
  the ports' new home, and add unit tests for the real gateways (`Clock`, `IdentifierProvider`,
  `PasswordHasher`), which today are only exercised indirectly.
- Document the email-uniqueness check-then-create (TOCTOU) as a known constraint to resolve when a real ORM
  lands (rely on a DB unique constraint), in `design.md`. No code change now — the in-memory adapter has no
  concurrency.

## Capabilities

### New Capabilities
- `core-determinism`: The shared-kernel ports that keep the pure domain deterministic and testable — a clock
  supplying the current timezone-aware time, and an identifier provider supplying fresh opaque, time-ordered
  identifiers. Owned by `core/`, consumed by every feature; no feature-specific behavior.

### Modified Capabilities
- `register-person`: Tighten the Person-creation contract so that a registration (via the entity factory) is
  the only path that brings a person into existence in the `active` state; constructing a person with a
  caller-supplied status is reserved for rehydration of already-persisted records, never for registration.

## Impact

- **New package:** `src/trocado/core/` (`application/interfaces/`, `infrastructure/gateways/`, with
  `__init__.py` throughout).
- **Moved code:** `clock_interface.py`, `identifier_provider_interface.py`, `clock.py`,
  `identifier_provider.py` leave `identity` for `core`. `identity` deletes the now-empty determinism files.
- **Changed imports:** `create_person_use_case.py` and `tests/identity/integrations/test_create_person_integration.py`.
- **Changed domain:** `PersonEntity` loses the `status` default (construction-contract change).
- **Tests:** new `tests/core/` tree (fakes + gateway unit tests); use-case test relocated; new gateway unit
  tests under `tests/core/` and `tests/identity/infrastructure/gateways/`.
- **No new runtime dependency.** No web/ORM introduced. The pure domain and application ports are otherwise
  untouched; adapters slot behind the same contracts.
