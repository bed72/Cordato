## ADDED Requirements

### Requirement: Create-budget is reachable over HTTP

The system SHALL expose the existing create-budget behavior as `POST /v1/budgets` (the `/v1` version prefix is
owned by the composition root; the controller declares only its bare resource path). The endpoint SHALL accept a
JSON body carrying the budget's `amount`, `start_date`, `end_date`, and optional `note`, bound and validated as a
Pydantic request model; resolve the acting person via the transitional placeholder identity; invoke the existing
create-budget use case unchanged; and, on success, respond `201 Created` with the created budget's read-model
(id, amount, `start_date`, `end_date`, `note`, `created_at`). The HTTP endpoint SHALL add no business rule
beyond the existing domain behavior — it is a transport over the use case, not a second home for the rules.

> The framing of domain errors raised by the use case (e.g. an overlapping budget → 409) is owned by the
> separate domain-error→HTTP-status mapping change; until it lands, such errors are not yet framed here.

#### Scenario: A valid request creates a budget

- **WHEN** a `POST /v1/budgets` arrives with a well-formed body
- **THEN** the system responds `201 Created` with the created budget's read-model

#### Scenario: A malformed body is rejected before the use case

- **WHEN** a `POST /v1/budgets` body is missing a required field or carries a wrong-typed value
- **THEN** the system rejects it at the boundary and the create-budget use case is not invoked
