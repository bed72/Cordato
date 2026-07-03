## Context

The composition root currently runs on Koin 4 (`io.insert-koin:koin-core`): two `module { }` blocks
(`coreModule`, `identityModule`) and a `startKoin { }` in `Main.kt`. Koin resolves the graph at runtime
via reflection. The team has committed to Micronaut as the eventual HTTP framework; its DI is
compile-time (annotation processing via KSP, no reflection). Running two DI mechanisms — or layering
Micronaut HTTP on top of a Koin graph — is undesirable, so we consolidate on Micronaut's DI now as a
standalone step, before any HTTP surface exists.

Hard constraints carried from `CLAUDE.md`:
- DI wiring lives only in each package's `main/` subpackage; a feature module inherits the shared
  kernel's bindings rather than re-declaring them.
- `domain/` and `application/` never reference the DI framework. Only `infrastructure/` and `main/` may.
- Boot must fail fast: the `DataSource` is realized on startup so Flyway migrations run and an
  unreachable DB / broken migration aborts startup.

## Goals / Non-Goals

**Goals:**
- Replace Koin with Micronaut compile-time DI while preserving the exact object graph and boot behavior.
- Keep annotations out of `domain`/`application`; confine wiring to `main/` via `@Factory` classes.
- Enforce the "no DI symbols in pure layers" rule with an automated Konsist test, extended to Micronaut.

**Non-Goals:**
- No HTTP surface: no controller, route, request validation, `SignUpError → HTTP` mapping, or global
  `ExceptionHandler`. Micronaut's HTTP server dependency is **not** added here.
- No change to any port, adapter, use case, entity, or persistence behavior — the graph's *contents* are
  identical, only the *container* changes.
- No GraalVM native-image build in this change (Micronaut merely makes it possible later).

## Decisions

**Decision: Micronaut compile-time DI via KSP, wired with `@Factory` methods in `main/`.**
Each current Koin module becomes a `@Factory`-annotated class in the same `main/` package. Each binding
becomes a factory method annotated `@Singleton` that constructs and returns the port type
(`ClockPort`, `PersonRepository`, `SignUpUseCase`, …), taking its collaborators as method parameters
(constructor injection through the factory). Rationale: the `domain`/`application` classes carry **no**
annotations, so Micronaut cannot (and must not) discover them by bean introspection — the `@Factory`
method is the single explicit place they are constructed. This maps 1:1 onto Koin's `single { }` and
keeps wiring confined to `main/`.
- *Alternative rejected — annotate the classes directly* (`@Singleton class SignUpUseCase`): would leak
  Micronaut into `application`/`domain`, violating the layer rule. `@Factory` is precisely the escape
  hatch for wiring types you don't own/annotate.
- *Alternative rejected — keep Koin*: leaves two DI stacks once Micronaut HTTP arrives; Koin is
  reflection/runtime, working against Micronaut's compile-time model.

**Decision: DI-only Micronaut footprint — `micronaut-inject` + KSP, no Netty.**
Add `micronaut-inject` (+ the Kotlin/KSP processor) and start via `ApplicationContext.run()` /
`.builder().start()` in `Main.kt`. No `micronaut-http-server-netty`. Rationale: HTTP is the next change;
pulling only the inject artifacts keeps this change to a pure DI swap and the boot a plain process (no
server port opened), matching today's IDE-run entry point.

**Decision: Preserve fail-fast by eagerly resolving `DataSource` in `Main`.**
Micronaut singletons are lazy (created on first lookup). To keep current behavior, `Main` explicitly
resolves the `DataSource` bean right after context start — its factory method runs
`Flyway.configure().dataSource(ds).load().migrate()` on construction, exactly as today.
- *Alternative considered — `@Context` on the `DataSource` factory method* (eager singleton created at
  context startup): equally valid and more declarative. Chosen the explicit resolve for parity with the
  existing `Main.kt`, which already documents "realizing the DataSource runs the migrations"; `@Context`
  is a fine follow-up if we want boot-ordering to be framework-driven.

**Decision: Extend the Konsist rule rather than replace it.**
The architecture test today asserts `domain`/`application` don't import Koin. Broaden it to a package
prefix / annotation check that also bars Micronaut DI symbols (`io.micronaut.context.annotation.*`,
`jakarta.inject.*`) from those layers, while allowing them in `infrastructure`/`main`.

## Risks / Trade-offs

- **Version compatibility: Kotlin 2.3.21 + JVM toolchain 25 + KSP + Micronaut.** Kotlin 2.3.21 is recent
  and KSP/Micronaut annotation processing is version-sensitive. → *Mitigation*: during `apply`, pin a
  known-good matrix (Micronaut 4.x with its KSP-based Kotlin support and a KSP2 version matching Kotlin
  2.3.21); verify `./gradlew build` and the app boot before archiving. If JVM 25 proves unsupported by
  the chosen Micronaut line, this surfaces immediately at build time and we adjust the toolchain or
  Micronaut version — captured as an open question below.
- **KSP adds a codegen step.** Bindings are generated at compile time, so a wiring mistake is a compile
  error (a plus), but IDE setup must run KSP. → *Mitigation*: KSP Gradle plugin wires generated sources
  into the main source set (same pattern already used for jOOQ codegen).
- **Lazy beans could hide a boot-time failure.** If nothing eagerly touches the `DataSource`, migrations
  wouldn't run at startup. → *Mitigation*: the explicit resolve in `Main` (above) keeps fail-fast.
- **Low rollback cost.** Pure wiring swap, no data/runtime-contract change; reverting the commit restores
  the Koin graph. Existing unit/integration tests construct collaborators directly (never via the
  container), so they neither break nor need the container to validate the migration.

## Migration Plan

1. Add Micronaut inject + KSP to the build; remove `koin-core`.
2. Convert `CoreModule` and `IdentityModule` to `@Factory` classes in place; rewrite `Main.kt` to start
   the `ApplicationContext` and resolve the `DataSource`.
3. Extend the Konsist rule; run `./gradlew build` (Konsist + all tests) and boot the app against a live
   DB (`make db-up`) to confirm migrations run and wiring resolves.
4. Post-merge: `/opsx:sync` to reconcile the `dependency-injection` spec and update `CLAUDE.md`'s DI
   decision from Koin to Micronaut.

Rollback: revert the change commit — Koin wiring is intact in history and has no persisted state to undo.

## Open Questions

- Exact pinned versions for Micronaut + KSP that are green on Kotlin 2.3.21 / JVM 25 — resolved
  empirically during `apply` (build must pass). If JVM 25 is unsupported by the chosen Micronaut line,
  do we drop the toolchain to the highest Micronaut-supported LTS, or hold the Micronaut version back?
