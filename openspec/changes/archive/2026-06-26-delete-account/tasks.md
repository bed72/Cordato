## 1. Identity domain

- [x] 1.1 Add `IncorrectPasswordError` in `identity/domain/errors/incorrect_password_error.py` — pt-BR,
  non-leaking message (e.g. `"Senha incorreta."`), one concept per file.
- [x] 1.2 Add a module-level constant for the reserved sentinel email domain (e.g. `trocado.invalid`) in the
  `PersonEntity` file, and a `PersonEntity.delete()` mutation: flips `status` to `PersonStatus.DELETED` and
  replaces `email` with `EmailValueObject(f"deleted+{id}@{...}")` derived from the id. No new field.

## 2. Identity application ports

- [x] 2.1 Extend `PasswordHasherInterface` with `async def verify(self, password: PasswordValueObject, hash: str) -> bool`
  (abstractmethod, docstring: constant-time, off-loop, never logs plaintext).
- [x] 2.2 Extend `PersonRepositoryInterface` with `async def find_active_by_id(self, person_id: str) -> PersonEntity | None`
  and `async def delete(self, person: PersonEntity) -> None` (persist the retired person — neutralized email
  + `DELETED` status).
- [x] 2.3 Add `BudgetEraserInterface` (`async def erase_for_person(self, person_id: str) -> None`) in
  `identity/application/interfaces/budget_eraser_interface.py` — anti-corruption port, identity vocabulary.
- [x] 2.4 Add `ExpenseEraserInterface` (`async def erase_for_person(self, person_id: str) -> None`) in
  `identity/application/interfaces/expense_eraser_interface.py`.
- [x] 2.5 Add `PairDissolverInterface` (`async def dissolve_for_person(self, person_id: str) -> None` —
  idempotent, no-op when no live pair) in `identity/application/interfaces/pair_dissolver_interface.py`.

## 3. Budgeting & expenses port + adapter extensions

- [x] 3.1 Extend `BudgetRepositoryInterface` with `async def erase_for_person(self, person_id: str) -> None`
  — physical purge of all of a person's budgets (live and soft-deleted); document it as the cascade primitive.
- [x] 3.2 Implement `erase_for_person` in the in-memory `BudgetRepository` (drop all matching entries).
- [x] 3.3 Extend `ExpenseRepositoryInterface` with `async def erase_for_person(self, person_id: str) -> None`
  and implement it in the in-memory `ExpenseRepository`.

## 4. Identity application use case

- [x] 4.1 Add `DeleteAccountData` in `identity/application/data/delete_account_data.py` — command input:
  `requester_id: str` + raw password (as `PasswordValueObject`).
- [x] 4.2 Add `DeleteAccountUseCase` in `identity/application/use_cases/delete_account_use_case.py`:
  resolve via `find_active_by_id` (None → `IncorrectPasswordError`); `verify` (False → `IncorrectPasswordError`)
  as the strict first guard; then `asyncio.gather` the independent steps — erase budgets, erase expenses,
  `person.delete()` + `PersonRepository.delete`, `PairDissolver.dissolve_for_person`. Returns `None`.

## 5. Identity infrastructure (Argon2 gateway)

- [x] 5.1 Implement `verify` on the Argon2 `PasswordHasher` gateway — `argon2`'s verify wrapped with
  `asyncio.to_thread`, returning `bool` (False on mismatch, never raising outward), never logging plaintext.
- [x] 5.2 Implement `find_active_by_id` and `delete` on the in-memory `PersonRepository` (delete persists the
  neutralized email + `DELETED` status; non-active stays excluded from `find_active_by_*`).

## 6. Tests

- [x] 6.1 Unit test `PersonEntity.delete` — status → `DELETED`, email neutralized to the id-derived sentinel,
  identity equality (`__eq__`/`__hash__` on id) intact.
- [x] 6.2 Unit test `IncorrectPasswordError` — pt-BR message, no sensitive data leaked.
- [x] 6.3 Gateway test for Argon2 `verify` — accepts the correct password against a real hash, rejects a wrong
  one. Repository tests for `PersonRepository.find_active_by_id` / `delete`, and for the budget/expense
  `erase_for_person` purges.
- [x] 6.4 Hand-written fakes under `tests/identity/fakes/`: `fake_budget_eraser.py`, `fake_expense_eraser.py`,
  `fake_pair_dissolver.py` (each one per file, satisfying its ABC).
- [x] 6.5 Use-case tests for `DeleteAccountUseCase`: correct password → budgets + expenses erased, person
  retired + email neutralized, live pair dissolved; correct password but no live pair → still succeeds,
  dissolve is a no-op; wrong password → `IncorrectPasswordError` and nothing erased/changed; another person's
  ledger and the partner's data untouched.
- [x] 6.6 Integration test under `tests/identity/integrations/`: wire in-memory `PersonRepository` + real
  Argon2 hasher + eraser/dissolver fakes through the use case; assert the ledger is gone, the freed email is
  reusable by a fresh `register-person` (new id, empty ledger), and the former pair is no longer live.

## 7. Guard & finalize

- [x] 7.1 Run `uv run poe check` (format → lint → mypy --strict → pytest) until green.
- [x] 7.2 Run `/trocado:guard` on the diff and resolve any reported violation (async boundaries, dependency
  direction, naming, no lib names, one-concept-per-file, pt-BR non-leaking errors, test layout).
