## ADDED Requirements

### Requirement: Delete-expense is reachable over HTTP

The system SHALL expose the existing delete-expense behavior as
`DELETE /v1/expenses/{expense_id}`. The endpoint SHALL resolve the acting person via
`current_person_provider`; invoke `DeleteExpenseUseCase` with the resolved person as
`requester_id` and the path parameter as `expense_id`; and, on success, respond
`204 No Content` with no body. Errors SHALL be framed in the standard unified error envelope.

#### Scenario: A valid request soft-deletes the expense

- **WHEN** a `DELETE /v1/expenses/{expense_id}` arrives with a valid Bearer token for the expense's owner
- **THEN** the system responds `204 No Content` with no body, and the expense no longer appears in normal reads

#### Scenario: Unknown or foreign expense returns 404

- **WHEN** the `expense_id` does not exist, belongs to another person, or is already soft-deleted
- **THEN** the system responds `404` in the unified error envelope, revealing nothing about other persons' data

#### Scenario: Missing or invalid token returns 401

- **WHEN** a `DELETE /v1/expenses/{expense_id}` request carries no valid `Authorization: Bearer <token>` header
- **THEN** the system responds `401` in the unified error envelope before the handler body runs
