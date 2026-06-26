## 1. Domain — Perspective, virtual object, error

- [x] 1.1 Add `Perspective` enum in `features/pairing/domain/enums/perspective.py` — `class Perspective(Enum)` with `MINE = "mine"` and `THEIRS = "theirs"` (enums live in `domain/enums/`, not `value_objects/`).
- [x] 1.2 Add `CoupleExpenseVirtualObject` in `features/pairing/domain/virtual_objects/couple_expense_virtual_object.py` — `@dataclass(frozen=True, slots=True)` holding `expense_id: str`, `owner_id: str`, `amount: MoneyValueObject`, `occurred_on: date`, `created_at: datetime`, `description: str | None`, `reader_id: str`; derived property `perspective -> Perspective` (`MINE` when `owner_id == reader_id`, else `THEIRS`).
- [x] 1.3 Add `NotPairedError` in `features/pairing/domain/errors/not_paired_error.py` → "Você não está em um par ativo." (non-leaking, no partner data).

## 2. Application — Port (consumer-owned gateway ACL)

- [x] 2.1 Add `PartnerExpenseReaderInterface` (`application/interfaces/partner_expense_reader_interface.py`) — ABC with `async def list_for_person(person_id: str) -> list[PartnerExpenseData]`; document it as pairing's gateway ACL over a person's expenses (live only; no `pairing → expenses` import; real adapter wired at the composition root).

## 3. Application — Data shapes and mapper

- [x] 3.1 Add `PartnerExpenseData` (`application/data/partner_expense_data.py`) — `@dataclass(frozen=True, slots=True)` with `id: str`, `person_id: str`, `amount: Decimal`, `occurred_on: date`, `created_at: datetime`, `description: str | None` (the cross-context read shape the gateway returns).
- [x] 3.2 Add `CoupleExpenseData` (`application/data/couple_expense_data.py`) — frozen dataclass `id`, `person_id`, `amount: Decimal`, `occurred_on: date`, `created_at: datetime`, `description: str | None`, `perspective: str` (the public read-model).
- [x] 3.3 Add `CoupleExpenseDataMapper` (`application/mappers/couple_expense_data_mapper.py`) — `@staticmethod to_data(view: CoupleExpenseVirtualObject) -> CoupleExpenseData`, unwrapping `amount` to `Decimal` and `perspective` to its `.value` string.

## 4. Application — Use case

- [x] 4.1 Add `GetCoupleExpensesUseCase(pair_repository, partner_expense_reader)` with `async def execute(reader_id: str) -> list[CoupleExpenseData]`.
- [x] 4.2 Resolve the reader's live pair via `pair_repository.find_active_by_person(reader_id)`; raise `NotPairedError` when `None`.
- [x] 4.3 Compute `partner_id` (the other id of the pair); `asyncio.gather` `list_for_person(reader_id)` and `list_for_person(partner_id)`.
- [x] 4.4 Build a `CoupleExpenseVirtualObject` per expense (wrapping `amount` in `MoneyValueObject`, passing `reader_id`), concatenating both lists.
- [x] 4.5 Sort most-recent-first (`occurred_on` desc, then `created_at` desc); map each via `CoupleExpenseDataMapper.to_data`; return the list.

## 5. Tests

- [x] 5.1 Unit test `Perspective` (members + string values).
- [x] 5.2 Unit test `CoupleExpenseVirtualObject` — `perspective` is `MINE` when `owner_id == reader_id`, `THEIRS` otherwise.
- [x] 5.3 Unit test `NotPairedError` (message + non-leaking).
- [x] 5.4 Add `FakePartnerExpenseReader` under `tests/pairing/fakes/` (per-person live-expense lists); reuse `FakePairRepository`.
- [x] 5.5 Use-case unit tests: both ledgers combined + correct `mine`/`theirs` marking + ordering; one partner empty; both empty; reader-not-paired → `NotPairedError`; dissolved-only pair → `NotPairedError`.
- [x] 5.6 Integration test under `tests/pairing/integrations/` wiring the in-memory `PairRepository` + `FakePartnerExpenseReader` through the use case (form a pair, seed both ledgers → union marked and ordered).

## 6. Guard

- [x] 6.1 Run `/trocado:guard` (architecture-guard) on the diff and resolve any findings.
- [x] 6.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) and make it green.
