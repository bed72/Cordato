## 1. Domain

- [x] 1.1 Add `PersonEntity.change_password(self, new_hash: str) -> None` to
  `domain/entities/person_entity.py`: overwrite `password` with the already-computed `new_hash` and leave
  `id`/`created_at`/`status`/`name`/`email` untouched. Document it as a sanctioned credential transition,
  alongside `create` (birth), `update_account` (edit), and `delete` (retire). The argument is a finished
  hash (plain `str`, no value object — a hash carries no invariant); hashing is the gateway's job.

## 2. Application

- [x] 2.1 Add `ChangePasswordData` in `application/data/change_password_data.py` — frozen, slotted
  dataclass: `requester_id: str`, `current_session_token: str`, `current_password: PasswordValueObject`,
  `new_password: PasswordValueObject` (both already policy-validated by construction, mirroring
  `DeleteAccountData.password` and the hasher port, which speaks `PasswordValueObject`).
- [x] 2.2 Add `async def purge_for_person_except(self, person_id: str, keep_token: str) -> None` to
  `SessionRepositoryInterface` (`application/interfaces/session_repository_interface.py`) — remove **all**
  of the person's sessions whose `token != keep_token`, irrespective of validity (live/revoked/expired
  alike); document it as the all-except-one sibling of `purge_for_person`, idempotent, and that the kept
  session (the acting one) survives.
- [x] 2.3 Add `ChangePasswordUseCase` in `application/use_cases/change_password_use_case.py`, depending on
  `PasswordHasherInterface`, `PersonRepositoryInterface`, and `SessionRepositoryInterface`. Flow:
  both `PasswordValueObject`s are built by the *caller* (the data already carries them), so the use case
  starts at the identity guard — `person = await person_repository.find_active_by_id(
  data.requester_id)`; raise `IncorrectPasswordError` if `person is None or not await hasher.verify(
  data.current_password, person.password)` (the two causes fail identically — no oracle). Only past the
  guard: `new_hash = await hasher.hash(data.new_password)`; `person.change_password(new_hash)`; then
  `await asyncio.gather(person_repository.update(person), session_repository.purge_for_person_except(
  person.id, data.current_session_token))`. Returns `None`. Keep the verify→hash ordering sequential (real
  data dependency: never hash before the guard passes).

## 3. Infrastructure

- [x] 3.1 Implement `purge_for_person_except` in the in-memory `SessionRepository`
  (`infrastructure/repositories/session_repository.py`) — rebuild `self._sessions` keeping only sessions
  where `session.person_id != person_id or session.token == keep_token` (drop the person's other sessions,
  keep everyone else's and the acting one).

## 4. Tests

- [x] 4.1 `tests/identity/domain/entities/test_person_entity.py` (extend): `change_password` overwrites
  `password` with the given hash and preserves `id`/`created_at`/`status`/`name`/`email`.
- [x] 4.2 Extend the identity `FakeSessionRepository` (`tests/identity/fakes/fake_session_repository.py`)
  with `purge_for_person_except` mirroring the real adapter's keep-rule.
- [x] 4.3 `tests/identity/application/use_cases/test_change_password_use_case.py`: happy path returns `None`,
  swaps the stored hash to the hash of the new password, and preserves name/email/status/id/created_at;
  wrong current password raises `IncorrectPasswordError` and changes nothing (hasher.hash never called —
  assert via a fake/spy hasher); unknown/non-active requester raises the *same* `IncorrectPasswordError`
  (indistinguishable); a too-short new password raises `WeakPasswordError` at `PasswordValueObject`
  construction (before any repository/hasher call); on success every *other* session of the person is
  purged while the session matching `current_session_token` survives; another person's sessions are
  untouched.
- [x] 4.4 `tests/identity/integrations/test_change_password_integration.py`: wire `ChangePasswordUseCase`
  with the real in-memory `PersonRepository`, `SessionRepository`, and the real Argon2
  `PasswordHasher`; seed a person (hashed) and several live sessions including the acting one; assert after
  the change that `sign-in`/verify succeeds with the new password and fails with the old; that
  `find_valid_by_token` resolves the kept token but not the other (pre-rotation) tokens; and that budgets
  and expenses are untouched (no eraser/dissolver is wired).

## 5. Quality gate

- [x] 5.1 Run `/trocado:guard` on the diff and resolve any findings.
- [x] 5.2 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) until green.
