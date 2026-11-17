# Authentication Session Logout Delta

## REMOVED Requirements

### Requirement: Layered logout execution
**Reason**: The disposable command and previous repository chain are historical and incompatible with the current application architecture.
**Migration**: Provide current-session logout through the new OTP application contract; migrate presentation consumers separately.

### Requirement: Supabase logout delegation
**Reason**: The previous backend is not part of the Flutter application.
**Migration**: Revoke the current Appwrite session using cookie-authenticated REST.

### Requirement: Reactive logout completion
**Reason**: The historical provider-specific authentication observer no longer exists.
**Migration**: Publish confirmed logout through the shared cookie-session observation mechanism without changing navigation in this delivery.

### Requirement: Logout dependency boundaries
**Reason**: Historical domain contracts and backend-specific module ownership have been superseded.
**Migration**: Use pure application contracts and root-available infrastructure; defer Settings integration to the presentation migration.

## ADDED Requirements

### Requirement: Current-session revocation
The application SHALL revoke only the current Appwrite session before removing its local credentials and reporting successful logout. It MUST NOT revoke all user sessions or claim durable local cleanup before cookie persistence completes.

#### Scenario: Successful logout
- **WHEN** the current-session deletion succeeds and local cleanup completes
- **THEN** logout completes and observers receive unauthenticated
- **AND** other devices' sessions are not targeted

#### Scenario: Session already absent
- **WHEN** deletion explicitly returns 401 because no current authenticated session exists
- **THEN** local session cookies are removed and logout completes as unauthenticated after cleanup succeeds

### Requirement: Logout failure preserves confirmed state
An unconfirmed remote logout SHALL fail without deliberately clearing local credentials or publishing unauthenticated. A local cleanup failure after confirmed remote revocation SHALL remain a failure and permit an explicit retry.

#### Scenario: Remote revocation fails
- **WHEN** deletion times out or returns a failure other than confirmed absence of session
- **THEN** the expected application failure reaches the caller and no unauthenticated event is emitted
- **AND** no automatic retry occurs
- **AND** the caller is not promised that the remote session remains valid after an uncertain response

#### Scenario: Cleanup fails after revocation
- **WHEN** remote revocation succeeds but local cookie deletion fails
- **THEN** logout does not report full success or publish completed local logout
- **AND** an explicit retry can reconcile a remotely absent session and finish cleanup

### Requirement: Independent logout infrastructure
The logout operation SHALL be available through a pure application contract outside route scopes. It MUST NOT navigate, access presentation state or require visiting Authentication first.

#### Scenario: Isolated dependency resolution
- **WHEN** the OTP authentication contract is resolved in root composition without activating Authentication routes
- **THEN** logout resolves with the same shared session infrastructure used by restoration
- **AND** no Settings, screen, Bloc or navigation change is required to verify it
