## Context

The identity domain and application layer are complete: `PersonEntity`, `SessionEntity`, all use cases
(`SignUpUseCase`, `SignInUseCase`, `SignOutUseCase`, `ValidateSessionUseCase`, `DeleteAccountUseCase`,
and the profile-update family), in-memory repositories (`PersonRepository`, `SessionRepository`), and
gateways (`PasswordHasher`, `TokenGenerator`) are implemented and tested. The HTTP edge for the
`budgeting` feature is already live on Litestar, establishing the conventions this change follows
(layered DI, unified error envelope, feature-scoped router, `/v1` prefix, `data`-bound body).

The only missing pieces are:
1. The `AuthenticationController` and its supporting HTTP layer (DTOs, mappers, error table).
2. The `current_person` provider that threads real identity into every protected handler.
3. The composition-root and budgeting wiring that retires the `"person_id"` placeholder.

## Goals / Non-Goals

**Goals:**
- Expose `sign-up`, `sign-in`, and `sign-out` over HTTP under `/v1/authentication/`.
- Provide a `current_person: PersonData` injectable dependency on the `/v1` router so protected
  handlers receive a real `PersonData` without coupling controllers to auth internals.
- Retire the hardcoded `"person_id"` placeholder in `budgeting`.
- Wire the `identity` feature into `app.py`.

**Non-Goals:**
- Exposing other identity use cases over HTTP (profile updates, delete-account, invite flows) — those
  are separate changes.
- Token refresh, multi-device management, or session listing.
- Real transport security (TLS) — that is an infrastructure / deployment concern.

## Decisions

### D1 — Bearer token over `Authorization` header (not cookie)

**Chosen**: `Authorization: Bearer <token>` on every authenticated request.

**Rationale**: The primary client is a Flutter mobile app. Mobile apps use secure platform storage
(Keychain / Keystore) and set the header explicitly — a pattern the existing `SessionData` comment
already assumes. HTTP-only cookies require a browser and same-origin context that do not apply here.

**Alternative considered**: Cookie with `HttpOnly` + `SameSite=Strict`. Appropriate for a browser
frontend, but not the current client. Can be added later as a second delivery mechanism if a web
frontend is built.

### D2 — `current_person` as a Litestar DI provider, not middleware

**Chosen**: A named provider `resolve_current_person` registered at the `/v1` router scope.

```
Router("/v1", …,
    dependencies={"current_person": Provide(resolve_current_person, sync_to_thread=False)}
)
```

Handlers that need the caller's identity declare `current_person: NamedDependency[PersonData]`;
handlers that do not (sign-up, sign-in, sign-out) simply omit the parameter. Litestar resolves
providers lazily — the function never runs for handlers that do not request it.

**Rationale**:
- Mirrors exactly how `clock` and `identifier` are already wired — consistent mental model.
- Fully typed: `mypy --strict` verifies the `PersonData` parameter at every protected handler.
- Test-isolated: `build()` returns a fresh app; replacing the provider in a test produces a
  fully isolated auth-stubbed application.
- No middleware magic, no ASGI scope mutation, no separate container.

**Alternative considered**: Litestar `Guard`. Guards run before the handler and can raise, but they
do not produce a value — the handler would still need a second mechanism to obtain the `PersonData`.
Using a DI provider achieves both auth and identity delivery in one step.

**Alternative considered**: Global middleware. Runs unconditionally on every request, including
sign-up and sign-in (which must be public), requiring opt-out logic. Also needs workarounds to
access Litestar's DI container from middleware scope.

### D3 — Provider defined in `identity/infrastructure/http/`, registered in composition root

**Chosen**: `resolve_current_person` lives in
`identity/infrastructure/http/providers/current_person_provider.py`. `app.py` imports it to wire
it onto the `/v1` router, exactly as it imports each feature's factory.

**Rationale**: Auth resolution is identity's responsibility. The composition root is the one place
allowed to know every module — importing one provider function from identity's HTTP layer is
consistent with importing `register_identity()` from its factory. No other feature imports identity
internals.

### D4 — `sign-out` reads the Bearer header directly (no `current_person`)

**Chosen**: `SignOutController.sign_out` does NOT declare `current_person`. It reads
`Authorization: Bearer <token>` directly and passes the raw token to `SignOutUseCase`.

**Rationale**: `SignOutUseCase` is idempotent — an unknown, expired, or already-revoked token is
a silent no-op, never an error. Routing sign-out through `current_person` would reject an already-
expired token with 401, preventing clients from cleaning up stale credentials. The raw token is all
the use case needs; no `PersonData` is required and no auth check should block the revocation.

### D5 — HTTP status codes for authentication routes

| Route | Success status | Rationale |
|---|---|---|
| `POST /authentication/sign-up` | **201** | Creates a new person (a new resource). |
| `POST /authentication/sign-in` | **200** | Signs in to an existing session. Creating a session is a side-effect of a credential check, not the primary action. |
| `POST /authentication/sign-out` | **204** | No content returned; idempotent. |

### D6 — `identity` error→status table entries

| Error | HTTP status | Code |
|---|---|---|
| `InvalidCredentialsError` | 401 | `invalid-credentials` |
| `InvalidSessionError` | 401 | `invalid-session` |
| `EmailAlreadyInUseError` | 409 | `email-already-in-use` |
| `InvalidEmailError` | 422 | `invalid-email` |
| `InvalidNameError` | 422 | `invalid-name` |
| `WeakPasswordError` | 422 | `weak-password` |

`InvalidCredentialsError` and `InvalidSessionError` both map to **401** (not 403) because in both
cases the request lacks valid proof of identity — it is an authentication failure, not a permission
failure on a known identity.

## Risks / Trade-offs

- **Placeholder retirement breaks budgeting tests that relied on the fixed string.** → Any test that
  asserted `person_id == "person_id"` must be updated to pass a real `person_id`. Acceptable cost;
  the placeholder was always transitional.

- **In-memory session repository loses state on restart.** → Known and accepted at this build stage.
  The ORM-backed adapter slots in later without touching domain or application. Until then, sign-in
  again on restart.

- **`resolve_current_person` is a top-level async function, not a class.** → It holds no state and
  has no collaborators beyond what Litestar injects; a `@staticmethod`-equivalent free function is the
  correct shape (same "earn its existence" rule applied to providers).

## Open Questions

_None — all decisions above are settled for this change._
