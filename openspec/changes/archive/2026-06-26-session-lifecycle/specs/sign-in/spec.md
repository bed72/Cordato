## MODIFIED Requirements

### Requirement: Signing in verifies the credential against the active person's hash

The system SHALL accept an email and a raw password and, only when the email belongs to an **active** person
and the password verifies against that person's stored hash, SHALL issue a new session for that person and
return it as the `SessionData` read-model — carrying an opaque session `token`, the session's `expires_at`,
and the person's public data (`PersonData`). The raw password SHALL be verified through the password-hasher
port, never compared as plaintext, and SHALL never be persisted, logged, or echoed. The session SHALL be
created **only past a successful verification** — a failed sign-in issues no session.

The session `token` SHALL be an opaque, unguessable secret produced by a cryptographic generator, distinct
from the session's `id`, and SHALL be the only credential the caller needs to present on later authenticated
requests. Each sign-in SHALL issue its **own** session, so the same person signed in from two devices holds
two independent sessions.

#### Scenario: Correct credential issues a session and returns it

- **WHEN** a requester supplies an email of an active person and the password that matches that person's stored hash
- **THEN** the system creates a new session for that person and returns `SessionData` with an opaque `token`, an `expires_at`, and the person's `PersonData`
- **AND** the raw password is verified against the stored hash via the hasher port, never compared as plaintext

#### Scenario: A failed sign-in issues no session

- **WHEN** a sign-in attempt fails for any reason
- **THEN** no session is created and no token is returned

#### Scenario: Each sign-in issues an independent session

- **WHEN** the same active person signs in twice (e.g. from two devices)
- **THEN** two independent sessions are issued, each with its own distinct token, so revoking one leaves the other valid

#### Scenario: The raw password never leaks

- **WHEN** a sign-in is attempted, whether it succeeds or fails
- **THEN** the raw password is neither persisted, logged, nor included in any returned value or error message
