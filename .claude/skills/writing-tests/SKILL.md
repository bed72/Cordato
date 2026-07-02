---
name: writing-tests
description: Conventions for writing tests in the Cordato Kotlin backend — MockK test doubles in the support package, hand-written fakes for stateful collaborators, asserting sealed results. Use when adding or changing any test.
metadata:
  author: cordato
  version: "1.0"
---

How tests are written in this repo. Adding tests for already-specified behavior does **not** require an OpenSpec change.

## Test doubles live in one place

All reusable doubles go in the `com.bed.cordato.support` package under `src/test` — **never** as `private class`es inside a test file. Expose them as small factory functions:

- `clockFixedAt(instant)` and `idGeneratorOf(vararg ids)` → `support/CoreDoubles.kt`
- `passwordHasherMock()` → `support/IdentityDoubles.kt`

A test class imports the factory and uses it; it doesn't declare its own double.

## MockK vs. fake — pick by what the collaborator is

- **MockK is the default** for ports that are only *stubbed or verified* — Clock, IdGenerator, PasswordHasher. Build them with `mockk { every { … } returns/answers … }` and check interaction with `verify` / `verify(exactly = 0) { … }`. Do **not** hand-roll a recording spy.
- **Hand-written fake** only for a *stateful* collaborator with real behavior — e.g. `InMemoryPersonRepository` (which lives in `main`, so tests just `new` it). Never mock a repository's storage.

## Asserting outcomes

- Match on the sealed `*Result` / `*Error` type (`assertIs<SignUpResult.Success>(…)`, `when` over the error). Never `assertThrows` — domain errors are returned, not thrown.
- Prove ordering/short-circuit guarantees with `verify` (e.g. hashing is skipped on a duplicate e-mail: `verify(exactly = 0) { hasher.hash(any()) }`).

## MockK pitfalls in this codebase

- **`@JvmInline value class` arguments** (e.g. `PasswordValueObject`) arrive in an `answers {}` lambda as the underlying raw type. Use `firstArg<String>()`, not `firstArg<PasswordValueObject>()` — the latter throws `ClassCastException`.
- The determinism ports are `fun interface`s; mock the type and stub the single method (`every { generator() } returnsMany …`, `every { clock.now() } returns …`).

## Reference

`SignUpUseCaseTest` is the worked example — mirror its structure. Run `./gradlew test` (or `--tests "…SignUpUseCaseTest"`). Follow the repo import style (blank-line groups, shortest→longest line within each).
