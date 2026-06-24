## ADDED Requirements

### Requirement: Register a new person

The system SHALL register a new person from a name, an email, and a password, creating a Person with an opaque
`id`, a `created_at` timestamp, `status = active`, and the password stored only as a hash. On success the
system SHALL return the person's public data — `id`, `name`, `email`, `status`, `created_at` — and SHALL NOT
include the password or its hash in that output.

#### Scenario: Successful registration

- **WHEN** a registration is requested with a valid name, a well-formed and unused email, and a
  policy-compliant password
- **THEN** a new Person is created with `status = active`, an assigned `id` and `created_at`, the password
  persisted only as a hash, and the person's public data (without any password field) is returned

### Requirement: Email is validated and normalized

The system SHALL validate that the email is well-formed and SHALL normalize it (trim surrounding whitespace and
lowercase it) before any uniqueness check or persistence. A malformed email SHALL be rejected and no person
SHALL be created.

#### Scenario: Malformed email is rejected

- **WHEN** a registration is requested with an email that is not a valid address
- **THEN** the registration is rejected with an invalid-email error and no person is created

#### Scenario: Email is normalized before use

- **WHEN** a registration is requested with an email containing leading/trailing spaces or uppercase letters
  (e.g. `"  Ana@Example.COM "`)
- **THEN** the email is stored and compared in its normalized form (e.g. `ana@example.com`), so uniqueness is
  evaluated against the normalized value

### Requirement: Email is unique among active accounts

The system SHALL reject a registration whose normalized email already belongs to an **active** person. An email
that belongs to no active person — including one previously freed when an account was deleted and its email
neutralized — SHALL be considered available, and registering with it SHALL create a brand-new, distinct Person.

#### Scenario: Duplicate active email is rejected

- **WHEN** a registration is requested with an email already held by an active person
- **THEN** the registration is rejected with an email-already-in-use error and no second person is created

#### Scenario: A freed email can be reused as a new person

- **WHEN** a registration is requested with an email that no active person holds (e.g. it was neutralized by a
  prior account deletion)
- **THEN** the registration succeeds and creates a new Person with a new `id` and an empty ledger — it does not
  resurrect any previous account

### Requirement: Password is validated and stored only as a hash

The system SHALL validate the password against a policy of at least 8 characters and SHALL store it only as a
hash produced by a strong password-hashing algorithm. The plaintext password SHALL never be persisted, returned,
or logged. A password that violates the policy SHALL be rejected and no person SHALL be created.

#### Scenario: Weak password is rejected

- **WHEN** a registration is requested with a password shorter than 8 characters
- **THEN** the registration is rejected with a weak-password error and no person is created

#### Scenario: Stored password is a hash, not plaintext

- **WHEN** a person is successfully registered
- **THEN** the persisted password value is a hash that differs from the supplied plaintext, and the plaintext
  appears in no stored field, returned data, or log

### Requirement: Name is validated

The system SHALL validate that the name is present and non-empty after trimming surrounding whitespace, and
SHALL reject a registration with a blank name without creating a person.

#### Scenario: Blank name is rejected

- **WHEN** a registration is requested with a name that is empty or only whitespace
- **THEN** the registration is rejected with an invalid-name error and no person is created
