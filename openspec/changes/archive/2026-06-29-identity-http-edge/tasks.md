## 1. Response DTOs and response mapper

- [x] 1.1 Create `identity/infrastructure/http/responses/person_response.py` — `PersonResponse` Pydantic DTO with `id`, `name`, `email` fields and OpenAPI `Field(description=, examples=)` + model-level example
- [x] 1.2 Create `identity/infrastructure/http/responses/session_response.py` — `SessionResponse` Pydantic DTO with `token`, `expires_at`, and nested `person: PersonResponse`; model-level example
- [x] 1.3 Create `identity/infrastructure/http/mappers/responses/session_response_mapper.py` — `SessionResponseMapper.to_response(data: SessionData) -> SessionResponse` (`@staticmethod`)

## 2. Request DTOs and request mappers

- [x] 2.1 Create `identity/infrastructure/http/requests/sign_up_request.py` — `SignUpRequest` Pydantic DTO with `email`, `password`, `name`; OpenAPI `Field(description=, examples=)` + model-level example
- [x] 2.2 Create `identity/infrastructure/http/requests/sign_in_request.py` — `SignInRequest` Pydantic DTO with `email`, `password`; OpenAPI `Field(description=, examples=)` + model-level example
- [x] 2.3 Create `identity/infrastructure/http/mappers/requests/sign_up_request_mapper.py` — `SignUpRequestMapper.to_data(request: SignUpRequest) -> SignUpData` (`@staticmethod`)
- [x] 2.4 Create `identity/infrastructure/http/mappers/requests/sign_in_request_mapper.py` — `SignInRequestMapper.to_data(request: SignInRequest) -> SignInData` (`@staticmethod`)
- [x] 2.5 Create `identity/infrastructure/http/mappers/requests/sign_out_request_mapper.py` — `SignOutRequestMapper.to_data(request: Request) -> SignOutData` (`@staticmethod`); extracts `Authorization: Bearer <token>` header, returns `SignOutData(token=token)` — empty string if header is absent or not Bearer-prefixed

## 3. Auth provider

- [x] 3.1 Create `identity/infrastructure/http/providers/current_person_provider.py` — async function `resolve_current_person(request: Request, validate_session: ValidateSessionUseCase) -> PersonData`; reads `Authorization: Bearer <token>` header; raises `InvalidSessionError` if header is absent or not Bearer-prefixed; delegates to `validate_session.execute(token)` and returns the `PersonData`

## 4. Identity error→status table

- [x] 4.1 Create `identity/infrastructure/http/errors/lookups/identity_status_error.py` — `IDENTITY_STATUS_ERROR: dict[type[Exception], int]` mapping `InvalidCredentialsError → 401`, `InvalidSessionError → 401`, `EmailAlreadyInUseError → 409`, `InvalidEmailError → 422`, `InvalidNameError → 422`, `WeakPasswordError → 422`

## 5. Authentication controller

- [x] 5.1 Create `identity/infrastructure/http/controllers/authentication_controller.py` — `AuthenticationController(Controller)` with `path = "/authentication"`:
  - `@post("/sign-up", status_code=201)` → declares `data: SignUpRequest`; maps → `SignUpData`; calls `SignUpUseCase`; maps → `SessionResponse`
  - `@post("/sign-in", status_code=200)` → declares `data: SignInRequest`; maps → `SignInData`; calls `SignInUseCase`; maps → `SessionResponse`
  - `@post("/sign-out", status_code=204)` → no body; reads Bearer via `SignOutRequestMapper`; calls `SignOutUseCase`; returns `None`

## 6. Identity feature factory

- [x] 6.1 Create `identity/main/identity_factory.py` — `register_identity() -> Router` returning a Litestar `Router(path="/", route_handlers=[AuthenticationController])` with scoped providers for all identity use cases, repositories (`PersonRepository`, `SessionRepository` as app-scoped singletons), gateways (`PasswordHasher`, `TokenGenerator`), and the identity error handlers built from `{**CORE_STATUS_ERROR, **IDENTITY_STATUS_ERROR}` scoped to the router

## 7. Composition root wiring

- [x] 7.1 Update `core/infrastructure/http/app.py`: import `register_identity` and `resolve_current_person`; add `register_identity()` to the `/v1` router's `route_handlers`; add `"current_person": Provide(resolve_current_person, sync_to_thread=False)` to the `/v1` router's `dependencies`; add an `Authentication` OpenAPI `Tag` to the config

## 8. Budgeting placeholder retirement

- [x] 8.1 Update `budgeting/infrastructure/http/mappers/requests/create_budget_request_mapper.py`: change `to_data(request: CreateBudgetRequest)` to `to_data(request: CreateBudgetRequest, person_id: str)` and replace the hardcoded `"person_id"` with the `person_id` parameter
- [x] 8.2 Update `budgeting/infrastructure/http/controllers/budget_controller.py` `create` handler: add `current_person: PersonData` (imported from `trocado.features.identity.application.data.person_data`) to the signature and pass `current_person.id` to `CreateBudgetRequestMapper.to_data`

## 9. Tests

- [x] 9.1 Create `tests/identity/integrations/test_authentication_http.py` — HTTP integration tests via Litestar `TestClient` against `build()`: sign-up 201, sign-in 200, sign-out 204, invalid credential 401, duplicate email 409, missing field 422, expired/unknown token on protected route 401
- [x] 9.2 Create `tests/identity/infrastructure/http/errors/lookups/test_identity_status_error.py` — unit test `IDENTITY_STATUS_ERROR` in plain Python (no server): verify each error class maps to its expected HTTP status
- [x] 9.3 Create `tests/identity/infrastructure/http/providers/test_current_person_provider.py` — unit test `resolve_current_person`: missing header → `InvalidSessionError`, non-Bearer header → `InvalidSessionError`, valid token → delegates to use case and returns `PersonData`
- [x] 9.4 Update `tests/budgeting/integrations/` — any test that relied on the `"person_id"` placeholder must sign in first (or inject a real `person_id` via the stubbed `current_person` provider) to verify the protected budget routes still work end-to-end
