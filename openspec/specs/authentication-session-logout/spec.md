# authentication-session-logout Specification

## Purpose
Define the layered, reactive Supabase logout flow shared by authenticated features.

## Requirements

### Requirement: Layered logout execution
The authenticated logout flow SHALL execute through a disposable presentation command that consumes the existing `IAuthenticationRepository`, which SHALL continue delegating through `AuthenticationDataSource` to `SupabaseAuthenticationClient` without duplicating authentication infrastructure in Settings.

#### Scenario: Successful command execution
- **WHEN** `LogoutCommand.signOut` is executed and `IAuthenticationRepository.signOut` returns `Right`
- **THEN** the repository is invoked exactly once
- **THEN** the command completes successfully

#### Scenario: Repository failure reaches the command
- **WHEN** `LogoutCommand.signOut` is executed and `IAuthenticationRepository.signOut` returns `Left(LogoutFailure)`
- **THEN** the repository is invoked exactly once
- **THEN** the command exposes that `LogoutFailure` as its error

#### Scenario: Command lifecycle ends
- **WHEN** the owner of the logout command is disposed
- **THEN** the underlying observable command is disposed

### Requirement: Supabase logout delegation
The existing authentication repository, data source, and client SHALL translate a logout request into one `Supabase Auth.signOut` call and SHALL preserve the typed failure boundary between infrastructure and presentation.

#### Scenario: Supabase accepts sign-out
- **WHEN** `Supabase Auth.signOut` completes successfully
- **THEN** `SupabaseAuthenticationClient.signOut` returns success
- **THEN** `AuthenticationDataSource.signOut` returns the client result
- **THEN** `AuthenticationRepository.signOut` returns `Right`

#### Scenario: Supabase rejects sign-out
- **WHEN** `Supabase Auth.signOut` throws
- **THEN** `SupabaseAuthenticationClient.signOut` returns failure without exposing the SDK exception
- **THEN** `AuthenticationDataSource.signOut` returns the client result
- **THEN** `AuthenticationRepository.signOut` returns `Left(LogoutFailure)`

### Requirement: Reactive logout completion
A successful Supabase sign-out SHALL complete through the global authentication-state observer, which SHALL map `signedOut` to an unauthenticated session and delegate navigation to `SessionGuardWidget` rather than Settings.

#### Scenario: Signed-out event is observed
- **WHEN** Supabase emits `AuthChangeEvent.signedOut` after the logout command succeeds
- **THEN** the global session state becomes unauthenticated
- **THEN** `SessionGuardWidget` delegates navigation to welcome
- **THEN** Settings does not invoke the router directly

#### Scenario: Logout does not complete
- **WHEN** the logout command fails and no `signedOut` event is emitted
- **THEN** the authenticated session state is not changed by Settings
- **THEN** Settings remains available for a retry

### Requirement: Logout dependency boundaries
The Settings logout integration MUST depend on Authentication only through its domain repository contract and MUST NOT access Supabase, authentication data sources, authentication clients, storage, or global routing directly. The Authentication dependency chain SHALL be registered in the root-owned private `_supabaseModule` so Settings can resolve it without activating an Authentication route.

#### Scenario: Implementing the integration
- **WHEN** the logout command, Settings module, screen, mixin, and widgets are created or updated
- **THEN** the Settings logout command is the only runtime component in Settings that imports `IAuthenticationRepository`
- **THEN** preview fakes may implement Authentication contracts only from its domain layer
- **THEN** no Settings presentation file imports Authentication data or infrastructure
- **THEN** no Settings presentation file imports `supabase_flutter`, storage, or a global router

#### Scenario: Opening Settings without an active Authentication route
- **WHEN** the application enters the feature-scoped Settings route
- **THEN** `LogoutCommand` resolves the root-owned `IAuthenticationRepository`
- **THEN** Authentication presentation commands and routes remain feature-scoped
