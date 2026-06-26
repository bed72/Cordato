## Why

`sign_in` verifies a credential and returns `PersonData`, but it establishes **no session** — so there is
nothing to authenticate later requests with, and nothing to `sign_out` of. To make the `sign_in` /
`sign_out` family real, the system needs a session: something issued at sign-in, presented on each
authenticated request, and revoked at sign-out. The consuming front-end is a **Flutter mobile app** (no web
app planned for the product itself), so the session is an **opaque bearer token** (CSPRNG) stored in the
device's secure storage and sent in the `Authorization` header — not a cookie, not a JWT.

A storage-backed, server-side session is the right model here: it is **revocable** (a lost device or an
explicit sign-out invalidates it instantly), it fits the current in-memory transitional stage with real
domain substance, and — importantly — it is **client-agnostic**. That last point is now concrete, not
hypothetical: Google Play will require a **web** account-deletion path reachable without the app, so a
minimal web edge is coming. The same opaque `Session` will serve that web flow as cleanly as it serves the
app, with no redesign. A stateless JWT would buy nothing here and would forfeit revocation.

## What Changes

- **New `SessionEntity`** — `id`, `created_at`, `person_id`, an opaque CSPRNG `token` (distinct from the
  time-ordered `id`), `expires_at`, and `revoked_at` (null = live). Valid ⇔ `revoked_at is null` AND not yet
  expired. Born only via `SessionEntity.create(...)`.
- **`sign-in` now issues a session** (**BREAKING** to its read-model): on a successful verify it creates a
  `SessionEntity` and returns a new `SessionData { token, expires_at, person: PersonData }` instead of bare
  `PersonData`. The anti-enumeration and timing-equalization rules are unchanged; issuance happens only past
  the successful verify.
- **New `validate-session` use case** — takes a raw token, returns the authenticated `PersonData` when the
  session is valid (not expired, not revoked) and the person is still active; otherwise a single generic,
  non-leaking `InvalidSessionError` (pt-BR `"Sessão inválida."`). This is the per-request auth check the app
  hits on every authenticated request — and what makes a sign-out's effect observable.
- **New `sign-out` use case** — takes a raw token and revokes that session. **Idempotent and non-leaking**:
  signing out an unknown / expired / already-revoked token is a successful no-op, never an oracle.
- **New ports + adapters** — `SessionRepositoryInterface` (in-memory adapter) and `TokenGeneratorInterface`
  (CSPRNG gateway, `secrets.token_urlsafe`). Identity gets its own token generator; there is **no `shared/`**
  (the `pairing` context's token generator is mirrored, not imported).

One session **per sign-in** (multi-device by nature: phone + tablet each get their own). Revoking-all-devices
is out of scope (parking lot).

## Capabilities

### New Capabilities
- `validate-session`: validate an opaque session token and resolve it to the authenticated person, rejecting
  expired/revoked/unknown tokens with one generic, non-leaking error.
- `sign-out`: revoke a session by its token so it can no longer authenticate; idempotent and non-leaking.

### Modified Capabilities
- `sign-in`: on success, additionally issues a session and returns the opaque token + `expires_at` alongside
  the person (read-model changes from `PersonData` to `SessionData`). Anti-enumeration and timing rules
  unchanged.

## Impact

- **New code** (`features/identity`): `domain/entities/session_entity.py`,
  `domain/errors/invalid_session_error.py`, `application/data/session_data.py`,
  `application/mappers/session_data_mapper.py`, `application/interfaces/session_repository_interface.py`,
  `application/interfaces/token_generator_interface.py`,
  `application/use_cases/validate_session_use_case.py`,
  `application/use_cases/sign_out_use_case.py`, `infrastructure/repositories/session_repository.py`,
  `infrastructure/gateways/token_generator.py`.
- **Modified**: `sign_in_use_case.py` (issue a session, return `SessionData`); the existing `sign-in` spec
  gains a MODIFIED requirement.
- **Reused, unchanged**: `IdentifierProviderInterface` (uuid7 `id`), `ClockInterface` (`created_at` +
  `expires_at = now + TTL`), `PersonRepositoryInterface`, `PasswordHasherInterface`, `PersonData` /
  `PersonDataMapper`.
- **Forward-looking, not in this change**: the mandatory web account-deletion endpoint (it will ride this
  same `Session`; the web framework choice is deferred to that change), and "sign out all devices".
- **No ORM impact**: transitional stage — pure domain + application ports + in-memory adapters + a real
  CSPRNG gateway; no `Model`/`ModelMapper`.
- **Tests**: use-case tests for sign-in (now issuing a session), validate-session (valid / expired / revoked
  / unknown / inactive person), and sign-out (revokes; idempotent no-op); integration tests wiring the
  in-memory session repository + the real token generator through the full issue → validate → revoke →
  validate-fails arc.
