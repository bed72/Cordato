## Context

The `identity` slice is fully implemented against ports, but the only `PersonRepository`
adapter is `InMemoryPersonRepository` (a `ConcurrentHashMap`). It cannot back a deployment
and loses data on restart. Every planned context (`expense`, `budget`, `couple`) anchors on
`identity` and will need durable storage behind its own ports, so the persistence stack is a
shared concern worth settling once, on the smallest real surface (`identity`), before more
contexts exist.

Constraints already fixed by the project's conventions and by earlier discussion:
- `domain` never imports a framework; `application` never imports a DI/DB library. Anything
  jOOQ/JDBC-shaped lives only in `infrastructure/`.
- Money persists as integer cents; dates as ISO-8601; SQL kept dialect-portable.
- Production is PostgreSQL. Dev and test use PostgreSQL too (not SQLite) to preserve
  dev/prod parity on exactly the range/uniqueness semantics that matter — run via Docker.

## Goals / Non-Goals

**Goals:**
- A durable `JooqPersonRepository` behind the existing `PersonRepository` port, on PostgreSQL.
- Flyway as the single source of truth for the schema; jOOQ types generated from it.
- Datastore-enforced email uniqueness that resolves to the existing `EmailAlreadyInUse`
  outcome, including under concurrent registration.
- Reusable wiring (datasource, `DSLContext`, codegen task, Testcontainers test harness) that
  the next contexts inherit without redesign.
- Pure use-case tests keep using the in-memory fake; adapter tests hit a real PostgreSQL.

**Non-Goals:**
- No `TransactionPort` / unit-of-work — deferred until the first genuinely multi-statement
  atomic use case (account deletion). `SignUp`'s only race is closed by the `UNIQUE`
  constraint.
- No new money/date value objects — this change persists only what `identity` already models;
  the cents/ISO rules are recorded here for the contexts that will introduce them.
- No `application` plugin / runnable entrypoint, no HTTP layer — out of scope.
- No repository methods beyond what `identity` uses today (`save`, `existsByEmail`).

## Decisions

### D1 — PostgreSQL everywhere, Docker-provided
Prod, dev, and test all run PostgreSQL. Dev via a `docker-compose.yml` service; tests via
Testcontainers; codegen against a throwaway migrated instance. Rationale: the two hardest
future invariants (budget non-overlap, atomic deletion) map to PostgreSQL features
(`EXCLUDE` constraints, ACID) and to range/aggregate SQL; running a *different* engine in dev
would break parity precisely where correctness lives. *Rejected:* SQLite-in-dev / PG-in-prod
(dual dialect, no parity on range/uniqueness); document/KV/graph stores (opposite of the flat,
derive-don't-store model).

### D2 — jOOQ for access, generated at build time from the migrated schema
jOOQ renders type-safe SQL; the generator runs at **build time** (never runtime) and reads the
schema **after Flyway has applied it**, so generated types can never drift from migrations.
*Primary approach:* a build step starts a Testcontainers PostgreSQL, runs Flyway migrate, then
jOOQ generates against that JDBC URL (via the `nu.studer.jooq` Gradle plugin or an equivalent
codegen task), then tears the container down. *Fallback if Docker-at-codegen is unwanted:*
jOOQ's `DDLDatabase` parses the Flyway `.sql` files directly with no live database — viable
only while the DDL stays portable (which D6 requires anyway). *Rejected:* Exposed (fine, but
jOOQ's SQL-first precision suits the range/aggregate queries the later contexts need); JPA/
Hibernate (annotations would leak into or couple the model, and runtime proxying fights the
"errors as data / explicit SQL" stance).

### D3 — Datasource and `DSLContext` provisioned only at the composition root
A pooled `DataSource` (HikariCP) and a single `DSLContext` are built in `infrastructure` (the
Koin composition root) from environment configuration (JDBC URL, user, password — 12-factor,
no secrets in code). `identityModule` (or a new shared infrastructure module) binds
`PersonRepository` to `JooqPersonRepository(dsl)`. `application`/`domain` never see `DSLContext`.

### D4 — Mapping stays in infrastructure; generated types never escape
The jOOQ-generated `PERSON` table/record lives in `infrastructure/repositories/models` (the
`models/` slot the conventions reserve). A mapper in `infrastructure/repositories/mappers`
translates a generated record to/from `PersonEntity`, unwrapping value objects at the boundary:
`EmailValueObject.value`/`NameValueObject.value` ↔ `text` columns, `PersonStatusEnum` ↔ a
`text`/`varchar` status column, `id` stored as `text` (honoring the opaque-`String` id contract
— no coupling to a `uuid` column type), `hash` as `text`. `PersonEntity` and its value objects
are unchanged.

### D5 — Uniqueness: cheap pre-check + authoritative, race-safe `save`
`existsByEmail` remains as the fail-fast guard the use case runs *before* bcrypt, so obvious
duplicates never pay the hashing cost. But a pre-check cannot close the concurrent-signup race,
so `PersonRepository.save` evolves to return a `Boolean`: `true` when the row was inserted,
`false` when the email was already taken. `SignUpUseCase` maps `false` to
`SignUpError.EmailAlreadyInUse` in a single line; the in-memory fake returns `false` when the
email key is present. In `JooqPersonRepository`, `save` performs a plain `INSERT` and catches
the unique-violation (SQLState `23505`) to return `false` — chosen over PostgreSQL's
`INSERT … ON CONFLICT DO NOTHING` to keep the SQL portable (D6); the exception is caught and
translated **inside the adapter**, so no exception crosses into `application`, honoring the
"errors are data, not thrown" rule. *Rejected:* leaving `save: Unit` and throwing a domain
exception on conflict (violates sealed-errors discipline); relying on the pre-check alone
(fails the concurrency scenario in the spec).

### D6 — Flyway migrations as the schema source of truth, kept portable
Versioned `V1__…sql` scripts under `db/migration/` own the schema; jOOQ reads them (D2), the app
runs them on startup. The first migration creates `person` with a `UNIQUE(email)` constraint.
DDL avoids PostgreSQL-only syntax without cause, so the codegen fallback (D2) stays open and a
future SQLite path, if ever wanted for something, isn't gratuitously blocked.

### D7 — Adapter tests on Testcontainers; pure tests keep the fake
`JooqPersonRepository` is covered by adapter tests that boot a real PostgreSQL via
Testcontainers (a container shared per test class, Flyway-migrated once), asserting durability,
the query path, and the concurrent-duplicate outcome. The existing use-case tests keep the
in-memory fake (now returning `Boolean` from `save`) — fast, no Docker. This is the standard
hexagonal split: many pure tests + a few real-adapter tests.

## Risks / Trade-offs

- **Docker becomes a hard prerequisite for dev, tests, and codegen.** → Accepted by the user;
  `docker-compose` for local run and Testcontainers reuse the same daemon. Document the
  requirement in the README/Makefile so a fresh clone knows why the build needs Docker.
- **Codegen against a live container slows the build and couples it to Docker availability.** →
  Cache generation (only regenerate when migrations change); the `DDLDatabase` fallback (D2)
  removes the Docker-at-codegen dependency if it becomes painful.
- **Evolving `save` touches `application` and the test fake**, contradicting the initial
  "infra-only" framing. → The change is one return type + one mapping line + the fake's return;
  it is the minimal way to make datastore uniqueness observable without throwing across layers.
- **Running Flyway on app startup can race in multi-instance deploys.** → Not a concern now
  (single instance); revisit with a migration gate when horizontal scaling arrives.
- **Portable-SQL discipline forgoes some PostgreSQL niceties now** (e.g. `ON CONFLICT`). → Cheap
  to relax later per-query if a concrete need appears; the default stays portable.

## Migration Plan

1. Add dependencies and the jOOQ codegen task; add `docker-compose.yml` and `V1__person.sql`.
2. Generate jOOQ types from the migrated schema; add `JooqPersonRepository` + mapper.
3. Evolve `PersonRepository.save` → `Boolean`; update `SignUpUseCase`, `InMemoryPersonRepository`,
   and the test fake accordingly.
4. Provision `DataSource`/`DSLContext` at the composition root; rebind `PersonRepository`.
5. Add Testcontainers adapter tests; keep pure tests green.
6. Run Flyway on startup. **Rollback:** rebind `PersonRepository` back to
   `InMemoryPersonRepository` in the Koin module — the port shape is unchanged, so application
   and domain need no revert.

## Open Questions

- Codegen path: commit to Testcontainers-at-build now, or start with `DDLDatabase` (no Docker at
  codegen) and switch only if portability bites? Lean Testcontainers for fidelity — confirm at
  implementation.
- Where do the shared `DataSource`/`DSLContext` singletons live — inside `identityModule` for now,
  or a new `core`/infrastructure module seeded here for reuse? Lean: a small shared infra module,
  since the next context will need it immediately.
