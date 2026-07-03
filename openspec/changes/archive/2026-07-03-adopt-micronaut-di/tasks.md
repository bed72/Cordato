## 1. Build: swap Koin for Micronaut DI

- [x] 1.1 Add the KSP Gradle plugin (`com.google.devtools.ksp`) at a version compatible with Kotlin 2.3.21, alongside the existing `kotlin("jvm")` and jOOQ plugins.
- [x] 1.2 Add the Micronaut inject dependencies: `io.micronaut:micronaut-inject` (implementation) and the Kotlin/KSP processor (`ksp("io.micronaut:micronaut-inject-kotlin")`), pinning a Micronaut 4.x line via its BOM. Do NOT add `micronaut-http-server-netty` — HTTP is a later change.
- [x] 1.3 Remove `io.insert-koin:koin-core:4.0.0` from dependencies.
- [x] 1.4 Wire KSP-generated sources into the main compilation if not automatic, mirroring the existing jOOQ `sourceSets.main` setup.
- [x] 1.5 Run `./gradlew help` (or a no-op build) to confirm the build script resolves with the new plugin/deps before writing code.

## 2. Migrate core wiring to a `@Factory`

- [x] 2.1 Rewrite `core/main/CoreModule.kt` as a `@Factory` class exposing `@Singleton` methods for `ClockPort` → `ClockAdapter`, `IdGeneratorPort` → `IdGeneratorAdapter`.
- [x] 2.2 Add a `@Singleton` factory method producing `DataSource` from `DatabaseConfiguration.fromEnv()` + Hikari, running `Flyway.configure().dataSource(ds).load().migrate()` on construction (preserve current pool settings: `maximumPoolSize = 10`).
- [x] 2.3 Add a `@Singleton` factory method producing `DSLContext` = `DSL.using(dataSource, SQLDialect.POSTGRES)`, taking the `DataSource` as a parameter (no `get<>()`).
- [x] 2.4 Keep the existing KDoc intent (shared kernel, `main/`-only wiring, jOOQ/JDBC confined to infrastructure); update the "never import Koin" note to name Micronaut.

## 3. Migrate identity wiring to a `@Factory`

- [x] 3.1 Rewrite `features/identity/main/IdentityModule.kt` as a `@Factory` class with `@Singleton` methods: `PasswordHasherPort` → `PasswordHasherAdapter`, and `PersonRepository` → `PersistencePersonRepository(dslContext)` taking `DSLContext` as a parameter.
- [x] 3.2 Add a `@Singleton` method producing `SignUpUseCase`, taking its collaborators (`PersonRepository`, `PasswordHasherPort`, plus the determinism/clock/id collaborators it needs) as parameters — the `DSLContext` and determinism ports resolve from core's factory.
- [x] 3.3 Confirm no second `DSLContext` binding is declared here (feature inherits core's binding).

## 4. Rewrite the composition root

- [x] 4.1 Rewrite `main/Main.kt` to start a Micronaut `ApplicationContext` (`ApplicationContext.run()` / `.builder().start()`) instead of `startKoin { modules(...) }`.
- [x] 4.2 Eagerly resolve the `DataSource` bean from the context right after start so Flyway migrations run and boot fails fast on an unreachable DB / broken migration.
- [x] 4.3 Keep the "started — database migrated and modules wired" log and the KDoc explaining the fail-fast boot; update wording from Koin to Micronaut.

## 5. Enforce the layer rule

- [x] 5.1 Extend the Konsist rule in `ArchitectureTest.kt` so `domain/` and `application/` are also forbidden from importing/annotating Micronaut DI symbols (`io.micronaut.context.annotation.*`, `jakarta.inject.*`), in addition to the existing Koin bar. (Note: no Koin bar existed yet — added a single DI-symbol rule covering both Koin and Micronaut.)
- [x] 5.2 Confirm the rule still allows those symbols in `infrastructure/` and `main/`.

## 6. Verify

- [x] 6.1 Run `./gradlew build` — Konsist architecture test + all existing unit/integration tests pass unchanged.
- [x] 6.2 Boot the app against a live DB (`make db-up`, run `Main` from the IDE): confirm migrations run on startup, `SignUpUseCase` resolves with all dependencies, and the started log prints. (Verified via a throwaway Postgres on :5433 — the user's :5432 is an SSH tunnel — driving `Main`: Flyway applied v1, `SignUpUseCase` resolved from the container, started log printed.)
- [x] 6.3 Confirm fail-fast: with the DB down, the app aborts startup with the underlying error rather than reaching the started state. (Verified: boot aborted with `PSQLException`, no started log.)

## 7. Reconcile docs (post-implementation)

- [x] 7.1 Run `/opsx:sync` to fold the `dependency-injection` spec into `openspec/specs/`.
- [x] 7.2 Update `CLAUDE.md`'s "DI" design decision (and the empty-project note in "Project state" if relevant) from Koin to Micronaut, preserving the `main/`-owns-wiring and framework-agnostic-layers rules.
