## ADDED Requirements

### Requirement: A valid session token resolves to its authenticated person

The system SHALL accept a raw session token and SHALL return the authenticated person (as `PersonData`) when
the token identifies a session that is **live** — `revoked_at` is null AND it has not expired — and whose
person is still **active**. This is the per-request authentication check: possession of an unexpired,
unrevoked token is the authorization. The repository SHALL own the validity filter, surfacing only live
sessions to the use case (mirroring how active/soft-delete reads are the repository's responsibility).

#### Scenario: A live token returns the person

- **WHEN** a requester presents a token whose session is not revoked, not expired, and whose person is active
- **THEN** the system returns that person's `PersonData`

#### Scenario: Expiry is evaluated against the current time

- **WHEN** a token's session has an `expires_at` at or before the current time
- **THEN** the session is treated as not live and the token does not resolve to a person

### Requirement: An invalid session token is rejected with a single generic, non-leaking error

The system SHALL reject any token that does not resolve to a live session whose person is active with one
generic `InvalidSessionError` (pt-BR `"Sessão inválida."`). An unknown token, an expired session, a revoked
session, and a token whose person is no longer active SHALL all produce the **same** error — never revealing
which condition failed, and never returning a person.

#### Scenario: Unknown token is rejected generically

- **WHEN** a requester presents a token that matches no session
- **THEN** the system raises `InvalidSessionError` and returns no person

#### Scenario: Expired token is rejected generically

- **WHEN** a requester presents a token whose session has expired
- **THEN** the system raises `InvalidSessionError`, indistinguishable from the unknown-token rejection

#### Scenario: Revoked token is rejected generically

- **WHEN** a requester presents a token whose session was revoked (e.g. by a prior sign-out)
- **THEN** the system raises `InvalidSessionError`, indistinguishable from the unknown-token rejection

#### Scenario: A token whose person is no longer active is rejected

- **WHEN** a requester presents an otherwise-live token whose person has since been deleted/retired
- **THEN** the system raises `InvalidSessionError` and returns no person
