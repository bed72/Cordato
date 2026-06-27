## 1. Domain

- [x] 1.1 In `domain/entities/person_entity.py`, replace `update_account(self, *, name, email)` with two
  narrow transitions:
  - `update_name(self, name: NameValueObject) -> None` — overwrite `name` only.
  - `update_email(self, email: EmailValueObject) -> None` — overwrite `email` only.
  Each leaves `id`/`created_at`/`status`/`password` and the *other* editable field untouched. Document them
  as sanctioned account mutations alongside `create` (birth), `update_password` (rotate), and `delete`
  (retire). Remove `update_account`.

## 2. Application — update-name (rename of update-account, name only)

- [x] 2.1 Rename `application/data/update_account_data.py` → `update_name_data.py`: `UpdateNameData` —
  frozen, slotted dataclass with `requester_id: str` and `name: str` (drop `email`).
- [x] 2.2 Rename `application/use_cases/update_account_use_case.py` → `update_name_use_case.py`:
  `UpdateNameUseCase`, depending only on `PersonRepositoryInterface`. Flow: build `NameValueObject(data.name)`
  (cheap, pure → `InvalidNameError`); `person = await find_active_by_id(data.requester_id)`; if `None` raise
  `InvalidSessionError`; `person.update_name(name)`; `await repository.update(person)`; return
  `PersonDataMapper.to_data(person)`. No email lookup, no uniqueness check, no password, no session purge.

## 3. Application — update-email (new, credential-sensitive)

- [x] 3.1 Add `application/data/update_email_data.py`: `UpdateEmailData` — frozen, slotted dataclass:
  `requester_id: str`, `current_session_token: str`, `current_password: PasswordValueObject` (policy-checked
  at construction, like `UpdatePasswordData`/`DeleteAccountData`), `new_email: str` (raw; the
  `EmailValueObject` is built in the use case).
- [x] 3.2 Add `application/use_cases/update_email_use_case.py`: `UpdateEmailUseCase`, depending on
  `PasswordHasherInterface`, `PersonRepositoryInterface`, `SessionRepositoryInterface`. Flow:
  1. `email = EmailValueObject(data.new_email)` — cheap, pure (`InvalidEmailError` before any I/O).
  2. `person, holder = await asyncio.gather(person_repository.find_active_by_id(data.requester_id),
     person_repository.find_active_by_email(email))`.
  3. Identity guard: `if person is None or not await hasher.verify(data.current_password, person.password):
     raise IncorrectPasswordError()` (the two causes fail identically — no oracle; `verify` runs after the
     reads and gates everything below, so it is awaited sequentially, never gathered).
  4. Uniqueness: `if holder is not None and holder.id != person.id: raise EmailAlreadyInUseError()` (self
     excluded; the holder verdict is consulted only past the identity guard).
  5. `person.update_email(email)`; then `await asyncio.gather(person_repository.update(person),
     session_repository.purge_for_person_except(person.id, data.current_session_token))`.
  6. `return PersonDataMapper.to_data(person)`.

## 4. Infrastructure

- [x] 4.1 No new code. Confirm the in-memory `PersonRepository`
  (`find_active_by_id`/`find_active_by_email`/`update`) and `SessionRepository.purge_for_person_except`
  (added by `update-password`) already satisfy both use cases.

## 5. Tests

- [x] 5.1 `tests/identity/domain/entities/test_person_entity.py` (edit): replace the `update_account` test
  with two tests — `update_name` overwrites only `name` (email/password/id/created_at/status preserved); and
  `update_email` overwrites only `email` (name/password/id/created_at/status preserved).
- [x] 5.2 Rename `tests/identity/application/use_cases/test_update_account_use_case.py` →
  `test_update_name_use_case.py`, trimmed to name-only: happy path returns `PersonData` with the new name and
  unchanged email/status/id/created_at; blank name → `InvalidNameError`; unresolved requester →
  `InvalidSessionError`; assert email/password/sessions untouched.
- [x] 5.3 Add `tests/identity/application/use_cases/test_update_email_use_case.py`: happy path returns
  `PersonData` with the new (normalized) email and swaps it; wrong current password → `IncorrectPasswordError`
  and nothing changes (assert `update`/`purge_for_person_except` never called, e.g. via spy fakes); unresolved
  requester → the *same* `IncorrectPasswordError` (indistinguishable); malformed email → `InvalidEmailError`
  at `EmailValueObject` construction, before any repository/hasher call; email held by another active person →
  `EmailAlreadyInUseError` (no address echoed) and nothing changes; re-saving the person's own email is
  allowed; on success every *other* session of the person is purged while `current_session_token` survives,
  and another person's sessions are untouched.
- [x] 5.4 Rename `tests/identity/integrations/test_update_account_integration.py` →
  `test_update_name_integration.py`: wire `UpdateNameUseCase` with the real in-memory `PersonRepository`;
  assert the name changes and email/credentials are untouched.
- [x] 5.5 Add `tests/identity/integrations/test_update_email_integration.py`: wire `UpdateEmailUseCase` with
  the real in-memory `PersonRepository`, `SessionRepository`, and the real Argon2 `PasswordHasher`; seed a
  person (hashed) plus several live sessions including the acting one; assert after a successful change that
  signing in with the new email + password succeeds and with the old email fails; that `find_valid_by_token`
  resolves the kept token but not the other (pre-change) tokens; and that budgets/expenses/pairs are untouched.

## 6. Quality gate

- [x] 6.1 Run `/trocado:guard` on the diff and resolve any findings (watch the BREAKING removal of
  `update-account`: no lingering imports of `UpdateAccountUseCase`/`UpdateAccountData`/`update_account`).
- [x] 6.2 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) until green.
