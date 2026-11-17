# Email OTP Authentication

## Purpose

Disponibilizar entrada sem senha por código de e-mail para consumidores de aplicação, independentemente da implementação futura das telas.

## ADDED Requirements

### Requirement: Passwordless challenge request
The application SHALL request an email OTP for new and existing accounts through the same operation, without a password or a separate account-registration request. Requesting a code MUST NOT publish an authenticated session.

#### Scenario: Challenge accepted
- **WHEN** a consumer supplies an email and the service accepts the OTP request
- **THEN** the operation returns the user identifier required for confirmation directly as a String, without a challenge wrapper
- **AND** no password or administrative credential is sent
- **AND** the application does not claim that the account was previously registered

#### Scenario: Repeated request
- **WHEN** a consumer explicitly requests another code
- **THEN** a new request is made and its returned challenge supersedes the previous challenge for that consumer
- **AND** infrastructure does not introduce timers, automatic retries or resend loops

### Requirement: OTP session confirmation
The application SHALL exchange the challenge user identifier and the supplied OTP for a cookie-backed session. Confirmation SHALL complete successfully only after cookie handling and the subsequent account request succeed. Account response fields SHALL NOT be parsed or validated by the session client.

#### Scenario: Valid code
- **WHEN** a code is accepted and the subsequent account query succeeds
- **THEN** the operation completes without returning cookies, session secrets or remote response objects
- **AND** session observers receive the confirmed authenticated state

#### Scenario: Rejected code
- **WHEN** the service rejects an invalid or expired code or rate-limits the request
- **THEN** an expected application exception preserves the service status and error type
- **AND** no authenticated event is published
- **AND** no request is automatically repeated

#### Scenario: Session creation succeeds but account validation fails
- **WHEN** session cookies have been received but the account query fails
- **THEN** confirmation does not report success or publish authentication
- **AND** a later explicit session load can reconcile the actual server state

### Requirement: Safe application boundary
The OTP contract SHALL expose only pure application/domain values and expected application exceptions. Remote error messages, OTP values and cookie credentials MUST NOT be logged or stored in application state by this infrastructure.

#### Scenario: Malformed response
- **WHEN** the code-request response has missing or incorrectly typed user identifier
- **THEN** parsing fails visibly rather than producing an empty challenge or successful authentication

#### Scenario: Transport failure
- **WHEN** a request times out or loses connectivity
- **THEN** the consumer receives the expected operation failure without remote message content
- **AND** infrastructure makes no claim that an uncertain request was not processed

### Requirement: Infrastructure-only migration boundary
The authentication adapter SHALL expose code request, confirmation and current-session logout through a single IAuthenticationRepository. The password contract MUST be removed without a parallel or legacy interface. Public authentication names MUST NOT encode the OTP mechanism.

#### Scenario: Password consumers have not been migrated
- **WHEN** a preserved password consumer calls a removed operation
- **THEN** its compilation incompatibility remains visible until migration
- **AND** no partial implementation, stub or fictitious success is introduced to hide it

#### Scenario: New infrastructure is registered
- **WHEN** the new OTP contract is resolved independently of any Authentication route
- **THEN** its production implementation is available
- **AND** no password authentication, registration, recovery or verification-link adapter is introduced
- **AND** no screen, Bloc, route or navigation behavior is changed by this delivery
