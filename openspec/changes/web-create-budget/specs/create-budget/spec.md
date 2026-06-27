## ADDED Requirements

### Requirement: Create-budget is reachable over HTTP

The system SHALL expose the existing create-budget behavior as `POST /budgets`. The endpoint SHALL accept a
JSON body carrying the budget's `amount`, `start_date`, `end_date`, and optional `note`, validated as a Pydantic
request model; resolve the acting person via the transitional identity mechanism; invoke the existing
create-budget use case unchanged; and, on success, respond `201 Created` with the created budget's read-model
(id, `person_id`, amount, `start_date`, `end_date`, `note`, `created_at`). Domain errors raised by the use case
SHALL be framed by the standard domain-error→HTTP-status mapping. The HTTP endpoint SHALL add no business rule
beyond the existing domain behavior — it is a transport over the use case, not a second home for the rules.

#### Scenario: A valid request creates a budget

- **WHEN** a `POST /budgets` arrives with a well-formed body and a valid acting person
- **THEN** the system responds `201 Created` with the created budget's read-model

#### Scenario: An overlapping budget is rejected over HTTP

- **WHEN** a `POST /budgets` would overlap an existing live budget of the acting person
- **THEN** the system responds `409` per the error mapping and persists nothing

#### Scenario: A malformed body is rejected before the use case

- **WHEN** a `POST /budgets` body is missing a required field or carries a wrong-typed value
- **THEN** the system responds `422` with validation details and the create-budget use case is not invoked
