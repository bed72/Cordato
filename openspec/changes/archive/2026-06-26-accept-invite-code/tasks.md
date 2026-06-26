## 1. Domain — Pair entity and invite-code redemption behavior

- [x] 1.1 Add `PairEntity` in `features/pairing/domain/entities/pair_entity.py` — `@dataclass(eq=False, slots=True)` with `id`, `created_at`, `person_a_id`, `person_b_id`, `deleted_at: datetime | None` (no default); `create(...)` factory fixing `deleted_at = None`; `__eq__`/`__hash__` on `id`.
- [x] 1.2 Extend `InviteCodeEntity` with redemption behavior: `is_expired(reference: datetime) -> bool` (`reference >= expires_at`), `is_consumed` property (`consumed_at is not None`), and `consume(at: datetime) -> None` mutator setting `consumed_at = at`.

## 2. Domain — Errors (pt-BR, non-leaking, one per file)

- [x] 2.1 `InviteCodeNotFoundError` → "Convite inválido."
- [x] 2.2 `InviteCodeExpiredError` → "Convite expirado."
- [x] 2.3 `InviteCodeAlreadyConsumedError` → "Convite já utilizado."
- [x] 2.4 `SelfPairingError` → "Você não pode parear consigo mesmo."
- [x] 2.5 `AlreadyPairedError` → "Já existe um par ativo." (never reveals which party)
- [x] 2.6 `PersonNotActiveError` → "Conta indisponível." (never reveals which party, never echoes an id)

## 3. Application — Ports

- [x] 3.1 Add `PersonDirectoryInterface` (`application/interfaces/person_directory_interface.py`) — ABC with `async def is_active(person_id: str) -> bool`; document it as pairing's consumer-owned ACL port (no `pairing → identity` import).
- [x] 3.2 Add `PairRepositoryInterface` — ABC with `async def find_active_by_person(person_id: str) -> PairEntity | None` (live pairs only — soft-delete is the repository's job) and `async def create(pair: PairEntity) -> None`.
- [x] 3.3 Extend `InviteCodeRepositoryInterface` with `async def find_by_token(code: str) -> InviteCodeEntity | None` and `async def consume(invite_code: InviteCodeEntity) -> None`.

## 4. Application — Data shapes and mapper

- [x] 4.1 Add `AcceptInviteCodeData` (command) — `code: str`, `accepter_id: str`.
- [x] 4.2 Add `PairData` (read-model) — `id`, `person_a_id`, `person_b_id`, `created_at`.
- [x] 4.3 Add `PairDataMapper` with `@staticmethod to_data(pair: PairEntity) -> PairData`.

## 5. Application — Use case

- [x] 5.1 Add `AcceptInviteCodeUseCase(clock, identifier, invite_code_repository, pair_repository, person_directory)`.
- [x] 5.2 Resolve the token via `find_by_token`; raise `InviteCodeNotFoundError` when absent.
- [x] 5.3 Draw `now` from the clock; guard `is_expired` → `InviteCodeExpiredError` and `is_consumed` → `InviteCodeAlreadyConsumedError`.
- [x] 5.4 Guard `accepter_id == code.creator_id` → `SelfPairingError`.
- [x] 5.5 `asyncio.gather` the independent reads (both `find_active_by_person`, both `is_active`, `identifier.generate()`); raise `AlreadyPairedError` if either party has a live pair, `PersonNotActiveError` if either is inactive.
- [x] 5.6 On success: `code.consume(now)`; build the `PairEntity` (creator = `person_a_id`, accepter = `person_b_id`); persist via `invite_code_repository.consume` and `pair_repository.create`; return `PairDataMapper.to_data(pair)`.

## 6. Infrastructure — In-memory adapters

- [x] 6.1 Add in-memory `PairRepository` (`infrastructure/repositories/pair_repository.py`) — dict keyed by `id`; `find_active_by_person` returns a pair containing the person with `deleted_at` null; `create` stores it.
- [x] 6.2 Extend in-memory `InviteCodeRepository` with `find_by_token` (scan by token) and `consume` (overwrite the stored entity).

## 7. Tests

- [x] 7.1 Unit tests for `PairEntity` (factory fixes `deleted_at = None`; identity equality) and the new `InviteCodeEntity` behavior (`is_expired` boundary at `expires_at`, `is_consumed`, `consume`).
- [x] 7.2 Unit tests for each new error (message + non-leaking).
- [x] 7.3 Add `FakePairRepository` and `FakePersonDirectory` under `tests/pairing/fakes/`; extend `FakeInviteCodeRepository` with `find_by_token` + `consume`.
- [x] 7.4 Use-case unit tests: happy path + every rejection (not-found, expired, last-moment-live, consumed, self-pairing, creator-paired, accepter-paired, dissolved-past-pair-does-not-block, inactive-creator, inactive-accepter), with fakes and a fixed clock/id.
- [x] 7.5 Repository unit tests: in-memory `PairRepository` (live vs dissolved lookup) and the extended `InviteCodeRepository` (`find_by_token`, `consume`).
- [x] 7.6 Integration test under `tests/pairing/integrations/` wiring the real in-memory repositories + core determinism adapters + a fake `PersonDirectory` through the use case (mint a code, then accept it → pair formed, code consumed).

## 8. Guard

- [x] 8.1 Run `/trocado:guard` (architecture-guard) on the diff and resolve any findings.
- [x] 8.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) and make it green.
