## ADDED Requirements

### Requirement: Deletion purges all of the person's sessions

The system SHALL purge **all** of the requester's opaque server-side sessions as part of the deletion
cascade, so that no token issued before the deletion continues to resolve to the retired account. This step
SHALL run only **after** the password guard has passed — a failed guard purges nothing — and SHALL be one of
the cascade's mutually-independent effects, issued alongside erasing budgets, erasing expenses, dissolving
the pair, and retiring the person.

The purge SHALL be **idempotent**: a requester who has zero sessions is a no-op here, never an error, and the
deletion still completes. Sessions are owned by the `identity` context itself, so this is a direct call on
the session store — no cross-context bridge is involved.

#### Scenario: A person's live sessions are purged on deletion

- **WHEN** a requester with one or more live sessions deletes their account (after a correct password)
- **THEN** every session belonging to that person is purged
- **AND** none of those tokens resolves to a session afterward — a subsequent validation of any of them
  finds nothing, exactly as for an unknown token

#### Scenario: Deletion succeeds when the requester has no sessions

- **WHEN** a requester who has no sessions deletes their account
- **THEN** the deletion still completes (ledger erased, account retired, email neutralized, any pair
  dissolved)
- **AND** the session purge is a no-op, raising no error

#### Scenario: A wrong password purges no sessions

- **WHEN** a requester supplies a password that does not match their stored hash
- **THEN** the system raises `IncorrectPasswordError`
- **AND** none of the requester's sessions is purged — they remain exactly as they were

#### Scenario: Only the requester's sessions are purged

- **WHEN** a requester who is in a live pair deletes their account
- **THEN** only the requester's own sessions are purged
- **AND** the former partner's sessions remain live and continue to resolve
