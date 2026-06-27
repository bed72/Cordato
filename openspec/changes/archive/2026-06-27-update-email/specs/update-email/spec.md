## ADDED Requirements

### Requirement: An authenticated person changes their own email in place

The system SHALL let an authenticated person change their own email — replacing the stored email — while
preserving the person's `id`, `created_at`, `status`, `name`, and password hash. The only account mutation is
the email; no new person is created. On success the system SHALL return the person's public data — `id`,
`name`, `email`, `status`, `created_at` — and SHALL NOT include the password or its hash.

#### Scenario: Person changes their own email

- **WHEN** an authenticated person submits the correct current password and a well-formed, unused new email
- **THEN** the system replaces that person's email, keeps their id, created_at, status, name, and password
  hash, and returns the person's public data without any password field

#### Scenario: The new email actually authenticates afterward

- **WHEN** a person has changed their email
- **THEN** signing in with the new email and their password succeeds, and signing in with the old email fails

### Requirement: Identity is re-confirmed by the current password, with no oracle

The system SHALL resolve the acting person as the active account identified by the `requester_id` carried on
the command (itself resolved upstream from a live session), and SHALL re-confirm identity by verifying the
submitted **current** password against that person's stored hash, before any change is made. A `requester_id`
that resolves to no active person and an incorrect current password SHALL fail **identically** with an
"incorrect password" error that reveals nothing about which case occurred, and nothing SHALL be changed. A
person SHALL only ever change their own email; there is no path to change another person's.

#### Scenario: Wrong current password is rejected

- **WHEN** the submitted current password does not match the acting person's stored hash
- **THEN** the system rejects the change with an "incorrect password" error and changes nothing

#### Scenario: Unresolved acting person is rejected identically

- **WHEN** the command's requester_id matches no active person
- **THEN** the system rejects the change with the same "incorrect password" error — indistinguishable from a
  wrong password — and changes nothing

### Requirement: The new email is re-validated and normalized

The system SHALL validate that the submitted email is well-formed and SHALL normalize it (trim surrounding
whitespace and lowercase it) before any uniqueness check or persistence. A malformed email SHALL be rejected
with an "invalid email" error, echoing no value, and no change SHALL be persisted. This validation is pure and
cheap and MAY be evaluated before the current-password verification.

#### Scenario: Malformed email is rejected

- **WHEN** the submitted email is not a valid address
- **THEN** the system rejects the change with an "invalid email" error and changes nothing

#### Scenario: Email is normalized before use

- **WHEN** the submitted email contains leading/trailing spaces or uppercase letters (e.g.
  `"  Ana@Example.COM "`)
- **THEN** the email is stored and compared in its normalized form (e.g. `ana@example.com`), so uniqueness is
  evaluated against the normalized value

### Requirement: Email stays unique among active accounts, excluding the acting person

The system SHALL reject a change whose normalized email already belongs to **another active** person. The
acting person SHALL be excluded from this check, so re-saving the account with the person's own current email
is allowed. An email that belongs to no other active person — including one previously freed when an account
was deleted and its email neutralized — SHALL be considered available. The rejection message SHALL echo no
email, so it can never be used to probe which addresses exist.

#### Scenario: Email already held by another active person is rejected

- **WHEN** the submitted email is already held by a different active person
- **THEN** the system rejects the change with an "email already in use" error, echoes no address, and changes
  nothing

#### Scenario: Re-saving the person's own email is allowed

- **WHEN** the acting person submits their own current email unchanged (with the correct password)
- **THEN** the system does not treat the person as colliding with themselves and accepts the change

#### Scenario: A freed email can be claimed

- **WHEN** the submitted email is held by no other active person (e.g. it was neutralized by a prior account
  deletion)
- **THEN** the change succeeds and the person now holds that email

### Requirement: A successful change purges every other session and preserves the acting one

On a successful email change the system SHALL purge **all** of the person's sessions **except** the one the
request was made on (identified by the current session's token), so any token issued before the change stops
resolving while the acting session stays live. The kept session SHALL remain valid; every other session —
live, revoked, or expired — SHALL be removed. The purge SHALL be idempotent: a person whose only session is
the acting one is a valid no-op.

#### Scenario: Other sessions are dropped, the current one survives

- **WHEN** a person with several live sessions changes their email from one of them
- **THEN** every other session of that person stops resolving, and the session the change was made on still
  authenticates

#### Scenario: A stolen older token stops working

- **WHEN** an email change succeeds
- **THEN** a token that was issued before the change (and is not the acting session) no longer resolves to a
  live session

### Requirement: Changing the email touches no credential, status, identity, or ledger

The system SHALL NOT modify the person's password hash, `name`, `status`, `id`, or `created_at`, and SHALL NOT
modify, relink, or delete any of the person's budgets, expenses, or pairs as part of an email change. An email
change alters only the stored email and the person's other sessions.

#### Scenario: Credentials, identity, and ledger are preserved

- **WHEN** a person changes their email
- **THEN** their password hash, name, status, id, created_at, budgets, expenses, and pairs are unchanged after
  the change
