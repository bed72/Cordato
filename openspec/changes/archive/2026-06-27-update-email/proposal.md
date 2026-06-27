## Why

Identity treats the password as a *credential* — `update-password` re-confirms the current password (no
oracle) and purges every other session — but treats the **email as a free profile field**: `update-account`
edits `name` and `email` together, with no identity re-confirmation and no session purge. Yet the email is
the **login identifier**: changing it silently reassigns who can sign in. Today a person (or a hijacked live
session) can swap the login address with *less* ceremony than changing the password — an asymmetry that
under-protects the very field that authenticates the account.

This change closes that gap and, in doing so, makes the account-mutation surface symmetric and self-evident:
**`update-name`** (a plain profile edit), **`update-email`**, and **`update-password`** (both
credential-sensitive: re-confirm the current password, then purge every other session while keeping the
acting one). `update-account` — the combined name+email edit — dissolves into the first two.

## What Changes

- **New `update-email`** capability — an authenticated person changes their own email in place, re-validated
  and normalized (`EmailValueObject` → `InvalidEmailError`) and kept unique among other active people
  (`EmailAlreadyInUseError`, echoing no address). It is **credential-sensitive**, mirroring `update-password`:
  - **Re-confirm identity with the current password first** (`hasher.verify`). An unresolved/non-active
    requester and a wrong password fail **identically** with `IncorrectPasswordError` — no oracle.
  - **On success, purge every *other* session and keep the acting one** (`purge_for_person_except`), so any
    token issued before the email change stops resolving while the device that made the change stays signed in.
  - Touches nothing else: `id`, `created_at`, `status`, `name`, and the password hash are preserved; the
    ledger (budgets, expenses, pairs) is untouched. Returns the person's public data (no secret).
- **New `update-name`** capability — the name-only remainder of the old account edit: validate the name
  (`InvalidNameError`), resolve the acting person (`InvalidSessionError`), overwrite `name`, return public
  data. No password, email, status, session, or ledger is touched. *(This is the renamed, email-stripped
  successor of `update-account`.)*
- **BREAKING — `update-account` is removed**, split into `update-name` + `update-email`. A caller that
  previously sent name+email in one request now sends a name to `update-name` and (separately, with the
  current password) an email to `update-email`. The convenience of editing both at once is intentionally
  dropped: an email change must cost a password re-confirmation.
- `PersonEntity.update_account(name, email)` is replaced by two narrow transitions —
  `update_name(name)` and `update_email(email)` — alongside the existing `update_password` and `delete`.
- **No new ports, errors, or dependencies.** Reuses `PersonRepositoryInterface`
  (`find_active_by_id`, `find_active_by_email`, `update`), `PasswordHasherInterface` (`verify`),
  `SessionRepositoryInterface.purge_for_person_except` (introduced by `update-password`), `PersonDataMapper`,
  and the errors `InvalidEmailError`, `EmailAlreadyInUseError`, `IncorrectPasswordError`,
  `InvalidNameError`, `InvalidSessionError`.

## Capabilities

### New Capabilities
- `update-email`: an authenticated person changes their own email in place — re-confirming identity with the
  current password (non-leaking, no oracle), re-validating and normalizing the new email, re-enforcing
  uniqueness among other active people (no enumeration), and purging every other session while preserving the
  acting one. No password, status, identity, or ledger is touched.
- `update-name`: an authenticated person updates their own display name in place — validated and persisted
  under per-person authorization, touching no credential, email, status, session, or ledger.

### Modified Capabilities
<!-- None modified in place; update-account is removed (below) and replaced by the two new capabilities. -->

### Removed Capabilities
- `update-account`: removed. Its name edit becomes `update-name`; its email edit becomes the
  credential-sensitive `update-email`. **BREAKING**: the combined single-request name+email update no longer
  exists.

## Impact

- **New code** in `features/identity`: `UpdateEmailData`, `UpdateEmailUseCase`; `UpdateNameData`,
  `UpdateNameUseCase`; `PersonEntity.update_name` and `PersonEntity.update_email`.
- **Removed code**: `UpdateAccountData`, `UpdateAccountUseCase`, `PersonEntity.update_account`.
- **Tests**: rename `test_update_account_*` → `test_update_name_*` (name-only) and add
  `test_update_email_*` (use case + integration); split the entity's `update_account` test into
  `update_name` / `update_email`.
- **Reused unchanged**: all repositories, the hasher, `purge_for_person_except`, `PersonDataMapper`, and the
  five reused errors.
- **No identity churn, no migration, no new dependency.** Still ORM-deferred: no `Model`/`ModelMapper`; the
  slice ships against the in-memory repositories.
- No change to budgets, expenses, or pairs.
