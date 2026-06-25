## ADDED Requirements

### Requirement: A person can register an individual budget

The system SHALL let a person create a budget that belongs to exactly that person, carrying an exact-decimal
`amount` in BRL, an inclusive `start_date` and `end_date` (date only — no time), and an optional `note`. The
created budget SHALL be assigned an opaque identity and a timezone-aware `created_at`, both supplied by the
determinism ports — never generated inside the domain. A budget SHALL be born live (`deleted_at = null`); it
holds no list of expenses, because spend is derived, not stored.

#### Scenario: Budget is created with valid data

- **WHEN** a person registers a budget with a positive amount and a `start_date` on or before its `end_date`
- **THEN** the system persists a live budget owned by that person and returns its read-model carrying the id,
  `person_id`, amount, `start_date`, `end_date`, `note`, and `created_at`

#### Scenario: Note is optional and normalized

- **WHEN** a person registers a budget with no note, or a note that is blank or surrounded by whitespace
- **THEN** the stored `note` is `null` when absent or blank, and trimmed of surrounding whitespace otherwise

### Requirement: A budget's date range must be well-formed

The system SHALL reject a budget whose `start_date` falls after its `end_date`. Both ends are inclusive, so a
single-day budget (`start_date == end_date`) is valid. The amount SHALL be an exact decimal precise to the
centavo; a non-positive amount SHALL be rejected.

#### Scenario: Start after end is rejected

- **WHEN** a person attempts to register a budget whose `start_date` is later than its `end_date`
- **THEN** the system rejects it with a domain error and persists nothing

#### Scenario: Single-day budget is accepted

- **WHEN** a person registers a budget whose `start_date` equals its `end_date`
- **THEN** the system accepts it as a valid one-day budget

#### Scenario: Non-positive amount is rejected

- **WHEN** a person attempts to register a budget with an amount of zero or less
- **THEN** the system rejects it with a domain error and persists nothing

### Requirement: A person's live budgets must not overlap in time

The system SHALL guarantee that no two *live* budgets of the same person share any date, not even a single
boundary day. Before creating a budget, the system SHALL check the new range against every existing live budget
of that person; if any date is shared, creation SHALL be rejected with a domain error and nothing persisted.
Soft-deleted budgets SHALL be ignored by this check, and budgets of other people SHALL never constrain it.

#### Scenario: Adjacent ranges are allowed

- **WHEN** a person has a live budget ending on a given day and registers another starting on the very next day
- **THEN** the system accepts the new budget, because the ranges touch but share no date

#### Scenario: Overlapping ranges are rejected

- **WHEN** a person registers a budget whose range shares one or more dates with an existing live budget of
  theirs — including sharing only the boundary day
- **THEN** the system rejects it with a domain error and persists nothing

#### Scenario: A soft-deleted budget does not block a new one

- **WHEN** a person registers a budget over a range that overlaps only a soft-deleted budget of theirs
- **THEN** the system accepts the new budget, because dissolved budgets are excluded from the check

#### Scenario: Another person's budget never constrains

- **WHEN** a person registers a budget over a range that overlaps a budget owned by a different person
- **THEN** the system accepts it, because the non-overlap invariant is per-person
