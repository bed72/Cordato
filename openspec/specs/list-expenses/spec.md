# list-expenses Specification

## Purpose
TBD - created by archiving change default-budget-and-list-expenses. Update Purpose after archive.
## Requirements
### Requirement: A person can list their own live expenses

The system SHALL return, for a given `person_id`, that person's **live** expenses — each carrying its own
`id`, `person_id`, `amount`, `occurred_on`, `description`, and `created_at`. The list is **read-only** and
read at request-time; producing it SHALL NOT mutate the ledger. The list carries **no budget reference of
any kind** — an expense is a fact, not a filing, and its budget belonging stays derived elsewhere.

#### Scenario: The person's expenses are returned

- **WHEN** a person with live expenses requests their list
- **THEN** the system returns one item per live expense, each preserving its own amount, day, description,
  and identity

#### Scenario: A person with no expenses gets an empty list

- **WHEN** a person who owns no live expense requests their list
- **THEN** the system returns an empty list

### Requirement: Soft-deleted expenses are excluded from the list

The system SHALL exclude any expense whose `deleted_at` is set. The day-to-day list is a normal read, so it
follows the two-read contract: only the explicit audit read (`list_including_removed`) ever sees
soft-deleted rows.

#### Scenario: A soft-deleted expense does not appear

- **WHEN** a person has both live and soft-deleted expenses
- **THEN** the returned list contains only the live ones

### Requirement: The list is ordered most-recent-first

The system SHALL order the list by `occurred_on` descending, breaking ties by `created_at` descending, so
the most recent spending appears first.

#### Scenario: Newer spending comes first

- **WHEN** the list contains expenses with different days
- **THEN** the expense with the later `occurred_on` appears before the earlier one

#### Scenario: Same-day expenses break ties by creation time

- **WHEN** two expenses share the same `occurred_on`
- **THEN** the one with the later `created_at` appears first

### Requirement: A person lists only their own expenses

The system SHALL return only expenses owned by the requesting `person_id`. Listing grants no view over
anyone else's ledger; the shared couple view is a separate, explicit capability.

#### Scenario: Another person's expenses are never included

- **WHEN** a person requests their list while other people own expenses
- **THEN** the returned list contains only the requester's own expenses

### Requirement: List-expenses is reachable over HTTP

The system SHALL expose the existing list-expenses behavior as `GET /v1/expenses`. The endpoint SHALL
resolve the acting person from the `Authorization: Bearer <token>` header via `current_person_provider`;
invoke the existing `ListExpensesUseCase` with that person's `id`; and respond `200 OK` with the
person's live expenses as a JSON array — each item carrying `id`, `person_id`, `amount`, `occurred_on`,
`description`, and `created_at` — ordered most-recent-first (`occurred_on` desc, then `created_at`
desc). The endpoint carries no query parameters in this version. An empty list returns `200 OK` with
`[]`.

#### Scenario: A valid request returns the person's live expenses

- **WHEN** a `GET /v1/expenses` arrives with a valid Bearer token and the acting person has live expenses
- **THEN** the system responds `200 OK` with an array of the person's live expense read-models, ordered most-recent-first

#### Scenario: No expenses returns an empty array

- **WHEN** a `GET /v1/expenses` arrives with a valid Bearer token and the acting person has no live expenses
- **THEN** the system responds `200 OK` with an empty array `[]`

#### Scenario: Missing or invalid token returns 401

- **WHEN** a `GET /v1/expenses` request carries no valid `Authorization: Bearer <token>` header
- **THEN** the system responds `401` in the unified error envelope before the handler body runs

