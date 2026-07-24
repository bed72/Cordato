## 1. Core: revoke all sessions for a person

- [x] 1.1 Add `SessionRepository.revokeAllForPerson(personId): Unit` (core, driven port) — revokes every
      live session of `personId`, no exclusion; no-op, not an error, when the person has none.
- [x] 1.2 Implement it in `PersistenceSessionRepository` (jOOQ), mirroring `revokeAllForPersonExcept` minus
      the exclusion clause.
- [x] 1.3 Add the method to `FakeSessionRepository` (test double in `core/factories/`).

## 2. Budget: hard-delete-all-for-person cascade capability

- [x] 2.1 Add `BudgetRepository.deleteAllOwnedBy(personId): Unit` — physically removes every budget row
      for `personId` (live and already soft-deleted), datastore failures surface as infra exceptions (same
      convention as `create`).
- [x] 2.2 Implement it in `PersistenceBudgetRepository`.
- [x] 2.3 Add a new public use case in `budget` (e.g. `DeleteAllOwnedBudgetsUseCase`) that `identity`'s
      adapter will call — the only public entry point another context is allowed to invoke, per ADR-0013.
- [x] 2.4 Wire the new use case in `BudgetFactory`.

## 3. Expense: hard-delete-all-for-person cascade capability

- [x] 3.1 Add `ExpenseRepository.deleteAllOwnedBy(personId): Unit` — physically removes every expense row
      for `personId`; datastore failures surface as infra exceptions.
- [x] 3.2 Implement it in `PersistenceExpenseRepository`, going through the existing cache-invalidation
      decorator so the person's cached listing is invalidated by this mutation too (same single
      invalidation point the decorator already centralizes).
- [x] 3.3 Add a new public use case in `expense` (e.g. `DeleteAllOwnedExpensesUseCase`) that `identity`'s
      adapter will call.
- [x] 3.4 Wire the new use case in `ExpenseFactory`.

## 4. Identity domain

- [x] 4.1 Add `DeleteAccountError` sealed type: `InvalidCredentials`, `PersonNotFound`.

## 5. Identity application — driven side

- [x] 5.1 Add `PersonRepository.deleteAccount(id): Boolean` — neutralizes the e-mail (e.g.
      `deleted+<id>@deleted.invalid`, built through `EmailValueObject.of`) and transitions status to
      `DELETED` for the **active** person matching `id`, in one write; `true` when a row changed, `false`
      when no active person matched (collapses to `PersonNotFound`, mirroring `updateName`/`updatePassword`).
- [x] 5.2 Implement it in `PersistencePersonRepository`.
- [x] 5.3 Define the cross-context driven port in `identity/application/driven/ports/` (e.g.
      `PersonOwnedFinancialsPort`) with the "delete everything this person owns" contract, in identity's own
      vocabulary — settle the one-port-two-calls vs. two-ports question left open in design.md.
- [x] 5.4 Implement the port in `identity/infrastructure/adapters/`, calling `budget`'s and `expense`'s new
      use cases (2.3, 3.3) in-process. No import of `budget`/`expense` domain or application types — only
      their public use case signatures.

## 6. Identity application — driving side

- [x] 6.1 Add `DeleteAccountCommand` (personId, password).
- [x] 6.2 Add `DeleteAccountResult` sealed type (Success / Failure(DeleteAccountError)).
- [x] 6.3 Implement `DeleteAccountUseCase`: resolve active person → verify password (`InvalidCredentials`
      on mismatch) → call the owned-financials port (budget + expense cascade) → `PersonRepository
      .deleteAccount` (the point of no return; a lost race here is `PersonNotFound`) →
      `SessionRepository.revokeAllForPerson` — in that order, matching design.md's ordering decision.
- [x] 6.4 Wire the use case in `IdentityFactory` (hasher, `PersonRepository`, the new owned-financials port,
      core's `SessionRepository`).

## 7. HTTP layer

- [x] 7.1 Add `DeleteAccountRequest` DTO (`@Serdeable`), `password: String` with `@NotBlank` only (no
      policy validation), mirroring `UpdatePasswordRequest`'s current-password field.
- [x] 7.2 Add `DELETE /persons/me` on `PersonController`, `@Authenticated`, building the command from the
      resolved `AuthenticatedActor.personId` and the request body; success responds `204 No Content`.
- [x] 7.3 Map `DeleteAccountError` by kind: `InvalidCredentials` and `PersonNotFound` → the shared neutral
      `401` (`UNAUTHENTICATED`), same as the existing email/password step-up mappers.
- [x] 7.4 Add the new i18n message key(s) to `messages.properties` (reuse the existing `UNAUTHENTICATED`
      key if no new wording is needed).

## 8. Verification

- [x] 8.1 `./gradlew build` compiles clean, including the Konsist architecture test.
- [x] 8.2 Manually exercise the golden path against a running instance (`make db-up`, `./gradlew run`):
      sign up, sign in, create a budget/expense, `DELETE /persons/me` with the correct password, confirm
      `401` on the now-revoked session, confirm a new sign-up with the same original e-mail succeeds and is
      a distinct person.
