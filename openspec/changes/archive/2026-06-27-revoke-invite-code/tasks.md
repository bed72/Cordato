## 1. Domain — entity lifecycle

- [x] 1.1 In `src/trocado/features/pairing/domain/entities/invite_code_entity.py`, add field `revoked_at: datetime | None`, set it to `None` in the `create` factory (alongside `consumed_at=None`), add an `is_revoked` property mirroring `is_consumed`, and add a `revoke(self, at: datetime) -> None` method that stamps `revoked_at` unconditionally (mirroring `consume`). Keep `eq=False` identity equality untouched.

## 2. Domain — error

- [x] 2.1 Add `InviteCodeRevokedError` in `src/trocado/features/pairing/domain/errors/invite_code_revoked_error.py`, in the same family as `InviteCodeExpiredError` / `InviteCodeAlreadyConsumedError`: a short, non-leaking pt-BR message (e.g. `"Convite inválido."` — must not reveal token existence/state).

## 3. Application — port

- [x] 3.1 In `src/trocado/features/pairing/application/interfaces/invite_code_repository_interface.py`, add `async def revoke(self, invite_code: InviteCodeEntity) -> None` (abstract), documented as "persist a code whose `revoked_at` has just been stamped" — mirroring `consume`. No other signature changes.

## 4. Application — command & use case

- [x] 4.1 Add `RevokeInviteCodeData` in `src/trocado/features/pairing/application/data/revoke_invite_code_data.py`: a `@dataclass(frozen=True, slots=True)` with `code: str` and `requester_id: str`.
- [x] 4.2 Add `RevokeInviteCodeUseCase` in `src/trocado/features/pairing/application/use_cases/revoke_invite_code_use_case.py`: constructor takes `ClockInterface` and `InviteCodeRepositoryInterface`; `async def execute(self, data: RevokeInviteCodeData) -> None`.
- [x] 4.3 In `execute`: resolve via `find_by_token(data.code)`; if `None` raise `InviteCodeNotFoundError`; if `invite.creator_id != data.requester_id` raise `InviteCodeNotFoundError` (non-owner treated as not-found, non-leaking); if `invite.is_consumed` raise `InviteCodeAlreadyConsumedError`; if `invite.is_revoked` return without re-stamping (idempotent no-op, preserve original `revoked_at`); otherwise `await clock.now()`, `invite.revoke(now)`, and `await repository.revoke(invite)`. Expiry must NOT block the revoke.

## 5. Application — accept guard

- [x] 5.1 In `src/trocado/features/pairing/application/use_cases/accept_invite_code_use_case.py`, after the expired/consumed guards add `if invite_code.is_revoked: raise InviteCodeRevokedError()`, importing the new error. Order it with the other state checks before the gather.

## 6. Infrastructure — adapter

- [x] 6.1 In `src/trocado/features/pairing/infrastructure/repositories/invite_code_repository.py`, implement `async def revoke(self, invite_code)` as the keyed overwrite (`self._invite_codes[invite_code.id] = invite_code`), mirroring `consume`.

## 7. Tests — domain

- [x] 7.1 Unit test `tests/pairing/domain/errors/test_invite_code_revoked_error.py`: the error carries a non-empty pt-BR message and leaks no token value.
- [x] 7.2 Extend `tests/pairing/domain/entities/test_invite_code_entity.py`: a freshly `create`d code has `revoked_at` null and `is_revoked` False; `revoke(at)` stamps `revoked_at` and flips `is_revoked` True; `revoke` and `consume` are independent (revoking does not set `consumed_at` and vice-versa).

## 8. Tests — application (revoke use case)

- [x] 8.1 Unit test `tests/pairing/application/use_cases/test_revoke_invite_code_use_case.py` against a hand-written `FakeInviteCodeRepository` (extend the existing fake under `tests/pairing/fakes/` to support `revoke`): cover success (revoked_at stamped from the fake clock, persisted), unknown token → `InviteCodeNotFoundError`, non-owner requester → `InviteCodeNotFoundError` (and code untouched), consumed code → `InviteCodeAlreadyConsumedError`, already-revoked → idempotent no-op preserving the original instant, and expired-but-unconsumed → revokes successfully.

## 9. Tests — application (accept rejects revoked)

- [x] 9.1 Extend `tests/pairing/application/use_cases/test_accept_invite_code_use_case.py`: accepting a revoked code raises `InviteCodeRevokedError`, creates no pair, and consumes nothing; a non-revoked otherwise-valid code still proceeds.

## 10. Tests — integration

- [x] 10.1 Integration test `tests/pairing/integrations/test_revoke_invite_code.py` wiring `RevokeInviteCodeUseCase` to the real in-memory `InviteCodeRepository` (+ a real/fake clock): mint via `CreateInviteCodeUseCase`, revoke it, then assert `AcceptInviteCodeUseCase` rejects the revoked code with `InviteCodeRevokedError` end to end; also assert the consumed-code and non-owner paths through the real adapter.

## 11. Gate

- [x] 11.1 Run `uv run poe check` (format-check → lint → mypy --strict → pytest) and make it green.
- [x] 11.2 Run `/trocado:guard` on the diff and resolve any CHANGES REQUIRED.
