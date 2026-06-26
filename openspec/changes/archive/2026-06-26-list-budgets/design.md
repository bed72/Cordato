## Context

Budgeting already exposes reads for the *active* budget (`GetActiveBudgetUseCase`, date-containment +
enriched spend) and the *default* "No budget" bucket. The `BudgetRepositoryInterface` already declares
`list_live_for_person(person_id) -> list[BudgetEntity]` — added for the non-overlap check — which returns
exactly the live budgets this capability needs. The public read-model `BudgetData` and its
`BudgetDataMapper` already exist (spend-free, the plain create response). So this change is almost entirely
composition of parts that already exist; the only genuinely new production unit is a use case.

## Goals / Non-Goals

**Goals:**
- A read-only `ListBudgetsUseCase` returning `list[BudgetData]` for a person, ordered
  most-recent-period-first, soft-deleted excluded, scoped to the requester.
- Reuse the existing port method, read-model, and mapper unchanged.

**Non-Goals:**
- No spend enrichment (`total_spent`/`remaining`) — that stays with the active-budget read and its
  `ActiveBudgetData`. This list is deliberately plain.
- No pagination/filtering — a couple has little data; the full list is cheap (consistent with the
  "NO cache" decision). Add later only if a real need appears.
- No new port method, entity, value object, ORM, or web layer.

## Decisions

- **Reuse `list_live_for_person`, do not add a port method.** It already returns the person's live budgets
  (soft-delete handled in the adapter, owner-scoped). Adding a `list_budgets`-named method would duplicate
  an existing contract for no behavioral gain — against derive/earn-its-existence discipline.
  *Alternative considered:* a dedicated `list_for_person_ordered` port that sorts in the adapter — rejected:
  ordering is a presentation rule, not a persistence concern, and the eventual ORM can still sort in SQL
  behind the same port without changing the contract.
- **Sort in the use case**, by `start_date` desc then `created_at` desc, exactly mirroring `list-expenses`
  (`occurred_on` desc, `created_at` desc). Keeps "most-recent-first" semantics consistent across the two
  list reads. The pure ordering is a tuple key `(start_date, created_at)` reversed.
- **Reuse `BudgetData` + `BudgetDataMapper`.** Same shape the create read already returns; the use case maps
  each entity with `BudgetDataMapper.to_data`. No new `data`/mapper file — symmetry with `list-expenses`,
  which also reuses the per-item read-model.
- **`async def execute(self, person_id: str) -> list[BudgetData]`.** Async by the I/O-boundary rule (the
  port is async); a single awaited port call, then pure in-memory sort + map — no `gather` needed (one call).

## Risks / Trade-offs

- **[Unbounded list as data grows]** → Acceptable now (couple = little data; same reasoning as the no-cache
  decision). Pagination is a future change behind the same use case if it ever matters.
- **[Ordering lives in the use case, not the adapter]** → The in-memory adapter returns unordered; the use
  case is the single source of order. When the ORM lands it MAY push the `ORDER BY` into SQL, but the
  capability's contract is the use case's output order — tests assert on the use case, so the guarantee
  holds regardless of where the sort runs.
