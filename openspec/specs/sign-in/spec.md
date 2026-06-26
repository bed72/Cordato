# sign-in Specification

## Purpose
TBD - created by archiving change sign-in. Update Purpose after archive.
## Requirements
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

### Requirement: Sign-in failures are a single generic, non-leaking error

The system SHALL reject every failed sign-in with one `InvalidCredentialsError` carrying a generic pt-BR
message (`"E-mail ou senha inválidos."`) that does NOT reveal which part of the credential was wrong. A
malformed email, an email that belongs to no active person, and a wrong password SHALL all produce the
**same** error — preventing account enumeration. This error is distinct from `delete-account`'s
`IncorrectPasswordError`: sign-in is pre-authentication and MUST stay generic.

#### Scenario: Unknown email is rejected generically

- **WHEN** a requester supplies an email that belongs to no active person
- **THEN** the system raises `InvalidCredentialsError`
- **AND** the message does not reveal whether the email exists

#### Scenario: Wrong password is rejected generically

- **WHEN** a requester supplies the email of an active person but a password that does not match the stored hash
- **THEN** the system raises `InvalidCredentialsError`
- **AND** the error is indistinguishable from the unknown-email rejection

#### Scenario: Malformed email is rejected generically

- **WHEN** a requester supplies an email that is not a valid address
- **THEN** the system raises `InvalidCredentialsError`
- **AND** it does NOT raise `InvalidEmailError` — a malformed email must not be distinguishable from a wrong credential

#### Scenario: An inactive (deleted) account cannot sign in

- **WHEN** a requester supplies the original email of a person whose account has been deleted/retired
- **THEN** the system raises `InvalidCredentialsError`
- **AND** no authenticated person is returned

### Requirement: Sign-in response time does not reveal whether the email exists

The system SHALL perform a password verification on **every** sign-in attempt, including when no active
person is found for the email — verifying the supplied password against a constant decoy hash. This SHALL
make the response time uniform whether or not the email exists, closing the enumeration-by-timing leak. This
requirement deliberately overrides the usual "cheap guard before expensive call" ordering: the verify is
paid even on the not-found path.

#### Scenario: Not-found path still pays a verification

- **WHEN** a requester supplies an email that belongs to no active person
- **THEN** the system still performs one password verification (against a constant decoy hash) before rejecting
- **AND** the rejection is `InvalidCredentialsError`, identical to the wrong-password case

#### Scenario: The decoy verification never authenticates

- **WHEN** the decoy hash is verified on the not-found path
- **THEN** the result is discarded and no person is ever returned, regardless of the verification outcome

