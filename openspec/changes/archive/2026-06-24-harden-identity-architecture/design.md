## Context

The `identity` module shipped as the first vertical slice (`register-person`). An architecture audit against
CLAUDE.md found two deviations from the project's own rules:

1. **Misplaced determinism ports.** `ClockInterface` and `IdentifierProviderInterface` (and their adapters
   `Clock`, `IdentifierProvider`) live in `identity`. But every entity in the domain carries an `id` and a
   `created_at`, so these ports are needed by every future context (`budgeting`, `expenses`, `pairing`,
   `notifications`). CLAUDE.md mandates a `core/` shared kernel — "everything the other modules need", "follows
   the same structure as a feature" — which does not yet exist.
2. **A fictional invariant.** CLAUDE.md states `PersonEntity.create(...)` is "the only sanctioned constructor …
   so a caller can never build an entity in an illegal state." In practice `status` defaults to `active`, so
   the bare dataclass constructor is equivalent to the factory and the guarantee is empty — the existing tests
   even construct people directly with arbitrary status.

Constraints: web framework and ORM are still deferred; the slice stays pure-domain + ports + in-memory/real
adapters. The quality gate is `uv run poe check` (ruff format+lint, mypy --strict, pytest). The dependency rule
points inward (`infrastructure → application → domain`); `domain/` imports nothing outside itself.

## Goals / Non-Goals

**Goals:**
- Establish `src/trocado/core/` as the shared kernel and make it the owner of the determinism ports, so no
  feature ever imports determinism plumbing from another feature.
- Make `PersonEntity.create(...)` the only path that brings a person into the `active` state, reconciling the
  code with CLAUDE.md without forbidding legitimate rehydration.
- Keep the test tree mirroring the source tree, and close the coverage gap on the real gateways.
- Zero behavior change for the determinism relocation — same contracts, same adapters, only their home and
  import paths move.

**Non-Goals:**
- No web/HTTP layer, no ORM, no persistence rework. The in-memory `PersonRepository` stays.
- Not moving `PasswordHasher` — password hashing is an authentication concern owned by `identity`, not a
  universal kernel capability.
- Not solving the email-uniqueness race now (see Risks); only recording it.
- No new runtime dependency.

## Decisions

### 1. `core/` mirrors a feature's layer structure; only universal ports live there
`core/application/interfaces/` holds `ClockInterface` and `IdentifierProviderInterface`;
`core/infrastructure/gateways/` holds `Clock` and `IdentifierProvider`. The test doubles move to
`tests/core/fakes/` (`FakeClock`, `FakeIdentifierProvider`) so the test tree mirrors the new source home and
the fakes are reusable across features.

*Why over alternatives:* leaving them in `identity` forces the second consumer to either cross a context
boundary (import from `identity`) or duplicate the port + adapter — the exact DIP/DRY violation the kernel
exists to prevent. A neutral `core/` is the smallest move that removes the future coupling, and CLAUDE.md
already prescribes it. The bar for what earns a place in `core/` is "needed by more than one context with no
feature-specific behavior" — `clock` and `identifier` qualify; `password hasher` does not.

### 2. Remove the `status` default instead of locking the constructor
`PersonEntity` drops `status: PersonStatus = field(default=PersonStatus.ACTIVE)`; the field becomes required.
`create(...)` keeps passing `status=PersonStatus.ACTIVE`. The explicit constructor stays public for
rehydration (the future `ModelMapper` rebuilding a stored person with its persisted status).

*Why over alternatives:* a fully private/guarded constructor or a frozen entity fights Python and breaks the
entity's own lifecycle (a person must later transition `active → deleted`, so the entity cannot be immutable).
Removing the default is the surgical change that makes `create()` the *only* way to get `active` for free,
while a deliberate caller (a mapper) can still reconstruct any persisted state by stating it explicitly. This
makes the CLAUDE.md invariant true rather than aspirational.

### 3. Add gateway unit tests at their new homes
`Clock` (asserts tz-aware), `IdentifierProvider` (asserts distinct, non-empty, well-formed ids) → `tests/core/`.
`PasswordHasher` (asserts the digest differs from plaintext, carries the Argon2 marker, and is awaitable
off-loop) → `tests/identity/infrastructure/gateways/`. Today these are only exercised transitively by the
integration test.

## Risks / Trade-offs

- **Import churn across the slice** → All edits are import-path updates plus file moves; the quality gate
  (`mypy --strict` + pytest) catches any missed reference immediately. The relocation has no behavior change,
  so a green gate is sufficient proof.
- **`core/` introduced for a single consumer (possible YAGNI objection)** → Accepted deliberately: the ports
  are *already* conceptually shared, CLAUDE.md mandates the kernel, and the relocation is far cheaper now (one
  consumer) than after several features have hard-coded the wrong import. Mitigation: keep `core/` minimal —
  only the two determinism ports go in for now.
- **Required `status` field could surprise future construction sites** → Mitigated by `create(...)` remaining
  the registration path and the persistence mapper being the only other intended constructor; `mypy --strict`
  flags any site that forgets to supply `status`.
- **Email-uniqueness TOCTOU (deferred)** → `CreatePersonUseCase` does `find_active_by_email` then `create`,
  which is not atomic. Harmless for the in-memory adapter (no concurrency). **When the ORM lands**, correctness
  MUST rest on a database unique constraint on the active email plus catching the integrity violation and
  raising `EmailAlreadyInUseError` — not on the read-then-write check. Recorded here so it is not lost; no code
  change in this change.

## Migration Plan

1. Create `src/trocado/core/` packages and move the two ports + two adapters in; delete the vacated files in
   `identity`.
2. Update imports in `create_person_use_case.py` and the identity integration test to point at `core`.
3. Remove the `status` default on `PersonEntity`.
4. Move the determinism fakes to `tests/core/fakes/`; relocate the use-case test under
   `tests/identity/application/use_cases/`; add the gateway unit tests.
5. Run `uv run poe check` (must be green) and `/trocado:guard` over the diff (must be PASS).

Rollback is a straight `git revert` of the change — no data or schema is touched.
