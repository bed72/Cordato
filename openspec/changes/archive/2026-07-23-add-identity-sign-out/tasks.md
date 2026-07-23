## 1. Session repository — revoke a single session

- [x] 1.1 Add `fun revoke(sessionId: String): Boolean` to `core/application/driven/repositories/SessionRepository.kt`, documented symmetric to `revokeAllForPersonExcept`.
- [x] 1.2 Implement `revoke` in `core/infrastructure/repositories/PersistenceSessionRepository.kt` (jOOQ delete/update by session id, mirroring the existing `revokeAllForPersonExcept` implementation).

## 2. Identity application layer — SignOutUseCase

- [x] 2.1 Add `SignOutCommand(sessionId: String)` in `features/identity/application/driving/commands/`.
- [x] 2.2 Add `SignOutResult` (single `Success` case) in `features/identity/application/driving/results/`.
- [x] 2.3 Add `SignOutUseCase` in `features/identity/application/driving/use_cases/`, taking `SessionRepository` and calling `revoke(command.sessionId)`, returning `SignOutResult.Success`.

## 3. HTTP edge — protected sign-out route

- [x] 3.1 Add `@Post("/sign-out")` `@Authenticated` handler to `AuthenticationController`, injecting `SignOutUseCase`, building `SignOutCommand` from the bound `AuthenticatedActor.sessionId`.
- [x] 3.2 Wire the response to `204 No Content` on `SignOutResult.Success`.
- [x] 3.3 Wire `SignOutUseCase` into DI (identity's factory), mirroring how the other use cases are provided.

## 4. Reconcile specs

- [x] 4.1 Run `/opsx:sync` to merge the `session-management` and `identity-http-api` delta specs into `openspec/specs/`.
- [ ] 4.2 Run `/opsx:archive` once implementation and sync are complete.
