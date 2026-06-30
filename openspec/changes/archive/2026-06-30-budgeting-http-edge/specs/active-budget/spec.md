## ADDED Requirements

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
