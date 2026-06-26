## 1. Domain — Virtual Object (no new error; "not paired" is `None`, not an error)

- [x] 1.1 Add `CurrentPairVirtualObject` in `features/pairing/domain/virtual_objects/current_pair_virtual_object.py` — `@dataclass(frozen=True, slots=True)` holding `reader_id: str`, `pair: PairEntity`, `partner_id: str`, `partner_name: str`; derived properties `pair_id -> str` (`pair.id`), `paired_since -> datetime` (`pair.created_at`). The reader-relative partner (`partner_id`/`partner_name`) is supplied by the use case (the "member who is not the reader" idiom); the VO asserts internal consistency — `partner_id` must be one of `pair.person_a_id` / `pair.person_b_id` and must not equal `reader_id` (raise on violation). Composes the stored entity + resolved identity; no own identity; never stored.

## 2. Application — Port extension (additive; pairing's existing identity ACL)

- [x] 2.1 Extend `PersonDirectoryInterface` (`application/interfaces/person_directory_interface.py`) with `async def find_active_profile(self, person_id: str) -> PartnerProfileData | None` — returns the **active** person's identity (`id`, `name`), or `None` for an unknown/inactive id; never raising (matching the port's existing non-raising contract). Leave `is_active` untouched. Document it as the cohesive broadening of the directory seam from active-check to id→profile; the concrete identity-backed adapter is wired at the composition root (`pairing` never imports `identity`).

## 3. Application — Data shapes and mapper

- [x] 3.1 Add `PartnerProfileData` (`application/data/partner_profile_data.py`) — `@dataclass(frozen=True, slots=True)` with `id: str`, `name: str` (the cross-context read shape the directory returns; a plain carrier — `data`, not a value object).
- [x] 3.2 Add `CurrentPairData` (`application/data/current_pair_data.py`) — `@dataclass(frozen=True, slots=True)` with `pair_id: str`, `paired_since: datetime`, `partner_id: str`, `partner_name: str` (the public read-model).
- [x] 3.3 Add `CurrentPairDataMapper` (`application/mappers/current_pair_data_mapper.py`) — `@staticmethod to_data(view: CurrentPairVirtualObject) -> CurrentPairData`, reading the VO's derived properties.

## 4. Application — Use case

- [x] 4.1 Add `GetCurrentPairUseCase(pair_repository, person_directory)` with `async def execute(reader_id: str) -> CurrentPairData | None`.
- [x] 4.2 Resolve the reader's live pair via `pair_repository.find_active_by_person(reader_id)`; when `None`, return `None` (the reader is not paired — a valid answer, never `NotPairedError`).
- [x] 4.3 Compute `partner_id` (the member of the pair who is not the reader — `pair.person_b_id if reader_id == pair.person_a_id else pair.person_a_id`); await `person_directory.find_active_profile(partner_id)` **sequentially** (real data dependency on `partner_id`, so no `gather`).
- [x] 4.4 If the partner profile is `None` while the pair is live, raise a plain `RuntimeError` with a short non-leaking message (integrity violation — `delete-account` dissolves pairs, so a live pair guarantees an active partner); do **not** return `None` here.
- [x] 4.5 Build `CurrentPairVirtualObject(reader_id, pair, profile.id, profile.name)`; return `CurrentPairDataMapper.to_data(view)`.

## 5. Tests

- [x] 5.1 Unit test `CurrentPairVirtualObject` — `pair_id`/`paired_since` echo the entity; partner fields preserved; the consistency assertion raises when `partner_id` equals `reader_id` or is neither member.
- [x] 5.2 Extend `FakePersonDirectory` under `tests/pairing/fakes/` with `find_active_profile` (per-person profile map; returns `None` when absent), keeping `is_active`; reuse `FakePairRepository`.
- [x] 5.3 Use-case unit tests: reader is `person_a` → partner is `person_b` (id + name); reader is `person_b` → partner is `person_a`; no live pair → `None`; dissolved-only pair → `None`; partner profile unresolvable on a live pair → `RuntimeError`.
- [x] 5.4 Use-case authorization test: with two unrelated couples seeded, a reader resolves only their own pair, never another couple's.
- [x] 5.5 Integration test under `tests/pairing/integrations/` wiring the in-memory `PairRepository` + `FakePersonDirectory` through the use case (no pair → `None`; form a pair + seed both profiles → current pair from each member's perspective; dissolve the pair → `None`).

## 6. Guard

- [x] 6.1 Run `/trocado:guard` (architecture-guard) on the diff and resolve any findings.
- [x] 6.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) and make it green.
