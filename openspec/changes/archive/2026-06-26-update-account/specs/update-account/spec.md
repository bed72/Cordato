## ADDED Requirements

### Requirement: An authenticated person updates their own account in place

The system SHALL let an authenticated person update their own account — changing their `name` and
`email` — while preserving the person's `id`, `created_at`, `status`, and password hash. The update
SHALL be a full replacement of the editable fields: every editable field is supplied by the command and
overwrites the stored value. The person's identity, lifecycle state, and credentials are untouched (the
account stays `active` and the stored hash is unchanged), and no new person is created. On success the
system SHALL return the person's public data — `id`, `name`, `email`, `status`, `created_at` — and SHALL
NOT include the password or its hash.

#### Scenario: Person updates their own name and email

- **WHEN** an authenticated person submits a new name and a well-formed, unused email
- **THEN** the system updates that person's name and email, keeps their id, created_at, status, and
  password hash, and returns the person's public data without any password field

#### Scenario: Person changes only their name

- **WHEN** an authenticated person submits a new name and re-submits their current email
- **THEN** the system updates the name, leaves the email unchanged, and accepts the update

### Requirement: Only the acting person can update their account, and the lookup is the authorization

The system SHALL resolve the acting person as the active account identified by the `requester_id`
carried on the command (itself resolved upstream from a live session) before applying any change. A
`requester_id` that resolves to no active person — unknown, or an account no longer active — SHALL be
rejected with an "invalid session" error, and nothing SHALL be changed. A person SHALL only ever update
their own account; there is no path to edit another person's account.

#### Scenario: Unresolved acting person is rejected

- **WHEN** the command's requester_id matches no active person
- **THEN** the system rejects the update with an "invalid session" error and changes nothing

### Requirement: Email is re-validated and normalized

The system SHALL validate that the submitted email is well-formed and SHALL normalize it (trim
surrounding whitespace and lowercase it) before any uniqueness check or persistence. A malformed email
SHALL be rejected with an "invalid email" error and no change SHALL be persisted.

#### Scenario: Malformed email is rejected

- **WHEN** the submitted email is not a valid address
- **THEN** the system rejects the update with an "invalid email" error and changes nothing

#### Scenario: Email is normalized before use

- **WHEN** the submitted email contains leading/trailing spaces or uppercase letters (e.g.
  `"  Ana@Example.COM "`)
- **THEN** the email is stored and compared in its normalized form (e.g. `ana@example.com`), so
  uniqueness is evaluated against the normalized value

### Requirement: Name is re-validated

The system SHALL validate that the submitted name is present and non-empty after trimming surrounding
whitespace, and SHALL reject the update with an "invalid name" error without changing anything.

#### Scenario: Blank name is rejected

- **WHEN** the submitted name is empty or only whitespace
- **THEN** the system rejects the update with an "invalid name" error and changes nothing

### Requirement: Email stays unique among active accounts, excluding the acting person

The system SHALL reject an update whose normalized email already belongs to **another active** person.
The acting person SHALL be excluded from this check, so re-saving the account with the person's own
current email is allowed. An email that belongs to no other active person — including one previously
freed when an account was deleted and its email neutralized — SHALL be considered available. The
rejection message SHALL echo no email, so it can never be used to probe which addresses exist.

#### Scenario: Email already held by another active person is rejected

- **WHEN** the submitted email is already held by a different active person
- **THEN** the system rejects the update with an "email already in use" error, echoes no address, and
  changes nothing

#### Scenario: Re-saving the person's own email is allowed

- **WHEN** the acting person submits their own current email unchanged
- **THEN** the system does not treat the person as colliding with themselves and accepts the update

#### Scenario: A freed email can be claimed

- **WHEN** the submitted email is held by no other active person (e.g. it was neutralized by a prior
  account deletion)
- **THEN** the update succeeds and the person now holds that email

### Requirement: Updating an account touches no credentials, status, identity, or ledger

The system SHALL NOT modify the person's password hash, `status`, `id`, or `created_at`, and SHALL NOT
modify, relink, or delete any of the person's budgets, expenses, pairs, or sessions as part of an account
update. An account update changes only the name and email.

#### Scenario: Credentials and identity are preserved

- **WHEN** a person updates their account
- **THEN** their password hash, status, id, and created_at are unchanged after the update

#### Scenario: The ledger is untouched

- **WHEN** a person updates their account
- **THEN** their budgets, expenses, pairs, and sessions are unchanged
