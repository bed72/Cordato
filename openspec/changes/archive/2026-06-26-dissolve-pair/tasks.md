## 1. Domain — entity mutation (no new entity, no new field, no new error)

- [x] 1.1 Add `dissolve(self, at: datetime) -> None` to `PairEntity` (`features/pairing/domain/entities/pair_entity.py`) — stamps `self.deleted_at = at`, the only transition out of the live state. Mirror `InviteCodeEntity.consume(at)` exactly: a bare stamp, no defensive guard (the live-pair guard lives at the use-case boundary). Update the class docstring's `deleted_at` note to mention `dissolve` as that transition. Reuse the existing `NotPairedError`; add no new error.

## 2. Application — command data and use case

- [x] 2.1 Add `DissolvePairData` (`features/pairing/application/data/dissolve_pair_data.py`) — `@dataclass(frozen=True, slots=True)` with a single field `requester_id: str` (the person dissolving). No output read-model and no output mapper — dissolve returns nothing.
- [x] 2.2 Add `DissolvePairUseCase` (`features/pairing/application/use_cases/dissolve_pair_use_case.py`) — `__init__(self, clock: ClockInterface, pair_repository: PairRepositoryInterface)`; `async def execute(self, data: DissolvePairData) -> None`.
- [x] 2.3 In `execute`: resolve the requester's live pair via `pair_repository.find_active_by_person(data.requester_id)`; if `None`, `raise NotPairedError()` (guard before any further work). Then `now = await self._clock.now()`, `pair.dissolve(now)`, `await pair_repository.dissolve(pair)`, return `None`. Await sequentially (real data dependency; guard short-circuits before the clock call) — no `asyncio.gather`.

## 3. Application — port

- [x] 3.1 Extend `PairRepositoryInterface` (`features/pairing/application/interfaces/pair_repository_interface.py`) with `async def dissolve(self, pair: PairEntity) -> None` — "persist a pair whose `deleted_at` has just been stamped", mirroring `InviteCodeRepositoryInterface.consume`. Update the port docstring to note dissolve persists the soft-delete. Leave `find_active_by_person` and `create` unchanged.

## 4. Infrastructure — adapter

- [x] 4.1 Implement `dissolve` on the in-memory `PairRepository` (`features/pairing/infrastructure/repositories/pair_repository.py`) — re-store by id: `self._pairs[pair.id] = pair`.

## 5. Tests

- [x] 5.1 Add `dissolve` to `FakePairRepository` (`tests/pairing/fakes/fake_pair_repository.py`) so it still satisfies the ABC — replace the matching pair in `self.pairs` by id (or stamp in place), keeping it inspectable for assertions.
- [x] 5.2 Unit test `PairEntity.dissolve` (`tests/pairing/domain/entities/test_pair_entity.py`) — a live pair gains the stamped `deleted_at`; identity equality (by `id`) and the other fields are unchanged.
- [x] 5.3 Use-case unit tests (`tests/pairing/application/use_cases/test_dissolve_pair_use_case.py`) with `FakePairRepository` + a fake/stub `Clock`: requester is `person_a` of a live pair → pair dissolved (`deleted_at` stamped) and persisted; requester is `person_b` → dissolved and persisted; requester in no live pair → `NotPairedError` (nothing persisted); requester whose only pair is already dissolved → `NotPairedError`.
- [x] 5.4 Integration test (`tests/pairing/integrations/test_dissolve_pair.py`) wiring the in-memory `PairRepository` + real `Clock` through the use case: form a live pair, dissolve it, assert `find_active_by_person` now returns `None` for **both** former members; then assert re-pairing succeeds (a fresh `create` for one member is found live afterward, with a new pair id).

## 6. Guard

- [x] 6.1 Run `/trocado:guard` (architecture-guard) on the diff and resolve any findings.
- [x] 6.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) and make it green.
