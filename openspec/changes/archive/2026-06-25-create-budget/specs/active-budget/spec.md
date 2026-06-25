## ADDED Requirements

### Requirement: A person's active budget is derived for a given day

The system SHALL compute a person's active budget at read-time as the person's single live budget whose
inclusive date range contains a given reference day. This association SHALL be derived, never stored: it is
recomputed on each read from the budgets' own date fields. If no live budget contains the day, the system SHALL
report that the person has no active budget for that day (no row is fabricated by this capability). Because live
budgets of a person never overlap, at most one budget can match — the result is unambiguous.

#### Scenario: A budget containing the day is active

- **WHEN** a person has a live budget whose range contains the reference day
- **THEN** the system returns that budget as the active one, enriched with its derived totals

#### Scenario: No budget contains the day

- **WHEN** none of a person's live budgets contains the reference day
- **THEN** the system reports no active budget for that day

#### Scenario: Soft-deleted budgets are never active

- **WHEN** the only budget whose range contains the day is soft-deleted
- **THEN** the system reports no active budget for that day

### Requirement: The active budget is enriched with derived spend

The system SHALL enrich the active budget with `total_spent` and `remaining`, both computed at read-time and
never stored. `total_spent` SHALL be the sum of the owner's expenses whose date falls within the budget's
inclusive range; `remaining` SHALL be `amount − total_spent`. Spend SHALL be obtained by querying expenses over
the date range with no foreign key from expense to budget — belonging is purely date-range. Soft-deleted
expenses SHALL be excluded from the sum, and only the budget owner's expenses SHALL be counted.

#### Scenario: Total spent sums expenses in range

- **WHEN** the owner has expenses dated within the active budget's range
- **THEN** `total_spent` equals the sum of those expenses' amounts and `remaining` equals `amount − total_spent`

#### Scenario: Expenses outside the range are excluded

- **WHEN** the owner has expenses dated before the budget's `start_date` or after its `end_date`
- **THEN** those expenses are not counted in `total_spent`

#### Scenario: Remaining goes negative when overspent

- **WHEN** the owner's expenses within the range sum to more than the budget amount
- **THEN** `remaining` is the negative difference, reported exactly (never clamped to zero)

#### Scenario: A budget with no expenses spends nothing

- **WHEN** the owner has no expenses within the active budget's range
- **THEN** `total_spent` is zero and `remaining` equals the full budget amount
