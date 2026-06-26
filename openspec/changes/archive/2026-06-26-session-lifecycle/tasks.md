## 1. Domain

- [x] 1.1 Add `domain/entities/session_entity.py` → `SessionEntity` (`id`, `created_at`, `person_id`, `token`, `expires_at`, `revoked_at`). Equality by `id`. `create(...)` factory (born live, `revoked_at=None`); a `revoke(now)` method that sets `revoked_at`; an `is_live(now)` helper (`revoked_at is None and expires_at > now`). Pure, no I/O.
- [x] 1.2 Add `domain/errors/invalid_session_error.py` → `InvalidSessionError`, pt-BR `"Sessão inválida."`, leaking nothing. One concept per file.
- [x] 1.3 Define `SESSION_TIME_TO_LIVE` as a named constant (`timedelta(days=30)`, spelled out — no "TTL" abbreviation) in the entity module, used by `create(...)` to derive `expires_at` (single source of truth).
- [x] 1.4 Add `domain/virtual_objects/authenticated_session_virtual_object.py` → `AuthenticatedSessionVirtualObject` holding `session: SessionEntity` + `person: PersonEntity`, exposing `token` / `expires_at` (delegating to the session) and `person`. A read-time composition so the data mapper takes ONE cohesive input (mirrors the couple views).

## 2. Application — ports & data

- [x] 2.1 Add `application/interfaces/session_repository_interface.py` → async ABC `SessionRepositoryInterface`: `create(session)`, `find_valid_by_token(token, now) -> SessionEntity | None` (adapter owns the live filter: not revoked, not expired), `revoke(session)`.
- [x] 2.2 Add `application/interfaces/token_generator_interface.py` → async ABC `TokenGeneratorInterface`: `generate() -> str`.
- [x] 2.3 Add `application/data/session_data.py` → `SessionData(token: str, expires_at: datetime, person: PersonData)`.
- [x] 2.4 Add `application/mappers/session_data_mapper.py` → `SessionDataMapper.to_data(authenticated_session)` (ONE arg: the `AuthenticatedSessionVirtualObject`) composing the existing `PersonDataMapper`.

## 3. Application — use cases

- [x] 3.1 Modify `application/use_cases/sign_in_use_case.py`: inject `SessionRepositoryInterface`, `TokenGeneratorInterface`, `IdentifierProviderInterface`, `ClockInterface`. Keep the existing guard + timing-equalization verify untouched; only **past a successful verify**, gather `id`/`created_at`/`token` (independent), compute `expires_at = created_at + SESSION_TIME_TO_LIVE`, create + persist the `SessionEntity`, wrap it with the person in an `AuthenticatedSessionVirtualObject`, and return `SessionData` via `SessionDataMapper` (was `PersonData`).
- [x] 3.2 Add `application/use_cases/validate_session_use_case.py` → `ValidateSessionUseCase`: `now = clock.now()`; `find_valid_by_token(token, now)`; if none → `InvalidSessionError`; else re-check the person is still active via `PersonRepositoryInterface.find_active_by_id(session.person_id)` (None → `InvalidSessionError`); return `PersonData`.
- [x] 3.3 Add `application/use_cases/sign_out_use_case.py` → `SignOutUseCase`: `now = clock.now()`; `find_valid_by_token(token, now)`; if none → return (idempotent no-op, no error); else `session.revoke(now)` + persist via `revoke(session)`.

## 4. Infrastructure (in-memory + CSPRNG gateway)

- [x] 4.1 Add `infrastructure/repositories/session_repository.py` → in-memory `SessionRepository` implementing the port; `find_valid_by_token` returns only live sessions (token match, `revoked_at is None`, `expires_at > now`); `revoke` persists the revoked entity.
- [x] 4.2 Add `infrastructure/gateways/token_generator.py` → `TokenGenerator` using `secrets.token_urlsafe(...)` (mirror the pairing context's generator; no import across contexts, no lib name in the class).

## 5. Tests

- [x] 5.1 `tests/identity/domain/entities/test_session_entity.py` — factory births live; `revoke` sets `revoked_at`; `is_live` across revoked/expired/live; equality by id.
- [x] 5.2 `tests/identity/domain/errors/test_invalid_session_error.py` — generic pt-BR message, no leak.
- [x] 5.2b `tests/identity/domain/virtual_objects/test_authenticated_session_virtual_object.py` — exposes the session's token/expires_at and the held person.
- [x] 5.3 Update `tests/identity/application/use_cases/test_sign_in_use_case.py` — success now returns `SessionData` (token present, `expires_at = created_at + SESSION_TIME_TO_LIVE`, nested `PersonData`); a session row is persisted; failures still raise `InvalidCredentialsError` and issue **no** session; the decoy/timing assertions stay green. Add fakes: `FakeSessionRepository`, `FakeTokenGenerator` under `tests/identity/fakes/`.
- [x] 5.4 `tests/identity/application/use_cases/test_validate_session_use_case.py` — live token → `PersonData`; unknown / expired / revoked / inactive-person each raise `InvalidSessionError`, mutually indistinguishable.
- [x] 5.5 `tests/identity/application/use_cases/test_sign_out_use_case.py` — live token is revoked (then a follow-up validate fails); unknown / already-revoked / expired token is a silent no-op (no error, nothing changed); a second device's session stays live.
- [x] 5.6 `tests/identity/integrations/test_session_lifecycle_integration.py` — wire in-memory `PersonRepository` + `SessionRepository` + real `PasswordHasher` + real `TokenGenerator` + `Clock`/`IdentifierProvider`: sign up → sign in (get token) → validate (ok) → sign out → validate (fails). Reuse existing identity fakes where applicable.

## 6. Guard & quality gate

- [x] 6.1 Run `/trocado:guard` on the diff (async ports, dependency direction, naming, one-concept-per-file, derive-don't-store for session validity, pt-BR non-leaking errors, gateways bucket, determinism ports, no lib names, test layout).
- [x] 6.2 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) green.
