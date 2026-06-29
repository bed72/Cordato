## ADDED Requirements

### Requirement: Sign-up is exposed at POST /authentication/sign-up and returns a session

The system SHALL expose the `SignUpUseCase` at `POST /v1/authentication/sign-up`. A request carrying a
valid JSON body (`email`, `password`, `name`) SHALL invoke the use case and, on success, return HTTP
**201** with a `SessionResponse` — the opaque session `token`, its `expires_at`, and the new person's
public data (`id`, `name`, `email`). The endpoint is **public**: it SHALL NOT require an
`Authorization` header and SHALL NOT declare the `current_person` dependency.

#### Scenario: Valid sign-up body returns 201 with a session

- **WHEN** a `POST /v1/authentication/sign-up` request arrives with a valid body (`email`, `password`, `name`)
- **THEN** the system responds **201** with a `SessionResponse` carrying a `token`, `expires_at`, and the new person's `id`, `name`, and `email`

#### Scenario: Duplicate email returns 409

- **WHEN** a `POST /v1/authentication/sign-up` request arrives with an email already in use by an active person
- **THEN** the system responds **409** with the unified error envelope (`code: "email-already-in-use"`, pt-BR `message`)

#### Scenario: Invalid email format returns 422

- **WHEN** a `POST /v1/authentication/sign-up` request arrives with a malformed email
- **THEN** the system responds **422** with the unified error envelope (`code: "invalid-email"`, pt-BR `message`)

#### Scenario: Weak password returns 422

- **WHEN** a `POST /v1/authentication/sign-up` request arrives with a password that does not meet policy
- **THEN** the system responds **422** with the unified error envelope (`code: "weak-password"`, pt-BR `message`)

#### Scenario: Missing required field returns 422 with field details

- **WHEN** a `POST /v1/authentication/sign-up` request arrives with a missing required field
- **THEN** the system responds **422** with the unified error envelope including an `errors` list naming the offending field

### Requirement: Sign-in is exposed at POST /authentication/sign-in and returns a session

The system SHALL expose the `SignInUseCase` at `POST /v1/authentication/sign-in`. A request carrying a
valid JSON body (`email`, `password`) SHALL invoke the use case and, on success, return HTTP **200** with
a `SessionResponse`. The endpoint is **public**: it SHALL NOT require an `Authorization` header and SHALL
NOT declare the `current_person` dependency.

#### Scenario: Valid credential returns 200 with a session

- **WHEN** a `POST /v1/authentication/sign-in` request arrives with the email of an active person and the matching password
- **THEN** the system responds **200** with a `SessionResponse` carrying a `token`, `expires_at`, and the person's `id`, `name`, and `email`

#### Scenario: Wrong or unknown credential returns 401

- **WHEN** a `POST /v1/authentication/sign-in` request arrives with any invalid credential (unknown email, wrong password, inactive account, or malformed email)
- **THEN** the system responds **401** with the unified error envelope (`code: "invalid-credentials"`, generic pt-BR `message` that does not reveal which factor failed)

### Requirement: Sign-out is exposed at POST /authentication/sign-out and revokes the session

The system SHALL expose the `SignOutUseCase` at `POST /v1/authentication/sign-out`. The handler SHALL
read the Bearer token from the `Authorization` header and pass it directly to `SignOutUseCase`. On any
outcome (valid session revoked, token unknown, expired, or already revoked), the system SHALL respond
**204** with no body. The endpoint is **semi-public**: it does NOT declare `current_person` and therefore
does not validate the token before the use case runs — the use case's idempotency handles all cases
silently.

#### Scenario: Valid session is revoked and 204 is returned

- **WHEN** a `POST /v1/authentication/sign-out` request arrives with a valid Bearer token
- **THEN** the system revokes that session and responds **204** with no body

#### Scenario: Unknown or expired token is a silent no-op returning 204

- **WHEN** a `POST /v1/authentication/sign-out` request arrives with an unknown, expired, or already-revoked token
- **THEN** the system responds **204** with no body, without raising an error

#### Scenario: Missing Authorization header returns 204 as a no-op

- **WHEN** a `POST /v1/authentication/sign-out` request arrives with no `Authorization` header
- **THEN** the system responds **204** with no body (the use case receives an empty string and treats it as a no-op)

### Requirement: Protected routes resolve the caller's identity via an injectable current_person dependency

The system SHALL provide a named Litestar dependency `current_person` registered on the `/v1` router.
Its resolver (`resolve_current_person`) SHALL read the `Authorization: Bearer <token>` header, call
`ValidateSessionUseCase`, and return `PersonData` on success. Any handler that declares
`current_person: PersonData` in its signature SHALL be protected — auth runs automatically for that
handler. Any handler that omits it SHALL be public — the resolver never runs. A missing or invalid
token in a protected handler SHALL raise `InvalidSessionError`, which SHALL be mapped to **401** by the
identity error table.

#### Scenario: Valid token resolves to PersonData

- **WHEN** a protected handler is invoked with `Authorization: Bearer <valid-token>`
- **THEN** the resolver calls `ValidateSessionUseCase` and the handler receives `PersonData` for the session owner

#### Scenario: Missing or invalid token on a protected handler returns 401

- **WHEN** a protected handler is invoked with a missing, malformed, expired, or revoked token
- **THEN** the system responds **401** with the unified error envelope (`code: "invalid-session"`, pt-BR `message`) without invoking the handler body

#### Scenario: Public handler is unaffected by auth resolution

- **WHEN** a public handler (one that does not declare `current_person`) is invoked
- **THEN** the resolver is never called, regardless of whether the request carries an Authorization header

#### Scenario: Protected budgeting route uses the resolved person_id

- **WHEN** a protected handler such as `POST /v1/budgets` is invoked with a valid Bearer token
- **THEN** the resolved `current_person.id` is used as the `person_id` in the use-case command — not a placeholder

### Requirement: SessionResponse carries the token, expiry, and person's public data

The system SHALL return a `SessionResponse` DTO from sign-up (201) and sign-in (200) responses. It
SHALL carry `token` (the opaque Bearer credential), `expires_at` (ISO-8601 datetime), and a nested
person object with `id`, `name`, and `email`. The raw password SHALL NOT appear in any response field.

#### Scenario: SessionResponse shape on sign-in

- **WHEN** a sign-in succeeds
- **THEN** the response body contains `token` (str), `expires_at` (ISO-8601 datetime), and `person` with `id`, `name`, and `email`
- **AND** no password field is present in the response

#### Scenario: SessionResponse shape on sign-up

- **WHEN** a sign-up succeeds
- **THEN** the response body carries the same `SessionResponse` shape as sign-in
