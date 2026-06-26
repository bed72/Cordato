# list-budgets Specification

## ADDED Requirements

### Requirement: A person can list their own live budgets

The system SHALL return, for a given `person_id`, that person's **live** budgets — each carrying its own
`id`, `person_id`, `amount`, `start_date`, `end_date`, `note`, and `created_at`. The list is **read-only**
and read at request-time; producing it SHALL NOT mutate the ledger. Each item carries **no spend**:
`total_spent` and `remaining` belong to the enriched active-budget read, not to this list.

#### Scenario: The person's budgets are returned

- **WHEN** a person who owns live budgets requests their list
- **THEN** the system returns one item per live budget, each preserving its own amount, range, note, and identity

#### Scenario: A person with no budgets gets an empty list

- **WHEN** a person who owns no live budget requests their list
- **THEN** the system returns an empty list

### Requirement: Soft-deleted budgets are excluded from the list

The system SHALL exclude any budget whose `deleted_at` is set. The day-to-day list is a normal read, so it
follows the two-read contract: only the explicit audit read (`list_including_removed`) ever sees
soft-deleted rows.

#### Scenario: A soft-deleted budget does not appear

- **WHEN** a person has both live and soft-deleted budgets
- **THEN** the returned list contains only the live ones

### Requirement: The list is ordered most-recent-period-first

The system SHALL order the list by `start_date` descending, breaking ties by `created_at` descending, so
the budget whose period begins most recently appears first. This mirrors `list-expenses`'
most-recent-first contract.

#### Scenario: A later-starting budget comes first

- **WHEN** the list contains budgets with different `start_date` values
- **THEN** the budget with the later `start_date` appears before the earlier one

#### Scenario: Same-start budgets break ties by creation time

- **WHEN** two budgets share the same `start_date`
- **THEN** the one with the later `created_at` appears first

### Requirement: A person lists only their own budgets

The system SHALL return only budgets owned by the requesting `person_id`. Listing grants no view over
anyone else's budgets; the shared couple view is a separate, explicit capability.

#### Scenario: Another person's budgets are never included

- **WHEN** a person requests their list while other people own budgets
- **THEN** the returned list contains only the requester's own budgets
