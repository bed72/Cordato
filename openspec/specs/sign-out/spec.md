# sign-out Specification

## Purpose
TBD - created by archiving change session-lifecycle. Update Purpose after archive.
## Requirements
### Requirement: Signing out revokes the session for the presented token

The system SHALL accept a raw session token and SHALL revoke the live session it identifies, so that the
token can no longer authenticate. After a successful sign-out, validating that same token SHALL fail. Only
the session for the presented token SHALL be revoked — any other session of the same person (e.g. another
device) SHALL remain valid.

#### Scenario: A live token is revoked

- **WHEN** a requester signs out with a token whose session is live
- **THEN** that session is marked revoked, and a subsequent validation of the same token is rejected

#### Scenario: Other devices keep their sessions

- **WHEN** a person who is signed in on two devices signs out on one (revoking that device's token)
- **THEN** the other device's token remains valid

### Requirement: Sign-out is idempotent and non-leaking

The system SHALL treat sign-out of a token that does not identify a live session — unknown, already expired,
or already revoked — as a **successful no-op**, never raising an error and never revealing whether the token
existed or in what state it was. Sign-out SHALL never act as an oracle for token validity.

#### Scenario: Signing out an unknown token succeeds silently

- **WHEN** a requester signs out with a token that matches no session
- **THEN** the operation succeeds, changes nothing, and raises no error

#### Scenario: Signing out an already-revoked token succeeds silently

- **WHEN** a requester signs out with a token whose session was already revoked or has expired
- **THEN** the operation succeeds, changes nothing further, and raises no error

