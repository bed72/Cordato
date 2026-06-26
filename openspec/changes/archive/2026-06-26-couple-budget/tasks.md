## 1. Domain — Virtual Objects (no new error; reuse `NotPairedError`)

- [x] 1.1 Add `PartnerActiveBudgetVirtualObject` in `features/pairing/domain/virtual_objects/partner_active_budget_virtual_object.py` — `@dataclass(frozen=True, slots=True)` holding `start_date: date`, `end_date: date`, `amount: MoneyValueObject`, `total_spent: MoneyValueObject`; derived property `remaining -> MoneyValueObject` (`amount − total_spent`, negative when overspent). Pairing's read-time view of one partner's active budget (the ACL counterpart of budgeting's `ActiveBudgetVirtualObject`, never imported).
- [x] 1.2 Add `CoupleBudgetVirtualObject` in `features/pairing/domain/virtual_objects/couple_budget_virtual_object.py` — `@dataclass(frozen=True, slots=True)` holding `budgets: tuple[PartnerActiveBudgetVirtualObject, ...]` (non-empty by construction); derived properties `period_start` (`min` start), `period_end` (`max` end), `amount` (sum, `MoneyValueObject`), `total_spent` (sum, `MoneyValueObject`), `remaining` (`amount − total_spent`). The span + money sums are the domain rule and live here.

## 2. Application — Port (consumer-owned gateway ACL)

- [x] 2.1 Add `PartnerBudgetReaderInterface` (`application/interfaces/partner_budget_reader_interface.py`) — ABC with `async def active_for_person(person_id: str, day: date) -> PartnerActiveBudgetData | None`; document it as pairing's gateway ACL over a person's active budget (returns `None` when none; no `pairing → budgeting` import; real adapter — delegating to budgeting's `GetActiveBudgetUseCase` — wired at the composition root).

## 3. Application — Data shapes and mapper

- [x] 3.1 Add `PartnerActiveBudgetData` (`application/data/partner_active_budget_data.py`) — `@dataclass(frozen=True, slots=True)` with `person_id: str`, `start_date: date`, `end_date: date`, `amount: Decimal`, `total_spent: Decimal` (the cross-context read shape the gateway returns).
- [x] 3.2 Add `CoupleBudgetData` (`application/data/couple_budget_data.py`) — `@dataclass(frozen=True, slots=True)` with `period_start: date`, `period_end: date`, `amount: Decimal`, `total_spent: Decimal`, `remaining: Decimal` (the public read-model).
- [x] 3.3 Add `CoupleBudgetDataMapper` (`application/mappers/couple_budget_data_mapper.py`) — `@staticmethod to_data(view: CoupleBudgetVirtualObject) -> CoupleBudgetData`, reading the VO's derived properties and unwrapping each `MoneyValueObject` to `Decimal`.

## 4. Application — Use case

- [x] 4.1 Add `GetCoupleBudgetUseCase(pair_repository, partner_budget_reader)` with `async def execute(reader_id: str, day: date) -> CoupleBudgetData | None`.
- [x] 4.2 Resolve the reader's live pair via `pair_repository.find_active_by_person(reader_id)`; raise `NotPairedError` when `None` (guard before any read).
- [x] 4.3 Compute `partner_id` (the other id of the pair); `asyncio.gather` `active_for_person(reader_id, day)` and `active_for_person(partner_id, day)`.
- [x] 4.4 Collect the present budgets (drop `None`); if none present, return `None`.
- [x] 4.5 Map each present `PartnerActiveBudgetData` → `PartnerActiveBudgetVirtualObject` (wrap `amount` / `total_spent` in `MoneyValueObject`); build `CoupleBudgetVirtualObject(tuple(views))`; return `CoupleBudgetDataMapper.to_data(view)`.

## 5. Tests

- [x] 5.1 Unit test `PartnerActiveBudgetVirtualObject` — derived `remaining` (positive, zero, and negative/overspent).
- [x] 5.2 Unit test `CoupleBudgetVirtualObject` — two partners: `period_start = min`, `period_end = max`, `amount`/`total_spent` summed exactly, `remaining = amount − total_spent`; and the single-partner case where the panorama equals that partner's span and figures.
- [x] 5.3 Add `FakePartnerBudgetReader` under `tests/pairing/fakes/` (per-person active-budget map; returns `None` when absent); reuse `FakePairRepository`.
- [x] 5.4 Use-case unit tests: both partners present → combined panorama (span + sums); one present → that partner's span only; neither present → `None`; reader-not-paired → `NotPairedError`; dissolved-only pair → `NotPairedError`.
- [x] 5.5 Integration test under `tests/pairing/integrations/` wiring the in-memory `PairRepository` + `FakePartnerBudgetReader` through the use case (form a pair, seed both partners' active budgets → combined panorama; then drop one → single-partner span; then drop both → `None`).

## 6. Guard

- [x] 6.1 Run `/trocado:guard` (architecture-guard) on the diff and resolve any findings.
- [x] 6.2 Run `uv run poe check` (format → lint → mypy --strict → pytest) and make it green.
