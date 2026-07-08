---
name: writing-tests
description: Conventions for writing tests in the Cordato Kotlin backend — MockK test doubles and fakes in each package's factories/ package, cross-cutting fixtures in support/, asserting sealed results. Use when adding or changing any test.
metadata:
  author: cordato
  version: "1.0"
---

How tests are written in this repo. Adding tests for already-specified behavior does **not** require an OpenSpec change.

## Test doubles live outside the test class — never inline

Reusable doubles/fakes are **never** declared as classes inside a test file; a test class only holds
`@Test` logic. They live in dedicated files, split by what they are (mirroring the production convention
that a package owns its own wiring):

- **Doubles, fakes and their factory helpers** go in the owning package's `factories/` package, one file
  per thing, named `<Thing>Factory.kt` for a builder or `Fake<Thing>.kt` for a fake:
  - `clockFixedAt(instant)` → `core/factories/ClockFactory.kt`; `idGeneratorOf(vararg ids)` →
    `core/factories/IdGeneratorFactory.kt`; `session(...)` builder → `core/factories/SessionFactory.kt`
  - `passwordHasherMock()` → `features/identity/factories/PasswordHasherFactory.kt`
  - `FakePersonRepository` → `features/identity/factories/FakePersonRepository.kt`
- **The `@Factory @Replaces` wiring** that swaps a real bean for a double in a `@MicronautTest` also lives
  in `factories/` — e.g. `features/identity/factories/SignUpUseCaseMockFactory.kt`,
  `core/factories/FakeSessionRepositoryFactory.kt`. Never inline the `@Factory`/`@Replaces` in a test class.
- **Cross-cutting fixtures that are neither doubles nor factories** — harnesses and probe beans — go in the
  `support/` package: `support/PostgresHarness.kt`, `support/AuthProbeController.kt`.

A test class imports the factory/fixture and uses it; it doesn't declare its own.

## MockK vs. fake — pick by what the collaborator is

- **MockK is the default** for ports that are only *stubbed or verified* — Clock, IdGenerator, PasswordHasher. Build them with `mockk { every { … } returns/answers … }` and check interaction with `verify` / `verify(exactly = 0) { … }`. Do **not** hand-roll a recording spy.
- **Hand-written fake** only for a *stateful* collaborator with real behavior — e.g. `FakePersonRepository` / `FakeSessionRepository` in the package's `factories/`, which tests just `new` (or wire via a `@Replaces @Factory`). Never mock a repository's storage.

## Asserting outcomes

- Match on the sealed `*Result` / `*Error` type (`assertIs<SignUpResult.Success>(…)`, `when` over the error). Never `assertThrows` — domain errors are returned, not thrown.
- Prove ordering/short-circuit guarantees with `verify` (e.g. hashing is skipped on a duplicate e-mail: `verify(exactly = 0) { hasher.hash(any()) }`).

## MockK pitfalls in this codebase

- **`@JvmInline value class` arguments** (e.g. `PasswordValueObject`) arrive in an `answers {}` lambda as the underlying raw type. Use `firstArg<String>()`, not `firstArg<PasswordValueObject>()` — the latter throws `ClassCastException`.
- The determinism ports are `fun interface`s; mock the type and stub the single method (`every { generator() } returnsMany …`, `every { clock.now() } returns …`).

## Reference

`SignUpUseCaseTest` is the worked example — mirror its structure. Run `./gradlew test` (or `--tests "…SignUpUseCaseTest"`). Follow the repo import style (blank-line groups, shortest→longest line within each).
