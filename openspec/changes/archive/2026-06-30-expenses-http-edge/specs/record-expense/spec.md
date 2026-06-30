## ADDED Requirements

### Requirement: Record-expense is reachable over HTTP

The system SHALL expose the existing record-expense behavior as `POST /v1/expenses` (the `/v1` prefix is
owned by the composition root; the controller declares only its bare resource path `/expenses`). The
endpoint SHALL accept a JSON body carrying `amount`, `occurred_on`, and optional `description`, bound and
validated as a Pydantic request model; resolve the acting person from the `Authorization: Bearer <token>`
header via `current_person_provider`; invoke the existing `CreateExpenseUseCase` unchanged; and, on
success, respond `201 Created` with the created expense's read-model (`id`, `person_id`, `amount`,
`occurred_on`, `description`, `created_at`). The HTTP endpoint SHALL add no business rule — it is a
transport over the use case. Errors SHALL be framed in the standard unified error envelope.

#### Scenario: A valid request records an expense

- **WHEN** a `POST /v1/expenses` arrives with a well-formed body and a valid Bearer token
- **THEN** the system responds `201 Created` with the created expense's read-model

#### Scenario: A malformed body returns 422

- **WHEN** a `POST /v1/expenses` body is missing a required field or carries a wrong-typed value
- **THEN** the system responds `422` in the unified error envelope with the offending fields, and the use case is not invoked

#### Scenario: A non-positive amount returns 422

- **WHEN** a `POST /v1/expenses` body carries a zero or negative `amount`
- **THEN** the system responds `422` in the unified error envelope and no expense is created

#### Scenario: Missing or invalid token returns 401

- **WHEN** a `POST /v1/expenses` request carries no valid `Authorization: Bearer <token>` header
- **THEN** the system responds `401` in the unified error envelope before the handler body runs
