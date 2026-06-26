# sign-up Specification

## Purpose

Define how a new person signs up into the system: creating a Person from a name, an email, and a
password, with the email validated/normalized and unique among active accounts, the password validated and
stored only as a hash, and the name validated — returning the person's public data without ever exposing the
password.
## Requirements
### Requirement: Sign up a new person

The system SHALL sign up a new person from a name, an email, and a password, creating a Person with an opaque
`id`, a `created_at` timestamp, `status = active`, and the password stored only as a hash. On success the
system SHALL return the person's public data — `id`, `name`, `email`, `status`, `created_at` — and SHALL NOT
include the password or its hash in that output.

Bringing a person into existence in the `active` state SHALL be reachable only through the entity's creation
factory, which fixes `status = active`; the factory is the sole sanctioned path for sign-up. Constructing
a person with a caller-supplied `status` SHALL be reserved for rehydrating an already-persisted record (e.g. a
persistence mapper reconstructing a stored person) and SHALL NOT be used to sign up a new person. There SHALL
be no default that lets a bare construction silently produce an `active` person.

#### Scenario: Successful sign-up

- **WHEN** a sign-up is requested with a valid name, a well-formed and unused email, and a
  policy-compliant password
- **THEN** a new Person is created with `status = active`, an assigned `id` and `created_at`, the password
  persisted only as a hash, and the person's public data (without any password field) is returned

#### Scenario: Sign-up sets the active state through the factory, not a default

- **WHEN** a person signs up
- **THEN** its `active` status comes from the creation factory, and constructing a person without going through
  that factory requires the status to be supplied explicitly (no implicit `active` default)

### Requirement: Email is validated and normalized

The system SHALL validate that the email is well-formed and SHALL normalize it (trim surrounding whitespace and
lowercase it) before any uniqueness check or persistence. A malformed email SHALL be rejected and no person
SHALL be created.

#### Scenario: Malformed email is rejected

- **WHEN** a sign-up is requested with an email that is not a valid address
- **THEN** the sign-up is rejected with an invalid-email error and no person is created

#### Scenario: Email is normalized before use

- **WHEN** a sign-up is requested with an email containing leading/trailing spaces or uppercase letters
  (e.g. `"  Ana@Example.COM "`)
- **THEN** the email is stored and compared in its normalized form (e.g. `ana@example.com`), so uniqueness is
  evaluated against the normalized value

### Requirement: Email is unique among active accounts

The system SHALL reject a sign-up whose normalized email already belongs to an **active** person. An email
that belongs to no active person — including one previously freed when an account was deleted and its email
neutralized — SHALL be considered available, and signing up with it SHALL create a brand-new, distinct Person.

#### Scenario: Duplicate active email is rejected

- **WHEN** a sign-up is requested with an email already held by an active person
- **THEN** the sign-up is rejected with an email-already-in-use error and no second person is created

#### Scenario: A freed email can be reused as a new person

- **WHEN** a sign-up is requested with an email that no active person holds (e.g. it was neutralized by a
  prior account deletion)
- **THEN** the sign-up succeeds and creates a new Person with a new `id` and an empty ledger — it does not
  resurrect any previous account

### Requirement: Password is validated and stored only as a hash

The system SHALL validate the password against a policy of at least 8 characters and SHALL store it only as a
hash produced by a strong password-hashing algorithm. The plaintext password SHALL never be persisted, returned,
or logged. A password that violates the policy SHALL be rejected and no person SHALL be created.

#### Scenario: Weak password is rejected

- **WHEN** a sign-up is requested with a password shorter than 8 characters
- **THEN** the sign-up is rejected with a weak-password error and no person is created

#### Scenario: Stored password is a hash, not plaintext

- **WHEN** a person successfully signs up
- **THEN** the persisted password value is a hash that differs from the supplied plaintext, and the plaintext
  appears in no stored field, returned data, or log

### Requirement: Name is validated

The system SHALL validate that the name is present and non-empty after trimming surrounding whitespace, and
SHALL reject a sign-up with a blank name without creating a person.

#### Scenario: Blank name is rejected

- **WHEN** a sign-up is requested with a name that is empty or only whitespace
- **THEN** the sign-up is rejected with an invalid-name error and no person is created
