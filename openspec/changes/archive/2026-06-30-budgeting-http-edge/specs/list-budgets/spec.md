## ADDED Requirements

### Requirement: List budgets is reachable over HTTP

The system SHALL expose the existing list-budgets behavior as `GET /v1/budgets` (the `/v1`
version prefix is owned by the composition root; the controller declares only its bare resource
path). The endpoint SHALL resolve the acting person via `CurrentPersonProvider`, invoke the
existing `ListBudgetsUseCase` unchanged, and respond `200 OK` with the list of live budgets —
each carrying `id`, `person_id`, `amount`, `start_date`, `end_date`, `note`, and
`created_at` — ordered most-recent-period-first. An empty list is a valid `200 OK` response
with an empty JSON array. The endpoint SHALL require authentication (`Authorization: Bearer
<token>`); a missing or invalid token SHALL respond `401` in the unified error envelope before
the use case is invoked. The HTTP endpoint SHALL add no business rule — it is a transport over
the use case.

#### Scenario: Authenticated person receives their live budgets

- **WHEN** `GET /v1/budgets` is requested with a valid Bearer token and the person has live
  budgets
- **THEN** the system responds `200 OK` with a JSON array of budget objects, each carrying
  `id`, `person_id`, `amount`, `start_date`, `end_date`, `note`, and `created_at`, ordered by
  `start_date` descending

#### Scenario: Authenticated person with no budgets receives an empty array

- **WHEN** `GET /v1/budgets` is requested with a valid Bearer token and the person has no
  live budgets
- **THEN** the system responds `200 OK` with an empty JSON array

#### Scenario: Unauthenticated request is rejected

- **WHEN** `GET /v1/budgets` is requested without an `Authorization: Bearer <token>` header
- **THEN** the system responds `401` in the unified error envelope before invoking the use
  case
