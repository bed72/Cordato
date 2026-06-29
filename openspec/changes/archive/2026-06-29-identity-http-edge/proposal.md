## Why

The identity domain and application layer are fully implemented — `SignUpUseCase`, `SignInUseCase`,
`SignOutUseCase`, `ValidateSessionUseCase`, in-memory repositories, and all ports are wired and tested.
What is missing is the HTTP edge that exposes them: the authentication routes and the mechanism that
translates a Bearer token into a real `person_id` on every protected request. Until this lands, every
controller uses a hardcoded `"person_id"` placeholder, making per-person authorization impossible and
blocking every subsequent feature's delivery.

## What Changes

- New `AuthenticationController` at path `/authentication`, with three routes:
  - `POST /v1/authentication/sign-up` → 201, `SessionResponse`
  - `POST /v1/authentication/sign-in` → 200, `SessionResponse`
  - `POST /v1/authentication/sign-out` → 204, no body
- New `current_person` injectable provider (`resolve_current_person`) in
  `identity/infrastructure/http/providers/`, registered on the `/v1` router in the composition root.
  A handler declares `current_person: PersonData` to require auth; handlers that omit it (e.g.
  sign-up, sign-in) are public. The provider reads `Authorization: Bearer <token>`, calls
  `ValidateSessionUseCase`, and returns `PersonData` or raises `InvalidSessionError` (→ 401).
- `identity` feature wired into `app.py` alongside `budgeting`.
- `CreateBudgetRequestMapper` updated to accept `person_id: str` instead of the hardcoded placeholder;
  `BudgetController.create` declares `current_person: PersonData` and passes `current_person.id`.
- `identity` error→status table (`IDENTITY_STATUS_ERROR`) added, scoped to its own router.

## Capabilities

### New Capabilities

- `authentication-http-edge`: The HTTP surface for authentication — sign-up, sign-in, and sign-out
  routes, plus the `current_person` injectable provider that threads real identity into protected
  handlers via the `/v1` router's dependency scope.

### Modified Capabilities

- `http-api`: The Bearer token convention and the `current_person` provider pattern are new
  cross-cutting auth rules that extend the existing HTTP API conventions (versioning, DI scoping,
  error envelope). The spec must capture how auth fits into the layered DI model and what it means
  for a route to be "protected" vs. "public".

## Impact

- **New files**: `identity/infrastructure/http/` — controller, requests, responses, mappers,
  providers/, errors/lookups/; `identity/main/identity_factory.py`.
- **Modified files**: `core/infrastructure/http/app.py` (wire identity router, add `current_person`
  provider to `/v1`); `budgeting/infrastructure/http/mappers/requests/create_budget_request_mapper.py`
  (replace placeholder); `budgeting/infrastructure/http/controllers/budget_controller.py` (declare
  `current_person`).
- **Dependencies**: no new runtime dependency — Litestar's native DI handles provider injection;
  the existing `argon2-cffi` and `litestar` are sufficient.
- **Auth token transport**: `Authorization: Bearer <token>` header, matching the Flutter mobile
  client's secure-storage model.
