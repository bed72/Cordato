## MODIFIED Requirements

### Requirement: Create-budget is reachable over HTTP

The system SHALL expose the existing create-budget behavior as `POST /v1/budgets` (the `/v1` version prefix is
owned by the composition root; the controller declares only its bare resource path). The endpoint SHALL accept a
JSON body carrying the budget's `amount`, `start_date`, `end_date`, and optional `note`, bound and validated as a
Pydantic request model; resolve the acting person via the transitional placeholder identity; invoke the existing
create-budget use case unchanged; and, on success, respond `201 Created` with the created budget's read-model
(id, amount, `start_date`, `end_date`, `note`, `created_at`). The HTTP endpoint SHALL add no business rule beyond
the existing domain behavior — it is a transport over the use case, not a second home for the rules. Errors SHALL
be framed in the standard unified error envelope: a malformed body returns `422`, and an overlapping budget
returns `409`.

#### Scenario: A valid request creates a budget

- **WHEN** a `POST /v1/budgets` arrives with a well-formed body
- **THEN** the system responds `201 Created` with the created budget's read-model

#### Scenario: A malformed body returns 422

- **WHEN** a `POST /v1/budgets` body is missing a required field or carries a wrong-typed value (e.g. `amount`
  is a boolean)
- **THEN** the system responds `422` in the unified error envelope with the offending fields, and the
  create-budget use case is not invoked

#### Scenario: An overlapping budget returns 409

- **WHEN** a `POST /v1/budgets` would overlap an existing live budget of the acting person
- **THEN** the system responds `409` in the unified error envelope carrying the domain's generic pt-BR message,
  and persists nothing
