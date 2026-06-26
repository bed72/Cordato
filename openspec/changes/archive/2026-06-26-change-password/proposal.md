## Why

A person can sign up, sign in, edit their name/email, and delete their account — but never rotate their
own password. `update-account` deliberately left credentials untouched and named `change-password` as its
own change, "with its own re-confirmation". This is the missing arm of credential maintenance: the one
place a person renews the secret that authenticates them, re-proving identity with the *current* password
before the swap, and — because a password rotation is often a response to a suspected leak — severing every
*other* session while keeping the acting one alive.

## What Changes

- New use case to **change an authenticated person's own password** — replace the stored hash, keeping
  the same `id`, `created_at`, `status`, `name`, and `email`.
- **Re-confirm identity with the current password** before anything is touched, exactly as
  `delete-account` does: `verify(current_password, person.password)`. An unresolved/non-active
  `requester_id` and a wrong current password fail **identically** with `IncorrectPasswordError` — no
  oracle reveals which.
- **New password re-validated against the policy** by `PasswordValueObject` (minimum length), rejecting
  with `WeakPasswordError`. The cheap pure validation happens first; the expensive `verify` of the current
  password guards the even-more-expensive `hash` of the new one (never hash if the guard would reject).
- **On success: hash the new password and persist** via a new `PersonEntity.change_password(new_hash)`
  transition + `PersonRepository.update(person)` — the entity owns the transition, as `update_account` and
  `delete` own theirs.
- **Session policy — purge every OTHER session, keep the current one.** A successful rotation drops any
  token issued before it (a stolen/old credential stops resolving) while the acting session stays live, so
  the person is not logged out of the device they just changed it from. This needs a new
  `SessionRepository` port method `purge_for_person_except(person_id, keep_token)`; the existing
  `purge_for_person` (all sessions, used by account deletion) is unchanged.
- **No secret ever leaves the domain.** The use case returns nothing meaningful; no plaintext and no hash
  is exposed. Domain error messages stay short, pt-BR, and non-leaking.
- No new error type is needed — `IncorrectPasswordError` and `WeakPasswordError` cover every rejection.

## Capabilities

### New Capabilities
- `change-password`: an authenticated person rotates their own password — re-confirming identity with the
  current password (non-leaking, no oracle), re-validating the new password against the policy, replacing
  the stored hash under per-person authorization, and purging every other session while preserving the
  acting one. No identity, status, or ledger is touched.

### Modified Capabilities
<!-- None. The session purge reuses the soft-/hard-delete pattern via a new, additive port method; no existing
     capability's REQUIREMENTS change. sign-out/validate-session behavior is unchanged. -->

## Impact

- **New code** in `features/identity`: `ChangePasswordData` (command), `ChangePasswordUseCase`, a
  `PersonEntity.change_password(new_hash)` transition, and a `purge_for_person_except(person_id, keep_token)`
  method on `SessionRepositoryInterface` + its in-memory adapter.
- **Reused unchanged**: `PasswordHasherInterface` (`verify` + `hash`), `PersonRepositoryInterface`
  (`find_active_by_id`, `update`), `PasswordValueObject`, and the errors `IncorrectPasswordError`,
  `WeakPasswordError`.
- **No identity churn**: `id`, `created_at`, `status`, `name`, and `email` are preserved; the only mutation
  is the password hash. No `updated_at` field is introduced.
- **Still ORM-deferred**: no `Model`/`ModelMapper`; the slice ships against the in-memory repositories.
- No change to budgets, expenses, or pairs; no migration; no new dependency.
