## Context

This is the first domain feature, built on the toolchain established by `dev-environment` (UV, ruff, pytest,
mypy strict, poe). The architecture is fixed by `CLAUDE.md`: Clean Architecture + DDD + Ports & Adapters, a
modular monolith under `src/trocado/`, async at every I/O boundary, a pure synchronous `domain/`, strict
naming, dedicated mappers at every hop, exact-decimal money (not relevant here), and per-person authorization.

Two stack decisions remain deferred project-wide: the **web framework** and the **ORM**. The user has scoped
this feature to a runnable, fully testable slice that does **not** force those decisions: domain + application
ports + an in-memory repository adapter + a real Argon2 hasher. Web handlers and ORM-backed persistence are
explicitly later changes.

## Goals / Non-Goals

**Goals:**
- A pure `PersonEntity` plus value objects and errors expressing the registration rules.
- An async `CreatePersonUseCase` orchestrating: validate → check email uniqueness → hash password → persist →
  return public data.
- Async ports: `PersonRepositoryInterface`, `PasswordHasherInterface`.
- Working adapters now: in-memory `PersonRepository`, Argon2 `PasswordHasher`.
- Deterministic, fast unit tests for every spec scenario.

**Non-Goals:**
- No web/HTTP layer (no framework chosen) — no Request/Response classes or controller in this change.
- No ORM / SQL persistence — no real database model.
- No login/authentication, no account deletion, no pairing.

## Decisions

**Decision 1 — Module layout.** Create `src/trocado/features/identity/` with `domain/`, `application/`,
`infrastructure/`. The `src/trocado/` package root and `features/` directory are created here (first feature),
not in `dev-environment`. `core/` is **not** created yet — nothing is shared until a second context needs it;
introducing it now would be speculative.

**Decision 0 — One concept per file, kept simple and separate.** Every value object, enum, error, port, and
mapper lives in its own dedicated file (e.g. `PersonStatus` → `domain/value_objects/person_status.py`, one error
class per file under `domain/errors/`). No bundling of related types into a shared module for convenience. This
is the standing convention for this and every future feature.

**Decision 2 — Value objects.** Model the rules as value objects so validation lives in the domain and is
reused:
- `EmailValueObject` — validates format, normalizes (trim + lowercase). Raises `InvalidEmailError`.
- `NameValueObject` — trims, rejects blank. Raises `InvalidNameError`.
- `PasswordValueObject` — validates the raw plaintext policy (≥ 8 chars). Raises `WeakPasswordError`. Holds the
  plaintext **transiently only** as the hasher's input; it is never persisted and has no place in any output.

The stored password **hash** is a plain `str`, **not** a value object: it enforces no invariant and carries no
behavior, so wrapping it would be ceremony (primitive-wrapping). A value object must earn its existence with a
rule or behavior — `Email`/`Name`/`Password` do (format, blankness, policy); a hash does not.
*Alternative considered:* a `PasswordHashValueObject` wrapper for symmetry. Rejected as over-engineering.

**Decision 3 — Identity and timestamp via ports, not `uuid`/`datetime` inside the entity.**
The pure domain must do no I/O and must be deterministic under test, yet `id` and `created_at` are
non-deterministic. Resolve this with two tiny application ports injected into the use case:
`IdentifierProviderInterface` (`async def generate() -> str`) and `ClockInterface` (`async def now() -> datetime`).
The use case obtains `id` + `created_at` and passes them into a pure `PersonEntity.create(...)` factory.
*Alternatives:* (a) generate the id/timestamp directly in the use case — simpler but makes the use case
non-deterministic and harder to assert; (b) generate inside the entity — violates domain purity. Ports win on
testability and keep the pattern honest from feature #1. They are declared async for contract uniformity even
though the in-memory adapters compute in memory.

The `IdentifierProvider` adapter uses **`uuid.uuid7()`** (stdlib in Python 3.14) rather than `uuid4()`: uuid7 is
time-ordered, so when an ORM is added later the `id` primary key keeps good B-tree index locality (near-sequential
inserts) instead of the random scatter `uuid4` causes — at zero dependency cost and with the same global
uniqueness. The id is stored as an opaque `str`, so the domain is unaffected by the choice; `uuid4` remains a
trivial fallback if random ids are ever preferred.

**Decision 4 — `PersonRepositoryInterface` shape.** Two async methods for this use case:
`async def find_active_by_email(email: EmailValueObject) -> PersonEntity | None` (uniqueness check against
active accounts only) and `async def create(person: PersonEntity) -> None` (persist). Reads exclude
non-active/removed accounts by the repository's own responsibility, per the soft-delete rule. The interface is an
`abc.ABC` with `@abstractmethod`s and takes/returns domain entities.

**Decision 5 — In-memory adapter naming and the Model/Mapper question.** The concrete adapter is named
`PersonRepository` (in `infrastructure/repositories/person_repository.py`) per the convention "the tool hides
inside the file" — "in-memory" is an implementation detail, not part of the class name, exactly as a future ORM
would be. It stores entities in a dict keyed by `id`. **No `PersonModel` / `PersonModelMapper` is created in
this change:** those exist to bridge an ORM/table, and there is no table yet. Inventing an in-memory "model"
would be ceremony with no boundary to cross. When the ORM is chosen, that change introduces `PersonModel` +
`PersonModelMapper` and reworks this adapter's internals. *Trade-off:* the model/mapper convention is deferred,
not skipped — recorded here so it is applied deliberately when persistence arrives.

**Decision 6 — Argon2 hasher adapter.** `PasswordHasher` (in `infrastructure`) implements
`PasswordHasherInterface` using `argon2-cffi`. argon2-cffi is synchronous and CPU-bound, so the adapter wraps
the hash call off the event loop (`asyncio.to_thread`) at its edge — never blocking the loop, never leaking the
sync call inward. The library name appears nowhere in the class/file name.

**Decision 7 — Data classes and mappers.** `CreatePersonData` (command: `name`, `email`, `password`) is the
use-case input; `PersonData` (read-model: `id`, `name`, `email`, `status`, `created_at`) is the output with no
password field. A dedicated `PersonDataMapper` converts `PersonEntity → PersonData`. No web Request/Response
mapper exists yet (no web layer).

## Risks / Trade-offs

- **In-memory persistence is not durable** → Acceptable: this slice exists to lock the domain + use-case
  contract and be testable now; durability arrives with the ORM change. The port boundary means that change
  won't touch domain or application code.
- **Two extra ports (clock, id) feel heavy for one feature** → Mitigated by how small they are; the payoff is
  deterministic tests and a pattern every later feature reuses instead of re-deciding.
- **Password policy is intentionally minimal (≥ 8 chars)** → A stronger policy (complexity, breach lists) can be
  a later change; the `PasswordValueObject` is the single place to extend it.
- **argon2-cffi parameters use library defaults** → Reasonable defaults for now; tuning cost/memory parameters
  can follow once a deployment target exists.

## Migration Plan

Additive only — a new module and one new runtime dependency (`argon2-cffi`). Nothing to migrate or roll back
beyond removing the new files/dependency. No persistence schema exists yet.

## Open Questions

- **Email format validation depth:** regex vs a small dependency (e.g. `email-validator`)? Leaning toward a
  pragmatic built-in check now to avoid a dependency for feature #1; revisit if stricter RFC compliance is
  needed.
- **Where the in-memory repository lives long-term:** it may become a test double once the ORM adapter exists.
  For now it ships as the real adapter so the slice runs outside tests too.
