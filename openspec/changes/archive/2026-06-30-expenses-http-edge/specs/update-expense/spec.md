## ADDED Requirements

### Requirement: Update-expense is reachable over HTTP

The system SHALL expose the existing update-expense behavior as
`PATCH /v1/expenses/{expense_id}`. Despite using `PATCH`, the semantics are **full replacement** of
all editable fields — consistent with `UpdateExpenseUseCase`, which overwrites `amount`, `occurred_on`,
and `description` atomically. The endpoint SHALL accept a JSON body carrying `amount`, `occurred_on`,
and optional `description`; resolve the acting person via `current_person_provider`; invoke
`UpdateExpenseUseCase` with the resolved person as `requester_id` and the path parameter as
`expense_id`; and, on success, respond `200 OK` with the updated expense's read-model. Errors SHALL be
framed in the standard unified error envelope.

#### Scenario: A valid request updates the expense

- **WHEN** a `PATCH /v1/expenses/{expense_id}` arrives with a well-formed body and a valid Bearer token for the expense's owner
- **THEN** the system responds `200 OK` with the updated expense's read-model

#### Scenario: Unknown or foreign expense returns 404

- **WHEN** the `expense_id` does not exist, belongs to another person, or is already soft-deleted
- **THEN** the system responds `404` in the unified error envelope, revealing nothing about other persons' data

#### Scenario: A non-positive amount returns 422

- **WHEN** the `amount` in the body is zero or negative
- **THEN** the system responds `422` in the unified error envelope and the expense is unchanged

#### Scenario: A malformed body returns 422

- **WHEN** a `PATCH /v1/expenses/{expense_id}` body is missing a required field or carries a wrong-typed value
- **THEN** the system responds `422` in the unified error envelope and the use case is not invoked

#### Scenario: Missing or invalid token returns 401

- **WHEN** a `PATCH /v1/expenses/{expense_id}` request carries no valid `Authorization: Bearer <token>` header
- **THEN** the system responds `401` in the unified error envelope before the handler body runs
