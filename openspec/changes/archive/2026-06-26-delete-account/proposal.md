## Why

The domain promises two things that only exist as assertions until this change lands: *"reversible without
loss"* — already exercised by `dissolve-pair` — and its dark twin, **the account hard-delete, the one
physical deletion the model allows**. Today a person can be born (`register-person`), can pair and unpair,
but can never *leave*: there is no way to erase an account and walk away. This change delivers that closing
move — **delete-account**, the "nuclear option": a single, guarded, irreversible operation that erases a
person's ledger, frees their email, retires the account, and takes the shared view down as a consequence.
It is the feature that makes the flat reference graph *pay off*: because nobody references a person's data
but themselves (the pair owns nothing; a partner only ever had a *view*), erasing one person is safe and
local — no dangling links, no orphans, no one else's data touched.

## What Changes

- Add identity's first **destructive lifecycle** use case: **delete account**. Given the requester
  (`requester_id`) and their **raw password** for re-confirmation, the system performs one indivisible
  operation: **verify the password against the stored hash**, then — and only then —
  **physically erase (cascade) every budget and expense the person owns**, **neutralize the account's email**
  (to a sentinel derived from the id, e.g. `deleted+<id>@…`) so the original address is **free for reuse**,
  **set `status = deleted`** (the account no longer authenticates), and **dissolve any live pair as a
  consequence**. There is **no restore**.

- **Guard before destruction — password is the gate.** The very first step is verifying the supplied
  password against the person's stored hash; a mismatch raises a pt-BR, non-leaking error and **nothing is
  touched**. This honors the async contract's "keep the short-circuiting guard *before* the expensive/
  destructive work": no budget or expense is read or erased until identity is re-confirmed. (Invalidating
  the live **session** is part of the spec's intent but **deferred with the rest of the web layer** — there
  is no session port yet; the slice models the *password* re-confirmation, which is the part expressible
  today.)

- **The cascade is physical, and it is the domain's only hard delete.** Unlike day-to-day soft-delete
  (`deleted_at`), account deletion **physically removes** the person's budgets and expenses — there is no
  `deleted_at` to set, the rows cease to exist. This is deliberate and is the single exception to
  "soft-delete everywhere": a departing person leaves no ledger behind.

- **Email neutralization frees the address without resurrecting the account.** The account's email is
  rewritten to a sentinel derived from the id (collision-free, still a valid `EmailValueObject`), so the
  original address stops belonging to any *active* person. Reusing it later creates a **brand-new**
  `PersonEntity` (new id, empty ledger) — it does **not** resurrect the old one. `register-person` already
  supports this: `find_active_by_email` ignores non-active accounts, so the freed email reads as available.
  Neutralization is the second belt (the email is also no longer literally the same string).

- **Dissolve-as-consequence reuses, never re-implements.** Account deletion dissolves the person's live
  pair by composing the existing dissolve building block — but **idempotently**: a requester in no live pair
  is simply a no-op here (unlike `DissolvePairUseCase`, which rejects with `NotPairedError`). Erasing an
  account must succeed whether or not the person happened to be paired.

- **Cross-module side effects travel through identity's own anti-corruption ports — no outward import.**
  The use case lives in `identity` and must reach into `budgeting`, `expenses`, and `pairing`. Per the
  modular-monolith rule (and exactly mirroring how `pairing` consumes identity through
  `PersonDirectoryInterface` / `PartnerBudgetReaderInterface`), identity defines **its own** ports in its
  own vocabulary — a **budget eraser**, an **expense eraser**, and a **pair dissolver** — and depends only
  on those abstractions. The concrete adapters that bridge to the other modules are wired at the composition
  root (the only layer permitted to know two modules) and, like the existing partner readers, are **deferred
  with the web/ORM**; the runnable slice exercises the ports through hand-written fakes.

- **Atomicity is the contract; the transaction boundary lands with the ORM.** The spec describes one
  *indivisible* operation. At the current in-memory stage there is no transaction manager, so the use case
  **orchestrates the steps in a safe order** (guard first, then erase + retire + dissolve), and the design
  records that this orchestration becomes a single DB transaction the day the ORM lands — behind the same
  ports, without touching `domain/` or `application/`.

- Add one domain mutation to the **existing** `PersonEntity` — `delete()` — a single transition that flips
  `status` to `DELETED` and replaces `email` with the neutralized sentinel derived from the id. No new
  field (both `status` and `email` already exist); mirrors `PairEntity.dissolve` / `InviteCodeEntity.consume`
  as a small, factory-guarded state change.

- Ship a **runnable, fully-tested vertical slice** for the current stage: the new domain behavior
  (`PersonEntity.delete`), the new `IncorrectPasswordError`, the application command + `DeleteAccountUseCase`
  + `DeleteAccountData`, the `PasswordHasherInterface.verify` extension, the two new `PersonRepositoryInterface`
  methods (`find_active_by_id`, `delete`), the physical-erase methods on the budget/expense repositories, and
  the three new identity ports — exercised through the in-memory repositories, the real Argon2 hasher gateway
  (now verifying), and hand-written fakes for the cross-module ports. The use case returns nothing (`None`):
  deletion is a pure command whose only outcome is absence.

- **Out of scope (deferred to their own changes):**
  - **Session invalidation** — no session/auth port exists yet; it enters with the web layer behind a new
    port, without changing this use case's domain logic.
  - The composition-root **bridge adapters** for the eraser/dissolver ports (deferred with web/ORM, like the
    existing partner readers), and the real **DB transaction** that makes the orchestration atomic.
  - Any notification emitted on deletion, an "undo/restore" path (there is none by design), HTTP handler, or
    ORM model/mapper.

## Capabilities

### New Capabilities
- `delete-account`: The account hard-delete — the domain's only physical deletion. After re-confirming the
  requester's identity by **verifying their password against the stored hash**, the system performs one
  indivisible, irreversible operation: **physically erase (cascade) all of the person's budgets and
  expenses**, **neutralize the account's email** to a sentinel derived from the id (freeing the original for
  reuse), **set `status = deleted`** so the account no longer authenticates, and **dissolve any live pair as
  a consequence** (idempotent — a no-op when the person is in no live pair). A wrong password rejects with a
  pt-BR, non-leaking `IncorrectPasswordError` and changes nothing. There is no restore; reusing the freed
  email later creates a new person with a new id and an empty ledger.

### Modified Capabilities
<!-- None. `register-person` keeps its requirements verbatim — it already specifies that email uniqueness is
     scoped to *active* accounts and that a deleted account's freed email reads as available, which is exactly
     what makes reuse work; delete-account only makes `status = deleted` real for the first time. `dissolve-pair`
     is composed (idempotently), not changed. `create-budget` / `record-expense` / `active-budget` are unchanged:
     the budget/expense repositories gain a physical-erase method used only by account deletion, but no prior
     capability's behavior shifts. -->

## Impact

- **New domain behavior (identity):** `PersonEntity.delete()` — flips `status` to `DELETED` and replaces
  `email` with the neutralized sentinel derived from the id. No new field; mirrors `PairEntity.dissolve`.
- **New error (identity):** `IncorrectPasswordError` (pt-BR, non-leaking — e.g. `"Senha incorreta."`),
  raised when the re-confirmation password does not match the stored hash.
- **Extended port (identity) — `PasswordHasherInterface`:** gains `verify(password, hash) -> bool`
  (Argon2 verifies; the sync call wrapped off-loop at the adapter edge, like `hash`). The real Argon2
  gateway implements it.
- **Extended port (identity) — `PersonRepositoryInterface`:** gains `find_active_by_id(person_id) ->
  PersonEntity | None` (resolve the requester to read their hash and active status) and `delete(person) ->
  None` (persist the retired person — neutralized email + `DELETED` status). `find_active_by_email` and
  `create` unchanged. The in-memory `PersonRepository` implements both.
- **New cross-module anti-corruption ports (identity `application/interfaces`):** `BudgetEraserInterface`
  (`erase_for_person(person_id)`), `ExpenseEraserInterface` (`erase_for_person(person_id)`), and
  `PairDissolverInterface` (`dissolve_for_person(person_id)` — idempotent). Each in identity's vocabulary,
  no outward import; bridge adapters wired at the composition root are **deferred** with the web/ORM
  (mirroring the existing partner readers).
- **Extended ports (budgeting, expenses):** `BudgetRepositoryInterface` and `ExpenseRepositoryInterface`
  each gain `erase_for_person(person_id) -> None` — a **physical** purge of all of a person's rows (live and
  soft-deleted alike), the cascade's primitive. Their existing read/create methods and all prior capabilities
  are unchanged. The in-memory adapters implement the purge.
- **New application shapes (identity):** `DeleteAccountData` (command input — `requester_id` + raw password)
  and `DeleteAccountUseCase` (verify password → `IncorrectPasswordError` if mismatch → erase budgets +
  expenses, retire person, dissolve live pair → `None`). No read-model, no output mapper; the destructive
  steps that are mutually **independent** are issued with `asyncio.gather`, after the password guard.
- **Reused, unchanged:** the dissolve building block (composed via `PairDissolverInterface`), the Argon2
  gateway's hashing, the determinism ports. No web/ORM introduced; the slice runs and is tested entirely
  in-memory.
- **Tests:** unit test for `PersonEntity.delete` (status → `DELETED`, email neutralized, identity equality
  intact); unit test for `IncorrectPasswordError`; use-case tests for every scenario (correct password →
  budgets + expenses erased, person retired + email neutralized, live pair dissolved; correct password but
  person in no live pair → still succeeds, dissolve is a no-op; wrong password → `IncorrectPasswordError`,
  nothing erased or changed); a `verify` test for the Argon2 gateway (accepts the right password, rejects a
  wrong one); and an integration test wiring the in-memory `PersonRepository` + real Argon2 hasher + fakes
  for the eraser/dissolver ports through the use case, asserting the ledger is gone, the email is free for a
  fresh `register-person`, and the former pair is no longer live. Hand-written fakes
  (`fake_budget_eraser`, `fake_expense_eraser`, `fake_pair_dissolver`) under `tests/identity/fakes/`.
