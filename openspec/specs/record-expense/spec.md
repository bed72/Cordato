# record-expense Specification

## Purpose
TBD - created by archiving change record-expense. Update Purpose after archive.
## Requirements
### Requirement: Record a new expense

The system SHALL record a new expense from an owner reference (`person_id`), an amount, a date, and an
optional description, creating an Expense with an opaque `id`, a `created_at` timestamp, and a live state
(`deleted_at = null`). On success the system SHALL return the expense's public data — `id`, `person_id`,
`amount`, `occurred_on`, `description`, `created_at`.

#### Scenario: Successful recording

- **WHEN** an expense is requested with a valid owner reference, a positive amount, a valid date, and a
  description (present or absent)
- **THEN** a new Expense is created with an assigned `id` and `created_at`, `deleted_at = null`, and the
  expense's public data is returned

### Requirement: An expense holds no reference to a budget

The system SHALL store on an expense only its owner (`person_id`), amount, date, and optional
description. The system SHALL NOT store on an expense any reference, identifier, or link to a budget;
belonging to a budget is derived at read-time from the expense's date and is never persisted.

#### Scenario: No budget link is stored

- **WHEN** an expense is recorded
- **THEN** the persisted expense exposes its owner, amount, date, and description but carries no budget
  identifier or budget reference of any kind

### Requirement: Amount is exact-decimal, centavo-precise money

The system SHALL treat every amount as exact decimal money in BRL with at most two decimal places
(centavos) and SHALL never represent it as a binary floating-point number. The system SHALL reject an
amount that is not a finite decimal or that carries more than two decimal places, without creating an
expense.

#### Scenario: A non-finite or over-precise amount is rejected

- **WHEN** an expense is requested with an amount that is not finite (e.g. NaN/Infinity) or that has more
  than two decimal places (e.g. `10.005`)
- **THEN** the recording is rejected with an invalid-money error and no expense is created

#### Scenario: A centavo-precise amount is preserved exactly

- **WHEN** an expense is recorded with an amount such as `19.90`
- **THEN** the stored and returned amount equals `19.90` exactly, with no rounding drift

### Requirement: Amount must be greater than zero

The system SHALL reject an expense whose amount is zero or negative, without creating an expense. An
expense represents a spend that happened, so a non-positive amount is meaningless.

#### Scenario: A non-positive amount is rejected

- **WHEN** an expense is requested with an amount of `0` or a negative amount
- **THEN** the recording is rejected with an invalid-amount error and no expense is created

### Requirement: Date is a pure date

The system SHALL record the expense's day — the `occurred_on` field — as a calendar date with no
time-of-day component. It is the day the spend happened and is the sole basis for any later
budget-belonging derivation.

#### Scenario: The date is stored without a time component

- **WHEN** an expense is recorded for a given day
- **THEN** the stored and returned `occurred_on` is exactly that calendar day, carrying no time-of-day or timezone

### Requirement: Description is optional and normalized

The system SHALL accept an optional description as free text. The system SHALL trim surrounding
whitespace, and a description that is empty or whitespace-only SHALL be stored as absent (no
description). A description is not required to record an expense.

#### Scenario: A blank description becomes absent

- **WHEN** an expense is recorded with a description that is empty or only whitespace
- **THEN** the expense is created with no description

#### Scenario: A present description is trimmed and kept

- **WHEN** an expense is recorded with a description surrounded by whitespace (e.g. `"  almoço  "`)
- **THEN** the expense is created with the trimmed description (e.g. `"almoço"`)

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

