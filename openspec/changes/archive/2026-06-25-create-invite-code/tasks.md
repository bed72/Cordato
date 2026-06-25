## 1. Module scaffolding

- [x] 1.1 Create the `pairing` context package tree: `src/trocado/features/pairing/{domain,application,infrastructure}` with the canonical sub-packages (`domain/entities`, `application/{interfaces,data,use_cases,mappers}`, `infrastructure/{repositories,gateways}`), each with `__init__.py`.

## 2. Domain

- [x] 2.1 Implement `InviteCodeEntity` in `domain/entities/invite_code_entity.py`: fields `id`, `created_at`, `creator_id`, `code` (`str`), `expires_at`, `consumed_at`; a `create(id, created_at, creator_id, code)` factory that fixes `expires_at = created_at + timedelta(days=1)` and `consumed_at = None`; `__eq__`/`__hash__` by `id`. No I/O, no value object around `code`.

## 3. Application ports

- [x] 3.1 Define `InviteCodeRepositoryInterface` (`abc.ABC`) in `application/interfaces/invite_code_repository_interface.py` with `async def create(self, invite_code: InviteCodeEntity) -> None`.
- [x] 3.2 Define `TokenGeneratorInterface` (`abc.ABC`) in `application/interfaces/token_generator_interface.py` with `async def generate(self) -> str`, documented as CSPRNG-backed and async-by-contract.

## 4. Application data + mapper

- [x] 4.1 Add `CreateInviteCodeData` (command, `creator_id`) in `application/data/create_invite_code_data.py`.
- [x] 4.2 Add `InviteCodeData` (read-model: `id`, `code`, `creator_id`, `expires_at`, `consumed_at`, `created_at`) in `application/data/invite_code_data.py`.
- [x] 4.3 Add `InviteCodeDataMapper.to_data(invite_code)` (`@staticmethod`) in `application/mappers/invite_code_data_mapper.py`.

## 5. Use case

- [x] 5.1 Implement `CreateInviteCodeUseCase` in `application/use_cases/create_invite_code_use_case.py`: depends on the repository, token generator, `ClockInterface`, `IdentifierProviderInterface`; `asyncio.gather`s `identifier.generate()`, `clock.now()`, `token_generator.generate()`; builds the entity via `InviteCodeEntity.create(...)`; persists it; returns `InviteCodeData` via the mapper.

## 6. Infrastructure adapters

- [x] 6.1 Implement in-memory `InviteCodeRepository` in `infrastructure/repositories/invite_code_repository.py` (stores entities; no model/mapper yet).
- [x] 6.2 Implement `TokenGenerator` gateway in `infrastructure/gateways/token_generator.py` backed by `secrets.token_urlsafe(...)`, wrapping the sync call with `asyncio.to_thread`. Class name `TokenGenerator` (never the lib name).

## 7. Tests

- [x] 7.1 Add `FakeInviteCodeRepository` and `FakeTokenGenerator` under `tests/pairing/fakes/` (one per file), satisfying the ABC ports.
- [x] 7.2 Unit-test `InviteCodeEntity` (`tests/pairing/domain/entities/test_invite_code_entity.py`): factory sets TTL one day past `created_at`, `consumed_at` null, identity equality.
- [x] 7.3 Unit-test `CreateInviteCodeUseCase` (`tests/pairing/application/use_cases/test_create_invite_code_use_case.py`): persists a code for the creator, starts unconsumed, expiry derived from clock, token comes from the generator (distinct tokens for two calls), returns correct `InviteCodeData`.
- [x] 7.4 Unit-test the in-memory `InviteCodeRepository` (`tests/pairing/infrastructure/repositories/test_invite_code_repository.py`).
- [x] 7.5 Unit-test the `TokenGenerator` gateway (`tests/pairing/infrastructure/gateways/test_token_generator.py`): returns a non-empty short URL-safe token; two calls differ.
- [x] 7.6 Integration test (`tests/pairing/integrations/test_create_invite_code.py`) wiring the real in-memory repository + real `TokenGenerator` + core clock/id adapters through the use case.

## 8. Quality gate

- [x] 8.1 Run `uv run poe check` (format → lint → mypy --strict → pytest) and fix any failures.
- [x] 8.2 Run `/trocado:guard` on the diff and resolve any CHANGES REQUIRED.
