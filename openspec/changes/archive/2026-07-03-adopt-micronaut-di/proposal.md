## Why

Cordato needs a runtime framework to eventually expose its use cases over HTTP, and the team has
chosen Micronaut (compile-time DI, no reflection, cohesive HTTP + DI stack). Adopting it now means
consolidating on **one** dependency-injection mechanism: today the composition root runs on Koin
(runtime, reflection-based). Rather than carry two DI stacks — or adopt Micronaut's HTTP layer on top
of a foreign DI container later — we migrate the wiring to Micronaut's DI first, as a self-contained
foundation, so the subsequent REST work sits on a coherent base.

## What Changes

- **BREAKING** (internal wiring only, no behavior change): the composition root moves from Koin to
  Micronaut's compile-time DI. `io.insert-koin:koin-core` is removed.
- Micronaut (DI/AOP + runtime) and its KSP annotation processor are added to the build.
- The existing Koin modules become Micronaut `@Factory` classes, kept in the **same `main/` packages**
  they live in today (`core/main`, `features/identity/main`) — DI wiring stays confined to `main/`.
- `Main.kt` boots a Micronaut `ApplicationContext` instead of `startKoin`, preserving the current
  fail-fast startup (eagerly realize the `DataSource` so Flyway migrations run and a broken DB fails
  the boot).
- The Konsist architecture rule that forbids Koin imports in `domain`/`application` is extended to also
  forbid Micronaut DI annotations there — those layers stay framework-agnostic; annotations are allowed
  only in `infrastructure/` and `main/`.
- `CLAUDE.md`'s "DI" design decision (currently naming Koin) will be reconciled to Micronaut after
  implementation, via `/opsx:sync`.

Explicitly **out of scope** (next change): exposing any use case over HTTP. No controller, route,
request validation, `SignUpError → HTTP` mapping, or global `ExceptionHandler` is introduced here. This
change only swaps the DI/bootstrap mechanism; Micronaut's HTTP server is wired in a later, behavioral
change.

## Capabilities

### New Capabilities
- `dependency-injection`: how the application composes its object graph at startup — each package owns
  its wiring in a `main/`-local factory, feature wiring inherits the shared kernel's bindings,
  `domain`/`application` stay free of any DI-framework symbol, and the boot fails fast if the database
  is unreachable or a migration is broken.

### Modified Capabilities
<!-- None. person-signup and identity-persistence describe behavior that is unchanged; the ports,
     adapters, and use case keep their exact shapes — only how they are wired together changes. -->

## Impact

- **Build**: `build.gradle.kts` — add Micronaut BOM/dependencies + KSP plugin and processor; remove
  `koin-core`.
- **Code** (3 wiring files, no domain/application/adapter logic touched):
  - `core/main/CoreModule.kt` → `@Factory` producing `ClockPort`, `IdGeneratorPort`, `DataSource`
    (runs `Flyway.migrate()` on construction), `DSLContext`.
  - `features/identity/main/IdentityModule.kt` → `@Factory` producing `PasswordHasherPort`,
    `PersonRepository`, `SignUpUseCase`.
  - `main/Main.kt` → start Micronaut `ApplicationContext`, eagerly resolve `DataSource`.
- **Tests**: `ArchitectureTest.kt` (Konsist) rule updated to bar Micronaut DI annotations from
  `domain`/`application`. Existing unit/integration tests are unaffected — they construct collaborators
  directly and never went through the container.
- **Dependencies**: remove Koin; add Micronaut core + KSP. No change to jOOQ, Flyway, HikariCP,
  Postgres, BCrypt, Testcontainers.
- **Docs**: `CLAUDE.md` DI decision reconciled post-implementation.
