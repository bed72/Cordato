## Why

Every other identity operation already exists in code (sign-up, sign-in, sign-out, update own name/email/
password), but the one the `identity` README calls out as "the only genuinely destructive and irreversible
operation in the whole system" — deleting the account — has no implementation. The business rule is fully
specified in business language (step-up confirmation, atomic cascade, email neutralization, status
transition, pairing dissolution) but a person today has no actual way to leave the system.

## What Changes

- New step-up (session + current password) `DeleteAccountUseCase` in `identity`: confirms the current
  password against the active person, and — as a single atomic operation — invalidates **all** of that
  person's live sessions (more drastic than a password change's "all but this one": there is no session left
  to spare once the account stops existing), neutralizes the email (freed for reuse, original record kept
  for audit history), transitions the person's status to **deleted**, and triggers the hard removal of every
  budget and expense the person owns.
- Cross-context cascade for owned financial data, following ADR-0013's Anti-Corruption-Layer pattern:
  `identity` (the consumer) defines its own port(s) for "delete everything this person owns"; `budget` and
  `expense` each expose a new **hard**-delete-all-for-person use case (distinct from `budget-delete`'s
  existing **soft** self-service delete of a single budget — the cascade is physical, not a state
  transition); `identity/infrastructure/adapters/` implements the port by calling those use cases in-process.
  `budget` and `expense` never import or reference `identity`.
- **BREAKING** (data): budgets and expenses owned by a deleted person are physically removed, not
  soft-deleted — unlike `budget-delete`'s existing recoverable-in-data behavior for a single, self-service
  removal.
- Reusing the same neutral, indistinguishable `401` this context already uses for every other step-up
  operation (update-email, update-password): an orphaned/absent session and an incorrect confirmation
  password collapse to the same response, never revealing which factor failed.
- New protected HTTP route on `identity`'s HTTP slice — a step-up operation with a JSON body carrying the
  confirmation password, mirroring how `PATCH /persons/me/email` and `PATCH /persons/me/password` already
  require it. Success responds with no body (the account, and the session that just made the call, no longer
  exist).
- Pairing dissolution ("if the person was paired, that pairing is undone as a direct consequence", per the
  `identity` and `couple` READMEs) is explicitly **out of scope** for this change: the `couple` bounded
  context has no code yet, only its domain README — there is no pairing mechanism today, so no live couple
  can exist to dissolve. This is deferred to whichever change first implements `couple`.

## Capabilities

### New Capabilities

(none — account deletion is a self-service profile operation, same family as the other `person-profile`
mutations already specified there)

### Modified Capabilities

- `person-profile`: adds the account-deletion operation — confirms the current password, ends every live
  session of the person, neutralizes and frees the email, transitions status to deleted, and triggers the
  hard-delete cascade of owned budgets and expenses — as one ordered, all-or-nothing sequence, expressed as
  the same kind of exhaustive `sealed` result (no exceptions) the other `person-profile` operations use.
- `identity-http-api`: adds the protected account-deletion endpoint (step-up body validation, success
  response shape, and the shared neutral-`401`/`422` error mapping conventions the other step-up routes
  already document).
- `identity-persistence`: adds the persistence operation that neutralizes a person's email and transitions
  their status to deleted as one write, and documents that `findById`/`findByEmail` already collapse a
  deleted person into the same absent result non-active persons produce today.
- `session-management`: adds an operation to revoke **all** live sessions of a person (including the one
  making the current request), distinct from the existing "all except one" used by password rotation.
- `budget-persistence`: adds a hard-delete-all-for-person operation, physically removing every budget a
  person owns regardless of live/removed state — distinct from `budget-delete`'s existing soft-delete of a
  single, owner-selected budget.
- `expense-persistence`: adds a hard-delete-all-for-person operation, physically removing every expense a
  person owns — the first delete capability `expense` gets at all.

## Impact

- **New code (`identity`)**: `DeleteAccountCommand`, `DeleteAccountResult`, `DeleteAccountUseCase`,
  `DeleteAccountError` (domain); a new driven port for the owned-data cascade (e.g.
  `PersonOwnedFinancialsPort` in `identity/application/driven/ports/`), implemented in
  `identity/infrastructure/adapters/`; the new HTTP route + request DTO + error mapping entries +
  `AuthenticationController`/`PersonController`Doc updates; `messages.properties` i18n keys.
- **New code (`core`)**: `SessionRepository` gains a revoke-all-for-person operation (no exclusion), with a
  `PersistenceSessionRepository` implementation and a `FakeSessionRepository` update.
- **New code (`budget`)**: a hard-delete-all-for-person use case and the corresponding `BudgetRepository`
  method + `PersistenceBudgetRepository` implementation.
- **New code (`expense`)**: a hard-delete-all-for-person use case and the corresponding `ExpenseRepository`
  method + `PersistenceExpenseRepository` implementation.
- **Modified (`identity`)**: `PersonRepository` gains the email-neutralize-and-mark-deleted persistence
  operation, implemented in `PersistencePersonRepository`.
- **APIs**: one new protected endpoint on `identity`'s HTTP slice. No existing routes change shape.
- **Docs**: this change implements business rules the `identity`/`couple` READMEs already document — no
  README rewrite expected, only confirmation the code matches.
- Out of scope, per CLAUDE.md's non-behavioral-chore carve-out: tests, `*ControllerDoc`/OpenAPI polish — same
  split prior identity changes (`add-identity-sign-in`, `add-identity-sign-out`) used.
