## Why

A person cannot do anything in Trocado without an account, and the account is the ledger's anchor — every
budget, expense, invite, and notification belongs to exactly one Person. Registration is therefore the first
domain capability: it creates that anchor, enforces the email-uniqueness invariant, and guarantees the
password is never stored in plaintext. This is also the first feature to exercise the project's Clean
Architecture conventions end to end, so it sets the pattern every later context follows.

## What Changes

- Introduce the `identity` context with its first use case: **register a new person** from a name, email, and
  password.
- Enforce the domain rules for a Person at creation time: email is validated and normalized and must be unique
  among **active** accounts; the password is validated against a policy and stored **only as an Argon2 hash**;
  the name is validated; the new account starts with `status = active` and receives an opaque `id` and a
  `created_at`.
- Define the ports this use case depends on: a `PersonRepositoryInterface` (async) for uniqueness check and
  persistence, and a `PasswordHasherInterface` (async) for hashing.
- Provide working adapters for the current (framework-less, ORM-less) stage: an **in-memory** person
  repository and an **Argon2** password hasher. This yields a vertical slice that runs and is fully testable
  today, without committing to a web framework or ORM.
- **Out of scope (deferred to their own changes):** any HTTP/web handler (no framework chosen yet), any
  ORM-backed persistence (no ORM chosen yet), authentication/login, and account deletion. This change only
  *registers* a person.

## Capabilities

### New Capabilities
- `register-person`: Creating a new individual account — input validation (name, email, password policy),
  email normalization and uniqueness among active accounts, password hashing (never plaintext), and the
  initial `active` state with assigned identity and timestamp. Returns the person's public data (never the
  password).

### Modified Capabilities
<!-- None. `dev-environment` is unaffected; this is a new domain capability. -->

## Impact

- **New module:** `src/trocado/features/identity/` with `domain/`, `application/`, `infrastructure/` layers.
- **New domain:** `PersonEntity`, value objects for email / name / password / password hash, and the related
  errors.
- **New ports + adapters:** `PersonRepositoryInterface` + in-memory `PersonRepository`;
  `PasswordHasherInterface` + Argon2 `PasswordHasher`.
- **New dependency:** `argon2-cffi` (runtime) for password hashing — the first runtime dependency in the
  project. No web/ORM dependency is added.
- **Tests:** unit tests for the domain rules and the use case (using the in-memory repository and a real or
  stubbed hasher).
- **CLAUDE.md "Stack and commands":** still TODO for web/persistence; unaffected by this change.
