# update-budget Specification

## Purpose
TBD - created by archiving change update-budget. Update Purpose after archive.
## Requirements
### Requirement: A person updates one of their own live budgets in place

The system SHALL let a person update an existing live budget they own, changing its `amount`,
`start_date`, `end_date`, and `note` while preserving the budget's `id` and `created_at`. The update
SHALL be a full replacement of the editable fields — every editable field is supplied by the command
and overwrites the stored value. The budget's identity and lifecycle position are untouched: it stays
live (`deleted_at` remains null) and no new budget is created.

#### Scenario: Owner updates a live budget

- **WHEN** a person submits new values for a live budget they own
- **THEN** the system updates that budget's amount, start_date, end_date and note, keeps its id and
  created_at, and returns the updated budget

#### Scenario: Note is normalized

- **WHEN** the submitted note is blank or surrounding whitespace
- **THEN** the stored note is normalized to absent (no note), consistent with budget creation

### Requirement: Only the owner can update, and the lookup is the authorization

The system SHALL resolve the target as the requester's own live budget — matched by owner and id,
excluding soft-deleted rows — before applying any change. An unknown id, a budget owned by another
person, and an already soft-deleted budget SHALL all be rejected identically with a "budget not found"
error, so the caller can never probe whether someone else's budget exists. The authorization check
SHALL happen before any update is applied.

#### Scenario: Updating an unknown budget is rejected

- **WHEN** the requester references a budget id that does not exist
- **THEN** the system rejects the update with a "budget not found" error and changes nothing

#### Scenario: Updating another person's budget is rejected

- **WHEN** the requester references a live budget owned by someone else
- **THEN** the system rejects the update with the same "budget not found" error, revealing nothing about
  the other person's data

#### Scenario: Updating a soft-deleted budget is rejected

- **WHEN** the requester references a budget they own that is already soft-deleted
- **THEN** the system rejects the update with the same "budget not found" error

### Requirement: The updated range re-validates the non-overlap invariant

The system SHALL re-check, on the updated range, the invariant that two live budgets of the same person
share no date — not even a boundary day. The check SHALL run against the owner's *other* live budgets;
the budget being updated SHALL be excluded from its own check, so re-saving it with the same or an
overlapping-only-with-itself range is allowed. Two inclusive ranges overlap when each starts on or
before the other ends, so a shared boundary day counts as overlap while mere adjacency (one ends the
day before the other starts) does not. On violation the system SHALL reject the update and change nothing.

#### Scenario: Updated range overlaps another live budget

- **WHEN** the new range shares at least one day with another live budget of the same person
- **THEN** the system rejects the update with an "overlapping budget" error and changes nothing

#### Scenario: Updated range is merely adjacent to another live budget

- **WHEN** the new range ends the day before another live budget starts, or starts the day after another ends
- **THEN** the system accepts the update, since adjacent ranges do not overlap

#### Scenario: Re-saving the same budget does not overlap itself

- **WHEN** the requester updates a budget without moving it out of its own current range
- **THEN** the system does not treat the budget as overlapping itself and accepts the update

### Requirement: The updated amount and range re-validate their invariants

The system SHALL re-validate the updated budget's amount and range: the amount MUST be a positive exact
decimal (cents, BRL) and `start_date` MUST NOT be after `end_date`. A non-positive amount SHALL be
rejected with an "invalid amount" error and an inverted range with an "invalid range" error. These
invariants hold for an update exactly as they do at creation.

#### Scenario: Updated amount is not positive

- **WHEN** the submitted amount is zero or negative
- **THEN** the system rejects the update with an "invalid amount" error and changes nothing

#### Scenario: Updated range is inverted

- **WHEN** the submitted start_date is after the submitted end_date
- **THEN** the system rejects the update with an "invalid range" error and changes nothing

### Requirement: Updating a budget touches no expense

The system SHALL NOT modify, relink, or delete any expense as part of updating a budget. Expense→budget
belonging is derived from dates at read-time with no stored link, so changing a budget's range only
changes which expenses fall under it on the next read. Expenses that leave the updated range SHALL
simply fall to the default ("No budget") bucket on the next read, and expenses that enter it SHALL be
summed into its derived spend — all without any stored rewiring.

#### Scenario: Narrowing the range drops expenses to the default bucket

- **WHEN** a budget's range is narrowed so some previously-covered expenses no longer fall within it
- **THEN** those expenses are unchanged in storage and, on the next read, are grouped under the default
  budget instead of this one

#### Scenario: Widening the range pulls expenses into the budget's spend

- **WHEN** a budget's range is widened to cover expenses it did not before
- **THEN** those expenses are unchanged in storage and, on the next read, are counted in this budget's
  derived total_spent

