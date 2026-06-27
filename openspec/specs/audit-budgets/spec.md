# audit-budgets Specification

## Purpose
TBD - created by syncing change audit-soft-deleted-budgets-and-expenses. Update Purpose after archive.
## Requirements
### Requirement: A person can audit all their own budgets, live and soft-deleted alike

The system SHALL return, for a given `person_id`, **every** budget that person owns — both live and
soft-deleted — each carrying its own `id`, `person_id`, `amount`, `start_date`, `end_date`, `note`,
`created_at`, and `deleted_at`. This is the explicit audit read; it is the only budget read that crosses the
two-read contract and surfaces `deleted_at != null` rows. It is **read-only** and read at request-time;
producing it SHALL NOT mutate the ledger. Each item carries **no spend**: `total_spent` and `remaining`
belong to the enriched active-budget read, not to the audit listing.

#### Scenario: Both live and soft-deleted budgets are returned

- **WHEN** a person who owns both live and soft-deleted budgets requests their audit listing
- **THEN** the system returns one item per budget — live and soft-deleted alike — each preserving its own amount, range, note, identity, and creation time

#### Scenario: A person with no budgets gets an empty list

- **WHEN** a person who owns no budget at all requests their audit listing
- **THEN** the system returns an empty list

### Requirement: Each audited budget exposes its deletion state

The system SHALL include `deleted_at` on every item: `null` for a live budget, and the soft-delete timestamp
for a removed one. This is what makes a removed budget distinguishable from a live one within the same
listing, fulfilling the "visible in audit" guarantee.

#### Scenario: A live budget carries a null deletion timestamp

- **WHEN** the listing contains a budget that has not been deleted
- **THEN** that item's `deleted_at` is null

#### Scenario: A soft-deleted budget carries its deletion timestamp

- **WHEN** the listing contains a budget that was soft-deleted
- **THEN** that item's `deleted_at` is the timestamp at which it was removed

### Requirement: The audit listing is ordered most-recent-period-first

The system SHALL order the listing by `start_date` descending, breaking ties by `created_at` descending, so
the budget whose period begins most recently appears first — mirroring the live `list-budgets` order. Live
and soft-deleted budgets interleave by this order; deletion state does not reorder them.

#### Scenario: A later-starting budget comes first

- **WHEN** the listing contains budgets with different `start_date` values
- **THEN** the budget with the later `start_date` appears before the earlier one, regardless of deletion state

#### Scenario: Same-start budgets break ties by creation time

- **WHEN** two budgets share the same `start_date`
- **THEN** the one with the later `created_at` appears first

### Requirement: A person audits only their own budgets

The system SHALL return only budgets owned by the requesting `person_id`. The audit read grants no view over
anyone else's budgets; the shared couple view is a separate, read-only capability and does not extend to the
audit trail.

#### Scenario: Another person's budgets are never included

- **WHEN** a person requests their audit listing while other people own budgets, live or soft-deleted
- **THEN** the returned listing contains only the requester's own budgets
