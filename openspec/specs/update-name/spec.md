# update-name Specification

## Purpose
Lets an authenticated person update their own display name in place — validated and persisted under
per-person authorization, touching no credential, email, status, session, or ledger. The name-only successor
of the former combined account update.
## Requirements
### Requirement: An authenticated person updates their own name in place

The system SHALL let an authenticated person update their own display name — overwriting the stored `name` —
while preserving the person's `id`, `created_at`, `status`, `email`, and password hash. No new person is
created. On success the system SHALL return the person's public data — `id`, `name`, `email`, `status`,
`created_at` — and SHALL NOT include the password or its hash.

#### Scenario: Person updates their own name

- **WHEN** an authenticated person submits a new, valid name
- **THEN** the system updates that person's name, keeps their id, created_at, status, email, and password
  hash, and returns the person's public data without any password field

### Requirement: Only the acting person can update their name, and the lookup is the authorization

The system SHALL resolve the acting person as the active account identified by the `requester_id` carried on
the command (itself resolved upstream from a live session) before applying any change. A `requester_id` that
resolves to no active person — unknown, or an account no longer active — SHALL be rejected with an "invalid
session" error, and nothing SHALL be changed. A person SHALL only ever update their own name; there is no path
to edit another person's.

#### Scenario: Unresolved acting person is rejected

- **WHEN** the command's requester_id matches no active person
- **THEN** the system rejects the update with an "invalid session" error and changes nothing

### Requirement: Name is re-validated

The system SHALL validate that the submitted name is present and non-empty after trimming surrounding
whitespace, and SHALL reject the update with an "invalid name" error without changing anything.

#### Scenario: Blank name is rejected

- **WHEN** the submitted name is empty or only whitespace
- **THEN** the system rejects the update with an "invalid name" error and changes nothing

### Requirement: Updating the name touches no credential, email, status, identity, session, or ledger

The system SHALL NOT modify the person's password hash, `email`, `status`, `id`, or `created_at`, and SHALL
NOT modify, relink, or delete any of the person's sessions, budgets, expenses, or pairs as part of a name
update. A name update changes only the stored name.

#### Scenario: Everything but the name is preserved

- **WHEN** a person updates their name
- **THEN** their password hash, email, status, id, created_at, sessions, budgets, expenses, and pairs are
  unchanged after the update
