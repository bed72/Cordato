# audit-expenses Specification

## ADDED Requirements

### Requirement: A person can audit all their own expenses, live and soft-deleted alike

The system SHALL return, for a given `person_id`, **every** expense that person owns — both live and
soft-deleted — each carrying its own `id`, `person_id`, `amount`, `occurred_on`, `description`,
`created_at`, and `deleted_at`. This is the explicit audit read; it is the only expense read that crosses the
two-read contract and surfaces `deleted_at != null` rows. It is **read-only** and read at request-time;
producing it SHALL NOT mutate the ledger. Each item carries **no budget reference of any kind** — belonging
to a budget stays a date-range derivation, never a stored link.

#### Scenario: Both live and soft-deleted expenses are returned

- **WHEN** a person who owns both live and soft-deleted expenses requests their audit listing
- **THEN** the system returns one item per expense — live and soft-deleted alike — each preserving its own amount, date, description, identity, and creation time

#### Scenario: A person with no expenses gets an empty list

- **WHEN** a person who owns no expense at all requests their audit listing
- **THEN** the system returns an empty list

### Requirement: Each audited expense exposes its deletion state

The system SHALL include `deleted_at` on every item: `null` for a live expense, and the soft-delete
timestamp for a removed one. This is what makes a removed expense distinguishable from a live one within the
same listing, fulfilling the "visible in audit" guarantee.

#### Scenario: A live expense carries a null deletion timestamp

- **WHEN** the listing contains an expense that has not been deleted
- **THEN** that item's `deleted_at` is null

#### Scenario: A soft-deleted expense carries its deletion timestamp

- **WHEN** the listing contains an expense that was soft-deleted
- **THEN** that item's `deleted_at` is the timestamp at which it was removed

### Requirement: The audit listing is ordered most-recent-first

The system SHALL order the listing by `occurred_on` descending, breaking ties by `created_at` descending, so
the expense that happened most recently appears first — mirroring the live `list-expenses` order. Live and
soft-deleted expenses interleave by this order; deletion state does not reorder them.

#### Scenario: A later-occurring expense comes first

- **WHEN** the listing contains expenses with different `occurred_on` values
- **THEN** the expense with the later `occurred_on` appears before the earlier one, regardless of deletion state

#### Scenario: Same-day expenses break ties by creation time

- **WHEN** two expenses share the same `occurred_on`
- **THEN** the one with the later `created_at` appears first

### Requirement: A person audits only their own expenses

The system SHALL return only expenses owned by the requesting `person_id`. The audit read grants no view over
anyone else's expenses; the shared couple view is a separate, read-only capability and does not extend to the
audit trail.

#### Scenario: Another person's expenses are never included

- **WHEN** a person requests their audit listing while other people own expenses, live or soft-deleted
- **THEN** the returned listing contains only the requester's own expenses
