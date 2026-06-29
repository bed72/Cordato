## ADDED Requirements

### Requirement: Authenticated routes receive the caller's identity via a typed DI dependency

The system SHALL wire a named provider `current_person` on the `/v1` router that resolves the acting
person from the `Authorization: Bearer <token>` header by delegating to `ValidateSessionUseCase`. A
handler SHALL be **protected** if and only if it declares `current_person: PersonData` in its
parameter list; the provider SHALL NOT run for handlers that omit it (public routes). This is the
sole mechanism for obtaining the caller's identity inside a handler — handlers SHALL NOT read the
`Authorization` header directly (except `sign-out`, which passes the raw token to the use case, not
to auth resolution). The provider SHALL be defined in
`identity/infrastructure/http/providers/current_person_provider.py` and imported by the composition
root, which registers it on the `/v1` router alongside the cross-cutting `clock` and `identifier`
providers.

#### Scenario: A handler omitting current_person is reachable without auth

- **WHEN** a handler that does not declare `current_person` is invoked without an `Authorization` header
- **THEN** the system processes the request normally — the provider is never invoked

#### Scenario: A handler declaring current_person is rejected without a valid token

- **WHEN** a handler that declares `current_person` is invoked without a valid `Authorization: Bearer <token>` header
- **THEN** the system responds **401** in the unified error envelope before the handler body runs

#### Scenario: The provider is registered on the /v1 router, not repeated per feature

- **WHEN** the application is assembled
- **THEN** `current_person` is registered once on the `/v1` router in the composition root, inherited by all feature routers mounted under it — no feature factory re-registers it

### Requirement: Bearer token transport is the auth credential convention for all API clients

The system SHALL use `Authorization: Bearer <token>` as the sole credential transport for all
authenticated API requests. The token SHALL be the opaque session token issued at sign-in or sign-up,
stored by the client in platform-provided secure storage (e.g. Keychain on iOS, Keystore on Android).
Cookie-based auth is NOT supported in this version. This convention applies uniformly — no route
accepts auth through a query parameter, a request body field, or a custom header.

#### Scenario: A valid Bearer token authenticates the request

- **WHEN** a request to a protected route carries `Authorization: Bearer <valid-token>`
- **THEN** the system resolves the token to the acting person and processes the request

#### Scenario: A non-Bearer Authorization header is treated as missing auth

- **WHEN** a request to a protected route carries an `Authorization` header that does not start with `Bearer `
- **THEN** the system responds **401** — the same as a missing header
