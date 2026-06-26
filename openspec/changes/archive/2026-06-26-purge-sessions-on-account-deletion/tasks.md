## 1. Application port

- [x] 1.1 Add `async def purge_for_person(self, person_id: str) -> None` to
  `SessionRepositoryInterface` (`src/trocado/features/identity/application/interfaces/session_repository_interface.py`),
  with a docstring stating it removes **all** of the person's sessions regardless of validity and is
  **idempotent** (a no-op when the person has none).

## 2. Use case

- [x] 2.1 Inject `SessionRepositoryInterface` into `DeleteAccountUseCase`
  (`src/trocado/features/identity/application/use_cases/delete_account_use_case.py`) as a new constructor
  dependency.
- [x] 2.2 Add `self._session_repository.purge_for_person(person.id)` to the post-guard `asyncio.gather`
  alongside the existing four effects; keep the purge strictly **after** the password guard.
- [x] 2.3 Update the use-case docstring to name session purge as the fifth independent cascade effect.

## 3. Infrastructure (in-memory adapter)

- [x] 3.1 Implement `purge_for_person` in the in-memory `SessionRepository`
  (`src/trocado/features/identity/infrastructure/repositories/session_repository.py`): drop every stored
  session whose `person_id` matches; no error when there are none.

## 4. Composition / wiring

- [x] 4.1 Update wherever `DeleteAccountUseCase` is constructed (composition root / integration wiring) to
  pass the session repository.

## 5. Tests

- [x] 5.1 Add `purge_for_person` to the `FakeSessionRepository`
  (`tests/identity/fakes/fake_session_repository.py`) so it still satisfies the port.
- [x] 5.2 In `tests/identity/integrations/test_delete_account_integration.py`: assert that after a successful
  deletion, a session issued beforehand no longer resolves (`find_valid_by_token` returns `None`).
- [x] 5.3 Add a scenario where the requester is in a live pair: only the requester's sessions are purged; the
  partner's session still resolves.
- [x] 5.4 Add the no-op case: deleting an account with zero sessions still completes and raises no error.
- [x] 5.5 Add the guard case: a wrong password raises `IncorrectPasswordError` and leaves the requester's
  sessions intact.

## 6. Quality gate

- [ ] 6.1 Run `/trocado:guard` on the diff and resolve any findings.
- [ ] 6.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) and confirm green.
