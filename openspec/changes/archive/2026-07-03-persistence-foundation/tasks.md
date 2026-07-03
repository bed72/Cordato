## 1. Build & local infrastructure

- [x] 1.1 Add dependencies to `build.gradle.kts`: PostgreSQL JDBC driver, HikariCP, jOOQ, Flyway; test deps Testcontainers (`postgresql`, JUnit 5 integration).
- [x] 1.2 Add `docker-compose.yml` with a `postgres` service (pinned version, dev credentials, volume) and document `docker compose up` in the README/Makefile.
- [x] 1.3 Create the first Flyway migration `src/main/resources/db/migration/V1__person.sql`: `person` table with `id`, `email`, `hash`, `name`, `status`, primary key on `id`, and `unique (email)`. (Columns are `varchar` rather than `text` — standard SQL, indexable under the jOOQ DDLDatabase H2 codegen, still portable.)
- [x] 1.4 Wire the jOOQ codegen task to generate from the Flyway migrations. Per implementation decision the codegen uses jOOQ's `DDLDatabase` (parses the migration `.sql` directly — no Docker at build), outputs into the `infrastructure` package, and re-runs when migrations change.
- [x] 1.5 Verify `./gradlew build` runs codegen and produces the generated `PERSON` type.

## 2. Port evolution (application) — race-safe save

- [x] 2.1 Change `PersonRepository.save` to return `Boolean` (`true` = inserted, `false` = email already taken); update its KDoc. `existsByEmail` unchanged. (Method is named `signUp` in the code — a rename applied to the port + callers; behavior per spec.)
- [x] 2.2 Update `SignUpUseCase` to map `signUp == false` to `SignUpError.EmailAlreadyInUse` (keep the `existsByEmail` pre-check before hashing).
- [x] 2.3 Update `InMemoryPersonRepository.signUp` to return `false` when the email key is already present, `true` otherwise (via atomic `putIfAbsent`).
- [x] 2.4 No `PersonRepository` fake exists in `support/IdentityDoubles.kt`; the pure tests use the real `InMemoryPersonRepository` (the in-memory fake), already updated in 2.3. (Also repaired `passwordHasherMock`, left mid-refactor by the concurrent `hash`→`invoke` port rename, to the named-mock operator-invoke pattern.)

## 3. jOOQ adapter (infrastructure)

- [x] 3.1 Add the record↔entity mapper in `infrastructure/repositories/mappers` (unwrap `EmailValueObject`/`NameValueObject`, map `PersonStatusEnum` ↔ status text, `id`/`hash` as text). Generated types stay in `infrastructure/repositories/models`.
- [x] 3.2 Implement `JooqPersonRepository(dsl: DSLContext)`: `existsByEmail` via `fetchExists`; `signUp` via a plain `INSERT` that catches the unique-violation (SQLState `23505`) and returns `false`, else `true` — no exception crosses into application.
- [x] 3.3 Provision a HikariCP `DataSource` and a single `DSLContext` at the infrastructure composition root (`core/infrastructure/persistence/persistenceModule`) from env config (`DB_URL`/`DB_USER`/`DB_PASSWORD`); Flyway migrate runs on startup (entry point in `Main.kt` resolves the DataSource).
- [x] 3.4 Rebind `PersonRepository` to `JooqPersonRepository` in `identityModule` (replacing the in-memory binding); datasource/`DSLContext` singletons added in `persistenceModule`, loaded by the composition root.

## 4. Tests

- [x] 4.1 Add a Testcontainers PostgreSQL harness (`support/PostgresHarness.kt`, container shared per class, Flyway-migrated once) for adapter tests. (Written + compiles; execution needs Docker — see 5.1.)
- [x] 4.2 `JooqPersonRepository` adapter tests: saved person found by `existsByEmail`; unknown email returns `false`; row survives a re-read; duplicate `signUp` returns `false` and creates no second row (asserts the `UNIQUE`-enforced path resolves to the losing outcome, not a raw exception). (Written + compiles; execution needs Docker — see 5.1.)
- [x] 4.3 Concurrency test: two `signUp` calls for the same email racing (released together via a `CyclicBarrier`) yield exactly one stored row and one `false`. (Written + compiles; execution needs Docker — see 5.1.)
- [x] 4.4 Confirmed pure use-case tests (`SignUpUseCaseTest`) stay green against the updated in-memory fake. Also added a Konsist rule asserting jOOQ/JDBC/Hikari/Flyway never leak into `domain`/`application`.

## 5. Verify & reconcile

- [x] 5.1 Ran `./gradlew clean test` (colima Docker); all 25 tests pass — pure + adapter/concurrency suites green and Konsist rules hold (incl. the new "no jOOQ/JDBC in domain/application" rule). Wiring notes: the `test` task pins `api.version=1.41` (Docker 29 rejects docker-java's stale 1.32 default) and points Testcontainers at the colima socket when present.
- [x] 5.2 Verified against the `docker-compose` PostgreSQL: registered a person through the full composition root (Koin + Hikari + Flyway + jOOQ) → `Success`; read it back in a fresh JVM → `true` (survives process restart); restarted the (volume-backed) container → still `true`; duplicate signup → `Failure(EmailAlreadyInUse)`. (Used a temporary test-scoped smoke runner, since the design defers a permanent runnable entrypoint; scaffolding removed afterward. Also parametrized the compose host port via `CORDATO_DB_PORT` to sidestep a 5432 conflict.)
- [x] 5.3 Synced `identity-persistence` into `openspec/specs/` (new capability spec) via `/opsx:sync`, then archived via `/opsx:archive`.
