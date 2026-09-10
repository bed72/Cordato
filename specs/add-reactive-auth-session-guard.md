# Add Reactive Auth Session Guard

## Status

Proposed

## Objective

Keep the Flutter navigation state synchronized with the authoritative Supabase session throughout the app
lifecycle. A user whose session is removed, expires, or cannot be refreshed must not remain in an authenticated
route until a later request fails.

## Scope

- Represent the complete authentication session state required by routing, including restored authenticated,
  unauthenticated, loading, and recoverable restoration failure states.
- Observe Supabase authentication state changes for sign-in, sign-out, token refresh, refresh failure, and
  invalid/expired session outcomes relevant to the SDK.
- Guard authenticated routes reactively and redirect to the unauthenticated entry when authorization is lost.
- Preserve the existing Magic Link callback flow and prevent protected UI from flashing while session state is
  unresolved.
- Add unit and widget/route-level coverage for session transitions and subscription disposal.

## Non-goals

- Do not change the Magic Link provider, add passwords, reproduce the legacy identity context, or change user
  profile ownership.
- Do not add offline session support, background retries, crash reporting, or a new global state-management
  package.
- Do not expose access tokens, refresh tokens, or raw provider errors to widgets.

## Requirements

### Requirement: Routing consumes a complete session state
The routing boundary SHALL derive its state from the active Supabase session and its observed auth events rather
than only from the session that existed during application startup. It SHALL distinguish unresolved restoration
from an unauthenticated state.

#### Acceptance scenarios

- **WHEN** the application starts with a valid persisted session
- **THEN** the authenticated route tree SHALL become available after restoration completes

- **WHEN** the application starts without a session
- **THEN** the unauthenticated entry route SHALL become available without exposing protected content

- **WHEN** session restoration is still unresolved
- **THEN** the application SHALL display a neutral loading state and SHALL not briefly render protected content

### Requirement: Loss of authorization removes protected navigation
An observed Supabase sign-out, invalid session, or unrecoverable refresh outcome SHALL remove authenticated
routing immediately and direct the user to the unauthenticated entry. The transition SHALL replace protected
history so back navigation cannot reveal it.

#### Acceptance scenarios

- **WHEN** Supabase emits a sign-out after the user entered the dashboard
- **THEN** the application SHALL replace the authenticated route with the unauthenticated entry

- **WHEN** a persisted token cannot be refreshed and Supabase reports the session as invalid
- **THEN** the application SHALL remove authenticated navigation and show a safe re-authentication path

- **WHEN** the user presses back after authorization was removed
- **THEN** protected screens SHALL not be displayed from route history

### Requirement: Session transitions remain safe during asynchronous work
An auth state transition SHALL not allow an obsolete callback, delayed session restoration, or disposed listener to
restore a protected route after sign-out. Auth subscriptions and route-owned listeners SHALL be disposed with
their owners.

#### Acceptance scenarios

- **WHEN** a sign-out event arrives before an earlier restoration request completes
- **THEN** the stale restoration result SHALL not re-enter authenticated routing

- **WHEN** the session guard is disposed or replaced
- **THEN** its auth-state subscription SHALL be cancelled and later events SHALL not navigate through it

- **WHEN** a user signs in through the existing Magic Link callback
- **THEN** the active authenticated session SHALL enter the dashboard through the same guarded route boundary

### Requirement: Provider failures remain safe and diagnosable
Expected authorization loss SHALL result in a safe re-authentication experience. Unexpected session-observation
or configuration failures SHALL not leave the user indefinitely in a loading state or expose raw Supabase errors.

#### Acceptance scenarios

- **WHEN** a known expired or revoked session is observed
- **THEN** the application SHALL present the unauthenticated entry without a provider error message

- **WHEN** an unexpected session initialization failure occurs
- **THEN** the application SHALL present a recoverable error state or safe retry path and retain technical context
  outside user-facing text

## Dependencies

- Existing Supabase Auth and Magic Link configuration.
- A confirmed mapping from Supabase auth events to the Flutter SDK version in `pubspec.yaml`.

## Verification

- Unit-test session-state mapping and stale-event suppression.
- Test route behavior for startup with/without session, sign-in, sign-out, expired/invalid session, and disposal.
- Run the existing authentication and dashboard tests to confirm Magic Link behavior remains unchanged.
