## ADDED Requirements

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
