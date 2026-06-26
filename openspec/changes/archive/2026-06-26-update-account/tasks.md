## 1. Domain

- [x] 1.1 Add `PersonEntity.update_account(*, name: NameValueObject, email: EmailValueObject) -> None`
  to `domain/entities/person_entity.py`: overwrite `name` and `email` in place and leave
  `id`/`created_at`/`status`/`password` untouched. Document it as the only sanctioned account mutation,
  alongside `create` and `delete`.

## 2. Application

- [x] 2.1 Add `UpdateAccountData` in `application/data/update_account_data.py` — frozen, slotted
  dataclass: `requester_id: str`, `name: str`, `email: str` (raw values straight from the caller).
- [x] 2.2 Add `async def update(self, person: PersonEntity) -> None` to `PersonRepositoryInterface`
  (`application/interfaces/person_repository_interface.py`) — persist a mutated *active* person;
  document it as distinct from `create` (introduce) and `delete` (persist retired state).
- [x] 2.3 Add `UpdateAccountUseCase` in `application/use_cases/update_account_use_case.py`, depending
  only on `PersonRepositoryInterface`: construct `NameValueObject(data.name)` and
  `EmailValueObject(data.email)` first (cheap guard); `asyncio.gather` `find_active_by_id(requester_id)`
  and `find_active_by_email(email)`; raise `InvalidSessionError` if the person is `None`; raise
  `EmailAlreadyInUseError` if the email holder is not `None` and its `id` differs from the person's;
  call `person.update_account(name=..., email=...)`; `await repository.update(person)`; return
  `PersonDataMapper.to_data(person)`.

## 3. Infrastructure

- [x] 3.1 Implement `update` in the in-memory `PersonRepository`
  (`infrastructure/repositories/person_repository.py`) — `self._people[person.id] = person`.

## 4. Tests

- [x] 4.1 `tests/identity/domain/entities/test_person_entity.py` (extend): `update_account` overwrites
  name and email and preserves id/created_at/status/password.
- [x] 4.2 `tests/identity/application/use_cases/test_update_account_use_case.py`: happy path returns
  updated `PersonData` (same id/created_at/status, no password field); name-only change re-submitting
  own email is accepted; email change to a free email succeeds; email held by another active person
  raises `EmailAlreadyInUseError`; re-saving own email does not self-collide; malformed email raises
  `InvalidEmailError`; blank/whitespace name raises `InvalidNameError`; unknown/non-active requester
  raises `InvalidSessionError`.
- [x] 4.3 Extend the identity `FakePersonRepository` (under `tests/identity/fakes/`) with `update` if it
  does not already inherit a usable implementation.
- [x] 4.4 `tests/identity/integrations/test_update_account_integration.py`: wire `UpdateAccountUseCase`
  with the real in-memory `PersonRepository`; assert an email change is reflected by
  `find_active_by_email` for the new address and the old address reads as available; assert budgets and
  expenses are untouched (no eraser/dissolver is even wired).

## 5. Quality gate

- [x] 5.1 Run `/trocado:guard` on the diff and resolve any findings.
- [x] 5.2 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) until green.
