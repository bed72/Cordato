# list-budgets Specification

## Purpose
TBD - created by archiving change list-budgets. Update Purpose after archive.
## Requirements
### Requirement: A person can list their own live budgets

The system SHALL return, for a given `person_id`, that person's **live** budgets — each carrying its own
`id`, `person_id`, `amount`, `start_date`, `end_date`, `note`, and `created_at`. The list is **read-only**
and read at request-time; producing it SHALL NOT mutate the ledger. Each item carries **no spend**:
`total_spent` and `remaining` belong to the enriched active-budget read, not to this list.

#### Scenario: The person's budgets are returned

- **WHEN** a person who owns live budgets requests their list
- **THEN** the system returns one item per live budget, each preserving its own amount, range, note, and identity

#### Scenario: A person with no budgets gets an empty list

- **WHEN** a person who owns no live budget requests their list
- **THEN** the system returns an empty list

### Requirement: Soft-deleted budgets are excluded from the list

The system SHALL exclude any budget whose `deleted_at` is set. The day-to-day list is a normal read, so it
follows the two-read contract: only the explicit audit read (`list_including_removed`) ever sees
soft-deleted rows.

#### Scenario: A soft-deleted budget does not appear

- **WHEN** a person has both live and soft-deleted budgets
- **THEN** the returned list contains only the live ones

### Requirement: The list is ordered most-recent-period-first

The system SHALL order the list by `start_date` descending, breaking ties by `created_at` descending, so
the budget whose period begins most recently appears first. This mirrors `list-expenses`'
most-recent-first contract.

#### Scenario: A later-starting budget comes first

- **WHEN** the list contains budgets with different `start_date` values
- **THEN** the budget with the later `start_date` appears before the earlier one

#### Scenario: Same-start budgets break ties by creation time

- **WHEN** two budgets share the same `start_date`
- **THEN** the one with the later `created_at` appears first

### Requirement: A person lists only their own budgets

The system SHALL return only budgets owned by the requesting `person_id`. Listing grants no view over
anyone else's budgets; the shared couple view is a separate, explicit capability.

#### Scenario: Another person's budgets are never included

- **WHEN** a person requests their list while other people own budgets
- **THEN** the returned list contains only the requester's own budgets

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

