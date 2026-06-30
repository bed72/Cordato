# active-budget Specification

## Purpose
TBD - created by archiving change create-budget. Update Purpose after archive.
## Requirements
### Requirement: A person's active budget is derived for a given day

The system SHALL compute a person's active budget at read-time as the person's single live budget whose
inclusive date range contains a given reference day. This association SHALL be derived, never stored: it is
recomputed on each read from the budgets' own date fields. If no live budget contains the day, the system SHALL
report that the person has no active budget for that day (no row is fabricated by this capability). Because live
budgets of a person never overlap, at most one budget can match — the result is unambiguous.

#### Scenario: A budget containing the day is active

- **WHEN** a person has a live budget whose range contains the reference day
- **THEN** the system returns that budget as the active one, enriched with its derived totals

#### Scenario: No budget contains the day

- **WHEN** none of a person's live budgets contains the reference day
- **THEN** the system reports no active budget for that day

#### Scenario: Soft-deleted budgets are never active

- **WHEN** the only budget whose range contains the day is soft-deleted
- **THEN** the system reports no active budget for that day

### Requirement: The active budget is enriched with derived spend

The system SHALL enrich the active budget with `total_spent` and `remaining`, both computed at read-time and
never stored. `total_spent` SHALL be the sum of the owner's expenses whose date falls within the budget's
inclusive range; `remaining` SHALL be `amount − total_spent`. Spend SHALL be obtained by querying expenses over
the date range with no foreign key from expense to budget — belonging is purely date-range. Soft-deleted
expenses SHALL be excluded from the sum, and only the budget owner's expenses SHALL be counted.

#### Scenario: Total spent sums expenses in range

- **WHEN** the owner has expenses dated within the active budget's range
- **THEN** `total_spent` equals the sum of those expenses' amounts and `remaining` equals `amount − total_spent`

#### Scenario: Expenses outside the range are excluded

- **WHEN** the owner has expenses dated before the budget's `start_date` or after its `end_date`
- **THEN** those expenses are not counted in `total_spent`

#### Scenario: Remaining goes negative when overspent

- **WHEN** the owner's expenses within the range sum to more than the budget amount
- **THEN** `remaining` is the negative difference, reported exactly (never clamped to zero)

#### Scenario: A budget with no expenses spends nothing

- **WHEN** the owner has no expenses within the active budget's range
- **THEN** `total_spent` is zero and `remaining` equals the full budget amount

### Requirement: Active budget for today is reachable over HTTP

The system SHALL expose the existing get-active-budget behavior as `GET /v1/budgets/active`
(the `/v1` version prefix is owned by the composition root; the controller declares only its
bare resource path). The endpoint SHALL resolve the acting person via `CurrentPersonProvider`,
derive today's date from the clock port, invoke the existing `GetActiveBudgetUseCase` for
that person and day, and on success respond `200 OK` with the active budget enriched with
`total_spent` and `remaining`. When no live budget contains today, the controller SHALL raise
`BudgetNotFoundError` so the existing error table frames the response as `404` in the unified
error envelope. The HTTP endpoint SHALL add no business rule — it is a transport over the
use case.

The route MUST be registered as a **static path** (`/budgets/active`) and mounted **before**
the parameterized route (`/budgets/{budget_id:str}`) to avoid Litestar matching `active` as
a budget id.

#### Scenario: Authenticated person has an active budget for today

- **WHEN** `GET /v1/budgets/active` is requested with a valid Bearer token and the person has
  a live budget whose inclusive date range contains today
- **THEN** the system responds `200 OK` with the budget enriched with `total_spent` and
  `remaining`, both derived at read-time

#### Scenario: Authenticated person has no active budget for today

- **WHEN** `GET /v1/budgets/active` is requested with a valid Bearer token and no live budget
  contains today
- **THEN** the system responds `404` in the unified error envelope

#### Scenario: Unauthenticated request is rejected

- **WHEN** `GET /v1/budgets/active` is requested without a valid `Authorization: Bearer
  <token>` header
- **THEN** the system responds `401` in the unified error envelope

