## ADDED Requirements

### Requirement: Delete budget is reachable over HTTP

The system SHALL expose the existing delete-budget behavior as `DELETE
/v1/budgets/{budget_id}` (the `/v1` version prefix is owned by the composition root). The
endpoint SHALL resolve the acting person via `CurrentPersonProvider`, invoke the existing
`DeleteBudgetUseCase` unchanged, and on success respond `204 No Content` with no body. The
HTTP endpoint SHALL add no business rule. Errors SHALL be framed in the unified error envelope:
a budget not found or not owned returns `404`.

#### Scenario: Valid request soft-deletes the budget and returns 204

- **WHEN** `DELETE /v1/budgets/{budget_id}` is requested with a valid Bearer token and the
  `budget_id` identifies a live budget owned by the acting person
- **THEN** the system responds `204 No Content` with no body and the budget is soft-deleted

#### Scenario: Budget not found or not owned returns 404

- **WHEN** the `budget_id` does not identify a live budget owned by the acting person
- **THEN** the system responds `404` in the unified error envelope and changes nothing

#### Scenario: Unauthenticated request is rejected

- **WHEN** `DELETE /v1/budgets/{budget_id}` is requested without a valid `Authorization:
  Bearer <token>` header
- **THEN** the system responds `401` in the unified error envelope
