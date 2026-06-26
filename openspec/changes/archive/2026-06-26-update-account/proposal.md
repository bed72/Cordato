## Why

A person can sign up, authenticate, and delete their account, but never correct their own account. A
typo in the name or a moved email today forces deletion and a fresh sign-up — which throws away the
person's `id`, `created_at`, and entire ledger. Editing one's own name and email is the missing arm of
account maintenance, and it is the natural place to prove, once more, that the email-uniqueness
invariant holds for an edit exactly as it does at sign-up.

## What Changes

- New use case to **update an authenticated person's own account** — change their `name` and `email`
  in place, keeping the same `id`, `created_at`, `status`, and password hash.
- **Per-person authorization via the acting identity**: the command carries the `requester_id`
  resolved upstream from a live session; a person may only edit their own account. A `requester_id`
  that resolves to no active person SHALL be rejected with `InvalidSessionError`, revealing nothing.
- **Email re-validated and normalized** by `EmailValueObject` (trim + lowercase), and **name
  re-validated** by `NameValueObject` (non-empty after trim) — exactly as at sign-up.
- **Email-uniqueness invariant re-enforced** against the *other* active people: a normalized email
  already held by another active person rejects with `EmailAlreadyInUseError`. Re-saving the account
  with the person's own current email is allowed (the person is excluded from their own check).
- **No password, status, id, created_at, or ledger touched.** This is a pure account edit; the
  password hash, the account status, and every budget/expense/pair stay exactly as they were.
- A new repository port method to **persist the mutated active person** (distinct from `create` and
  `delete`).
- No new error type is needed — `InvalidEmailError`, `InvalidNameError`, `EmailAlreadyInUseError`, and
  `InvalidSessionError` cover every rejection. Messages stay short, pt-BR, and non-leaking.

## Capabilities

### New Capabilities
- `update-account`: an authenticated person updates their own `name` and `email` in place, under
  per-person authorization, re-validating the email/name invariants and re-enforcing email-uniqueness
  against the other active people, while touching no password, status, identity, or ledger.

### Modified Capabilities
<!-- None. Account editing reuses sign-up's email/name validation and uniqueness behavior unchanged; no existing requirement changes. -->

## Impact

- **New code** in `features/identity`: `UpdateAccountData` (command), `UpdateAccountUseCase`, a
  `PersonEntity.update_account(...)` mutation method, and an `update(...)` method on
  `PersonRepositoryInterface` + its in-memory adapter.
- **Reused unchanged**: `PersonData` / `PersonDataMapper` (output, already drops the hash),
  `EmailValueObject`, `NameValueObject`, and the errors `InvalidEmailError`, `InvalidNameError`,
  `EmailAlreadyInUseError`, `InvalidSessionError`.
- **No identity churn**: `id`, `created_at`, `status`, and the password hash are preserved; no
  `updated_at` field is introduced (adding edit-auditing would be a separate change).
- **Still ORM-deferred**: no `Model`/`ModelMapper`; the slice ships against the in-memory repository.
- No change to budgets, expenses, pairs, or sessions; no migration; no new dependency.
