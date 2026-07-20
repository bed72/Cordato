# ADR 0006: Dependency injection

DI is Micronaut's compile-time DI (annotation processing via KSP, no reflection), and each domain
package owns its own wiring in a `main/` subpackage: one `@Factory` class per package —
`core/main/CoreFactory.kt` (the shared kernel — determinism ports plus persistence) and
`features/<context>/main/<Context>Factory.kt` (e.g. `identity/main/IdentityFactory.kt`). Each factory
exposes `@Singleton` methods that construct and return the port types, taking their collaborators as
method parameters (the `@Factory` method is the single explicit place a pure, unannotated class is
constructed — Micronaut never discovers `application`/`domain` types by introspection). Each factory
wires only what its own package owns; a feature factory inherits core's bindings (e.g. the `DSLContext`)
rather than re-declaring them. The root `com.bed.cordato.main` package holds only `Main.kt`, the entry
point, which starts one Micronaut `ApplicationContext` (`ApplicationContext.run()`) — the context
discovers every package's `@Factory` into a single object graph. Micronaut singletons are lazy, so
`Main` eagerly resolves the `DataSource` bean to force the Flyway migrations to run at boot (fail-fast).
DI is deliberately *not* a per-feature `infrastructure/di/` concern: a package's `main/` subpackage is
the one place its wiring may reach across its own layers. `domain/` and `application/` never import
Micronaut or any DI annotation (`io.micronaut.context.annotation.*`, `jakarta.inject.*`) — they stay
framework-agnostic per the layer table above, enforced by the Konsist architecture test. (Infrastructure
still owns the adapters/config the factories wire — e.g. `DatabaseConfiguration` stays in
`core/infrastructure/persistence/`; only the Micronaut wiring lives in `main/`.) The classpath now also
carries `micronaut-http-server-netty` + `micronaut-serde-jackson` (compile-time JSON via `@Serdeable`, no
reflection) and `micronaut-validation` (edge Bean Validation) so `Main` starts an embedded server after
migrating. Micronaut applies AOP by subclassing, so the `kotlin("plugin.allopen")` plugin opens any type
carrying an `@Around`-meta annotation (e.g. `@Validated`); pure classes stay `final`.
