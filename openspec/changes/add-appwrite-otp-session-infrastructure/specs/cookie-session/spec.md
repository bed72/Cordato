# Cookie Session

## Purpose

Restaurar e observar sessões Appwrite persistidas em cookies, distinguindo autenticação confirmada, ausência de sessão e falhas de validação.

## ADDED Requirements

### Requirement: Server-validated restoration
The application SHALL establish the initial session state by querying the authenticated account with persisted cookies. Cookie presence alone MUST NOT imply authentication, and restoration MUST NOT require an OTP or a refresh-token request.

#### Scenario: Valid persisted session
- **WHEN** a new application composition loads a valid persisted cookie session and the account query succeeds
- **THEN** session loading returns authenticated without requesting another code

#### Scenario: No valid server session
- **WHEN** the account query returns 401
- **THEN** session loading returns unauthenticated and invalid session cookies are removed
- **AND** observers receive unauthenticated only after the required local cleanup succeeds

### Requirement: Validation failure is not logout
Account-query failures other than confirmed unauthorized access SHALL preserve the last confirmed session state and propagate as application failures. Malformed payloads and local cookie-storage errors MUST NOT become successful absence of session.

#### Scenario: Network or server failure
- **WHEN** restoration encounters a timeout, connectivity failure, 403 or server error
- **THEN** session loading fails without clearing credentials or publishing unauthenticated

#### Scenario: Persistence failure
- **WHEN** reading or removing persisted session cookies fails
- **THEN** the failure remains observable and is not converted into an anonymous session

### Requirement: Shared session observation
Session consumers SHALL observe confirmed login, restoration and logout transitions through a shared application-facing stream. Authentication and Session MUST NOT import each other's presentation or concrete repository implementation.

#### Scenario: Login observed by existing subscriber
- **WHEN** OTP confirmation validates the account after storing cookies
- **THEN** an already subscribed session observer receives authenticated without polling

#### Scenario: Observation cancelled
- **WHEN** a consumer cancels its observation
- **THEN** its subscription is released without closing shared transport or affecting other subscribers

### Requirement: Ordered session effects
Session restoration, confirmation and logout SHALL be coordinated so older operations cannot overwrite newer confirmed session changes. This protection MUST cover persisted cookie effects as well as emitted state.

#### Scenario: Restoration overlaps logout
- **WHEN** restoration and logout are requested in that order before restoration finishes
- **THEN** the final confirmed state reflects the completed logout
- **AND** late account responses cannot restore credentials after logout

#### Scenario: Confirmation overlaps logout
- **WHEN** confirmation is pending and logout is requested afterward
- **THEN** cookie writes and session publication are ordered so successful logout leaves no confirmed authenticated session

#### Scenario: Concurrent restoration requests
- **WHEN** multiple consumers request restoration for the same unchanged session concurrently
- **THEN** they share the in-flight validation rather than issuing duplicate account queries

### Requirement: Persistent origin-bound credentials
Session credentials SHALL remain cookie-backed, persisted in the configured application-support directory and restricted to the configured service origin. Infrastructure MUST NOT export cookie secrets or create bearer-token persistence as a fallback.

#### Scenario: New process composition
- **WHEN** a fresh cookie store instance opens the same directory after a successful login
- **THEN** its account request includes the applicable persisted session cookies
- **AND** expired cookies are not treated as valid credentials

#### Scenario: Foreign origin request
- **WHEN** a request targets a different origin or attempts a redirect
- **THEN** session credentials are not forwarded to that destination
