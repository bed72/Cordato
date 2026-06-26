## 1. Domain error

- [x] 1.1 Add `domain/errors/invalid_credentials_error.py` → `InvalidCredentialsError`, pt-BR message `"E-mail ou senha inválidos."`, naming neither the email nor the password (anti-enumeration). One concept per file.

## 2. Application command

- [x] 2.1 Add `application/data/sign_in_data.py` → `SignInData(email: str, password: str)` (raw input strings; the command, named after the use case).

## 3. Use case

- [x] 3.1 Add `application/use_cases/sign_in_use_case.py` → `SignInUseCase`, constructed with the `PersonRepositoryInterface` and `PasswordHasherInterface` ports (no new port).
- [x] 3.2 Define a module-level constant decoy Argon2 hash `str` (a real digest of an arbitrary throwaway secret) with an inline comment explaining it exists only to equalize timing on the not-found path.
- [x] 3.3 Build `EmailValueObject` and `PasswordValueObject` from the input inside a narrow try/except; on `InvalidEmailError`/`WeakPasswordError` re-raise `InvalidCredentialsError` (malformed input must be indistinguishable from a wrong credential).
- [x] 3.4 `await repository.find_active_by_email(email)`; sequential (the verify depends on the result) — no `asyncio.gather`.
- [x] 3.5 ALWAYS `await hasher.verify(password, person.password if person else DECOY_HASH)`; discard the decoy result. Authenticate only when a person was found AND verify returned `True`.
- [x] 3.6 On any failure (no person, or verify `False`, or the caught validation errors) raise `InvalidCredentialsError`; on success map the entity to `PersonData` via the existing `PersonDataMapper` and return it. Never log/echo the raw password.

## 4. Tests

- [x] 4.1 `tests/identity/domain/errors/test_invalid_credentials_error.py` — message is the generic pt-BR string and leaks no value.
- [x] 4.2 `tests/identity/application/use_cases/test_sign_in_use_case.py` — success returns `PersonData`; wrong password, unknown email, malformed email, weak/invalid password, and inactive account each raise `InvalidCredentialsError` and are mutually indistinguishable.
- [x] 4.3 Assert the not-found path still calls `verify` once (timing equalization) — e.g. a fake/spy hasher records the call against the decoy hash.
- [x] 4.4 `tests/identity/integrations/test_sign_in.py` — wire the in-memory `PersonRepository` + the real Argon2 `PasswordHasher`: register a person, then sign in successfully and with a wrong password. Reuse the existing fakes under `tests/identity/fakes/`.

## 5. Guard & quality gate

- [x] 5.1 Run `/trocado:guard` on the diff (async ports, dependency direction, naming, one-concept-per-file, pt-BR non-leaking error, no new lib names).
- [x] 5.2 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) green.
