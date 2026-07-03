## Why

Person records today live in `InMemoryPersonRepository` — a `ConcurrentHashMap` that
vanishes on restart and cannot back a real deployment. Every context to come
(`expense`, `budget`, `couple`) anchors on `identity` and will need durable storage
behind the same driven ports. This change lays the persistence foundation once, proves
it end-to-end on the existing `identity` slice, and leaves the shared wiring in place
for the next contexts to reuse. `domain` is untouched; `application` changes only by the
one minimal port evolution required to make datastore-enforced uniqueness observable (see
below) — no use-case logic beyond a single mapping line.

## What Changes

- Introduce **PostgreSQL** as the real datastore across dev/test/prod, run locally via
  Docker (`docker-compose`).
- Add **Flyway** migrations as the single source of truth for the schema; the first
  migration creates the `person` table with a `UNIQUE` constraint on `email`.
- Add **jOOQ** for type-safe access, with code generation at build time from the
  Flyway-migrated schema (generated classes confined to `infrastructure/`).
- Add a `JooqPersonRepository` implementing the `PersonRepository` port; bind it in
  `identityModule` in place of the in-memory adapter.
- **Evolve `PersonRepository.save`** to report whether the insert won or lost the email
  race (a `Boolean`), so datastore-enforced uniqueness is observable to the use case. The
  `existsByEmail` cheap pre-check stays (it spares the bcrypt cost on obvious duplicates);
  `save`'s result becomes authoritative for the concurrent case. `SignUpUseCase` maps a
  lost race to the existing `EmailAlreadyInUse` failure in one line. `InMemoryPersonRepository`
  adopts the same signature.
- Email uniqueness is enforced by the datastore via the `UNIQUE` constraint, so two
  concurrent signups for the same address can no longer both succeed; the adapter catches
  the unique-violation and returns the losing outcome rather than leaking a raw exception.
- `InMemoryPersonRepository` is **kept** as the fast fake for pure use-case tests; a new
  set of adapter tests exercises `JooqPersonRepository` against a real PostgreSQL spun by
  **Testcontainers**.
- Conventions carried by this foundation: money will persist as `INTEGER` cents (no type
  introduced yet — recorded as the rule for later contexts), dates as ISO-8601, and SQL
  kept dialect-portable (no PostgreSQL-only syntax without cause).

Explicitly **out of scope** (deferred until a consumer needs them): a `TransactionPort`
/ unit-of-work — no current use case spans multiple statements atomically (`SignUp`'s
race is fully closed by the `UNIQUE` constraint); the account-deletion atomic flow and
the budget non-overlap check-then-insert that will justify it do not exist yet.

## Capabilities

### New Capabilities
- `identity-persistence`: person records are stored durably and survive process restarts;
  email uniqueness is enforced at the datastore, including under concurrent registration,
  and surfaces as the existing non-enumerating conflict outcome.

### Modified Capabilities
<!-- None: no existing spec files under openspec/specs/ yet; SignUp's observable behavior
     is unchanged except durability and concurrency-safe uniqueness, captured above. -->

## Impact

- **Build** (`build.gradle.kts`): jOOQ codegen plugin, Flyway, PostgreSQL JDBC driver,
  Testcontainers (`postgresql`, JUnit 5) test dependencies; a jOOQ generation task wired
  to the migrated schema.
- **New infra**: `docker-compose.yml` (local PostgreSQL), `db/migration/` Flyway scripts,
  `JooqPersonRepository` (+ `models/`/`mappers/` as needed), jOOQ `DSLContext` provisioning
  and datasource config in the composition root.
- **DI** (`IdentityModule.kt`): `PersonRepository` now bound to `JooqPersonRepository`;
  datasource/`DSLContext` singletons added at the infrastructure root.
- **Tests**: new adapter tests under `infrastructure/repositories/` using Testcontainers;
  existing pure tests keep using the in-memory fake unchanged.
- **Runtime prerequisite**: a running Docker daemon for local dev, adapter tests, and jOOQ
  codegen.
