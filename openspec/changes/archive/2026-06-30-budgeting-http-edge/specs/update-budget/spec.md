## ADDED Requirements

### Requirement: Update budget is reachable over HTTP

The system SHALL expose the existing update-budget behavior as `PATCH /v1/budgets/{budget_id}`
(the `/v1` version prefix is owned by the composition root). The endpoint SHALL resolve the
acting person via `CurrentPersonProvider`, bind and validate a JSON body carrying `amount`,
`start_date`, `end_date`, and optional `note` as a Pydantic request model, invoke the existing
`UpdateBudgetUseCase` unchanged, and on success respond `200 OK` with the updated budget's
read-model (`id`, `person_id`, `amount`, `start_date`, `end_date`, `note`, `created_at`).
Despite using the `PATCH` verb, the semantics are full replacement of all editable fields —
clients must always supply `amount`, `start_date`, and `end_date`. The HTTP endpoint SHALL
add no business rule. Errors SHALL be framed in the unified error envelope: a malformed body
returns `422`, a budget not found or not owned returns `404`, and an overlapping range returns
`409`.

#### Scenario: Valid request updates the budget and returns 200

- **WHEN** `PATCH /v1/budgets/{budget_id}` is requested with a valid Bearer token and a
  well-formed body for a live budget the person owns
- **THEN** the system responds `200 OK` with the updated budget's read-model

#### Scenario: Malformed body returns 422

- **WHEN** the request body is missing a required field or carries a value of the wrong type
- **THEN** the system responds `422` in the unified error envelope with the offending fields,
  and the use case is not invoked

#### Scenario: Budget not found or not owned returns 404

- **WHEN** the `budget_id` does not identify a live budget owned by the acting person
- **THEN** the system responds `404` in the unified error envelope and changes nothing

#### Scenario: Overlapping range returns 409

- **WHEN** the new range shares at least one day with another live budget of the acting person
- **THEN** the system responds `409` in the unified error envelope and changes nothing

#### Scenario: Unauthenticated request is rejected

- **WHEN** `PATCH /v1/budgets/{budget_id}` is requested without a valid `Authorization:
  Bearer <token>` header
- **THEN** the system responds `401` in the unified error envelope
