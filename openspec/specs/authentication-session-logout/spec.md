# authentication-session-logout Specification

> A infraestrutura atual revoga a sessão Appwrite por REST autenticado com cookies,
> usando contratos puros de aplicação e coordenação compartilhada de sessão.
> Supabase, commands e observação de token no storage são mecanismos históricos.
> Esta spec não declara migração das telas, integração de Settings ou homologação
> remota. Consulte [a referência atual](../../README.md).

## Purpose

Define current-session Appwrite logout through shared cookie-session infrastructure, preserving confirmed state on failures without changing presentation or navigation.

## Requirements

### Requirement: Current-session revocation
The application SHALL revoke only the current Appwrite session and await transport response handling before reporting logout. It MUST NOT revoke all user sessions or promise additional local cookie cleanup beyond the server's Set-Cookie response.

#### Scenario: Successful logout
- **WHEN** the current-session deletion succeeds and transport cookie handling completes
- **THEN** logout completes and observers receive unauthenticated
- **AND** other devices' sessions are not targeted

#### Scenario: Session already absent
- **WHEN** deletion explicitly returns 401 because no current authenticated session exists
- **THEN** logout completes as unauthenticated after transport response handling
- **AND** no manual cookie deletion is performed

### Requirement: Logout failure preserves confirmed state
An unconfirmed remote logout SHALL fail without deliberately clearing local credentials or publishing unauthenticated. Cookie handling failures SHALL remain transport failures; the session client MUST NOT add cleanup recovery state or automatic retries.

#### Scenario: Remote revocation fails
- **WHEN** deletion times out or returns a failure other than confirmed absence of session
- **THEN** the expected application failure reaches the caller and no unauthenticated event is emitted
- **AND** no automatic retry occurs
- **AND** the caller is not promised that the remote session remains valid after an uncertain response

#### Scenario: Cookie persistence fails after revocation
- **WHEN** remote revocation succeeds but CookieManager fails to persist response cookies
- **THEN** logout fails without publishing unauthenticated
- **AND** no extra local cleanup or rollback is claimed

#### Scenario: No cookie expiry in response
- **WHEN** remote revocation succeeds without cookie expiry headers
- **THEN** logout publishes unauthenticated but makes no claim that cookies were removed locally

### Requirement: Independent logout infrastructure
The logout operation SHALL be available through a pure application contract outside route scopes. It MUST NOT navigate, access presentation state or require visiting Authentication first.

#### Scenario: Isolated dependency resolution
- **WHEN** the OTP authentication contract is resolved in root composition without activating Authentication routes
- **THEN** logout resolves with the same shared session infrastructure used by restoration
- **AND** no Settings, screen, Bloc or navigation change is required to verify it
