## Why

Every feature already built assumes an authenticated person — per-person authorization, the "live session"
that `delete-account` re-confirms, the `person_id` each use case takes for granted. Yet nothing establishes
that identity: `register-person` (`sign_up`) creates the account and `delete-account` retires it, but the
miolo — proving "this credential belongs to this active person" (`sign_in`) — is missing. This change closes
the identity loop.

## What Changes

- Add a `SignInUseCase` to the `identity` context: given an email and a raw password, verify the credential
  against the active person's stored hash and return the existing `PersonData` read-model on success.
- Add a `SignInData(email: str, password: str)` command and an `InvalidCredentialsError` domain error.
- **Anti-enumeration is a first-class rule**: a malformed email, an unknown/inactive email, and a wrong
  password ALL collapse into the single generic `InvalidCredentialsError` (pt-BR `"E-mail ou senha
  inválidos."`). The use case never reveals which half failed.
- **Timing equalization**: the use case ALWAYS performs a password verify — even when no person is found it
  verifies against a constant decoy hash — so response time does not betray whether the email exists. This
  deliberately overrides the usual "cheap guard before expensive call" ordering.
- Reuses existing ports only — `PersonRepositoryInterface.find_active_by_email` and
  `PasswordHasherInterface.verify`. **No new port.** `InvalidCredentialsError` is distinct from
  `delete-account`'s `IncorrectPasswordError` (that one is post-auth and may be specific; `sign_in` is
  pre-auth and must stay generic).
- Adopts the `sign_in` / `sign_out` / `sign_up` vocabulary. This change delivers `sign_in` only; `sign_up`
  is the existing `register-person`, and `sign_out` (session/token discard) stays deferred with the web edge.

Out of scope (deferred, not skipped): any `Session` concept and token/JWT issuance — those live at the web
edge, behind the existing ports, once the transport is chosen.

## Capabilities

### New Capabilities
- `sign-in`: Verify a person's credentials (email + password) against their stored hash and return the
  authenticated person, with anti-enumeration guarantees (single generic error and equalized response timing).

### Modified Capabilities
<!-- None. No existing capability's requirements change; sign-in reuses register-person's ports without altering them. -->

## Impact

- **New code** (`features/identity`): `application/use_cases/sign_in_use_case.py` (`SignInUseCase`),
  `application/data/sign_in_data.py` (`SignInData`), `domain/errors/invalid_credentials_error.py`
  (`InvalidCredentialsError`).
- **Reused, unchanged**: `PersonRepositoryInterface.find_active_by_email`, `PasswordHasherInterface.verify`,
  `EmailValueObject`, `PasswordValueObject`, `PersonData` (+ its `PersonDataMapper`).
- **Decoy hash**: a constant, valid Argon2 hash string used only to equalize timing on the not-found path.
  Where it lives (a small gateway/constant in `identity/infrastructure` vs. injected) is settled in design.
- **No ORM impact**: transitional stage — pure domain + application ports + the existing in-memory adapter;
  no `Model`/`ModelMapper`.
- **Tests**: a use-case test (success, unknown email, wrong password, inactive account, malformed email) and
  an integration test wiring the in-memory repository + the real Argon2 hasher.
