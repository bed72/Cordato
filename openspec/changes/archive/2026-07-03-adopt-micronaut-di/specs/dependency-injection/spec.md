# dependency-injection

## Purpose

Defines how Cordato composes its object graph at startup: which layer may reference the DI framework,
where wiring lives, how a bounded context inherits the shared kernel's bindings, and how the boot
sequence fails fast on an unhealthy database. These are architectural requirements independent of the
concrete container; the concrete container is Micronaut's compile-time DI.

## ADDED Requirements

### Requirement: Wiring is confined to each package's `main/` subpackage

The system SHALL declare every DI binding inside the owning package's `main/` subpackage
(`core/main`, `features/<context>/main`), and nowhere else. A package's `main/` subpackage is the only
place its wiring may reach across its own layers; `infrastructure/`, `application/`, and `domain/` SHALL
NOT declare bindings. Each package SHALL wire only the ports/adapters it owns — a feature SHALL NOT
re-declare the shared kernel's bindings.

#### Scenario: Bindings live only in `main/`

- **WHEN** the source tree is scanned for DI binding declarations (factory/bean definitions)
- **THEN** every such declaration resides in a `*/main/` package, and no binding is declared under
  `domain/`, `application/`, or `infrastructure/`

#### Scenario: Feature inherits the shared kernel's bindings

- **WHEN** `identity`'s wiring resolves `SignUpUseCase`, which depends on a `DSLContext`,
  `PersonRepository`, and `PasswordHasherPort`
- **THEN** the `DSLContext` (and other kernel-owned collaborators) are provided by `core`'s wiring, and
  `identity`'s `main/` factory declares only the identity-owned bindings, not a second `DSLContext`

### Requirement: `domain` and `application` stay free of any DI-framework symbol

The `domain/` and `application/` layers SHALL NOT import or annotate with any DI-framework symbol
(neither the previous Koin API nor Micronaut DI annotations such as `@Singleton`, `@Inject`, `@Factory`,
`@Bean`). DI-framework symbols are permitted only in `infrastructure/` and `main/`. This SHALL be
enforced by an automated architecture test, not left to convention.

#### Scenario: Architecture test rejects a DI annotation in a pure layer

- **WHEN** a type under `domain/` or `application/` imports or is annotated with a DI-framework symbol
- **THEN** the Konsist architecture test fails

#### Scenario: DI symbols are allowed at the edges

- **WHEN** a type under `infrastructure/` or `main/` uses a DI-framework symbol
- **THEN** the architecture test passes for that usage

### Requirement: Single composition root aggregates all packages' wiring

The system SHALL expose one composition root (`com.bed.cordato.main.Main`) that starts the DI container
with every package's wiring aggregated, producing a single object graph. Resolving a use case SHALL
yield an instance with all transitive dependencies satisfied from that one graph.

#### Scenario: Use case resolves with all dependencies satisfied

- **WHEN** the application starts and `SignUpUseCase` is requested from the container
- **THEN** a fully-constructed `SignUpUseCase` is returned, with its repository, hasher, and
  determinism collaborators injected — with no missing-binding error

### Requirement: Startup fails fast on an unhealthy database

The boot sequence SHALL eagerly realize the `DataSource` so that Flyway migrations run during startup.
If the database is unreachable or a migration fails, the application SHALL fail to start (surface the
error and exit non-successfully) rather than start in a half-initialized state.

#### Scenario: Broken database aborts startup

- **WHEN** the application boots against an unreachable database or a failing migration
- **THEN** startup aborts with the underlying error and the process does not reach a "started" state

#### Scenario: Healthy database boots with schema migrated

- **WHEN** the application boots against a reachable database with valid migrations
- **THEN** the migrations are applied during startup and the composition root completes wiring
