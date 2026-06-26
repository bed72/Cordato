# update-expense Specification

## Purpose
TBD - created by archiving change update-expense. Update Purpose after archive.
## Requirements
### Requirement: A person updates one of their own live expenses in place

The system SHALL let a person update an existing live expense they own, changing its `amount`,
`occurred_on`, and `description` while preserving the expense's `id` and `created_at`. The update SHALL
be a full replacement of the editable fields — every editable field is supplied by the command and
overwrites the stored value. The expense's identity and lifecycle position are untouched: it stays
live (`deleted_at` remains null) and no new expense is created.

#### Scenario: Owner updates a live expense

- **WHEN** a person submits new values for a live expense they own
- **THEN** the system updates that expense's amount, occurred_on and description, keeps its id and
  created_at, and returns the updated expense

#### Scenario: Description is normalized

- **WHEN** the submitted description is blank or surrounding whitespace
- **THEN** the stored description is normalized to absent (no description), consistent with expense
  recording

### Requirement: Only the owner can update, and the lookup is the authorization

The system SHALL resolve the target as the requester's own live expense — matched by owner and id,
excluding soft-deleted rows — before applying any change. An unknown id, an expense owned by another
person, and an already soft-deleted expense SHALL all be rejected identically with an "expense not
found" error, so the caller can never probe whether someone else's expense exists. The authorization
check SHALL happen before any update is applied.

#### Scenario: Updating an unknown expense is rejected

- **WHEN** the requester references an expense id that does not exist
- **THEN** the system rejects the update with an "expense not found" error and changes nothing

#### Scenario: Updating another person's expense is rejected

- **WHEN** the requester references a live expense owned by someone else
- **THEN** the system rejects the update with the same "expense not found" error, revealing nothing about
  the other person's data

#### Scenario: Updating a soft-deleted expense is rejected

- **WHEN** the requester references an expense they own that is already soft-deleted
- **THEN** the system rejects the update with the same "expense not found" error

### Requirement: The updated amount re-validates its invariant

The system SHALL re-validate the updated expense's amount: the amount MUST be a positive exact decimal
(cents, BRL). A non-positive amount SHALL be rejected with an "invalid amount" error. This invariant
holds for an update exactly as it does at recording. An expense carries no date range, so there is no
range or non-overlap invariant to re-check.

#### Scenario: Updated amount is not positive

- **WHEN** the submitted amount is zero or negative
- **THEN** the system rejects the update with an "invalid amount" error and changes nothing

### Requirement: Updating an expense touches no budget

The system SHALL NOT modify, relink, or delete any budget as part of updating an expense. Expense→budget
belonging is derived from `occurred_on` at read-time with no stored link, so changing an expense's day
or amount only changes which budget it falls under, and how much that budget shows as spent, on the next
read. No budget is rewired, and no other expense is affected.

#### Scenario: Moving an expense's day regroups it under another budget

- **WHEN** an expense's `occurred_on` is changed so it now falls within a different budget's range (or
  into the default "No budget" bucket)
- **THEN** no budget is modified in storage and, on the next read, the expense is grouped under whichever
  budget contains its new day, its amount summed into that budget's derived total_spent

#### Scenario: Changing an expense's amount recomputes its budget's spend

- **WHEN** an expense's amount is updated while its day still falls within the same budget's range
- **THEN** no budget is modified in storage and, on the next read, that budget's derived total_spent
  reflects the new amount

