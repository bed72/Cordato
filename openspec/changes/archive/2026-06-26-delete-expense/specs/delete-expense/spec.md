## ADDED Requirements

### Requirement: A person can soft-delete one of their own expenses

The system SHALL allow a person to remove one of their **own** expenses by supplying the requester
(`requester_id`) and the target `expense_id`. Removal SHALL be a **soft-delete**: the system stamps the
expense's `deleted_at` with the current instant (obtained from the clock port) and persists it, keeping the
row. The operation SHALL return nothing — its only outcome is the expense's disappearance from normal reads.
The `deleted_at` instant SHALL never be set inside the domain by reading the wall clock directly; it SHALL be
supplied by the use case from the clock port.

#### Scenario: Owner soft-deletes a live expense

- **WHEN** a requester supplies the id of a live expense they own
- **THEN** that expense's `deleted_at` is stamped with the clock's current instant
- **AND** the expense is persisted in that removed state
- **AND** the operation returns nothing

#### Scenario: The removed expense leaves normal reads but survives for audit

- **WHEN** an owner has soft-deleted one of their expenses
- **THEN** that expense no longer appears in the repository's normal reads (it is excluded from `find_in_range`)
- **AND** the expense still appears in the explicit audit read (`list_including_removed`) with its `deleted_at` set

### Requirement: Deleting an expense is authorized by a non-leaking scoped lookup

The system SHALL resolve the target expense **scoped to the requester** — by owner and id together — so that a
person can only ever delete an expense they own. An unknown id, an expense owned by another person, and an
expense that is already soft-deleted SHALL all be indistinguishable to the caller: each SHALL reject with the
same pt-BR, non-leaking `ExpenseNotFoundError` and SHALL change nothing. The resolution SHALL be the first
step, so that a failed authorization pays for no further work, and the error SHALL never reveal whether
another person's expense exists.

#### Scenario: Unknown expense id is rejected

- **WHEN** a requester supplies an id that matches no expense
- **THEN** the system raises `ExpenseNotFoundError`
- **AND** no expense is modified or persisted

#### Scenario: An expense owned by another person is rejected and not leaked

- **WHEN** a requester supplies the id of an expense owned by a different person
- **THEN** the system raises `ExpenseNotFoundError`
- **AND** the message is identical to the unknown-id case (the other person's expense is never revealed)
- **AND** that expense is left untouched, still live

#### Scenario: Re-deleting an already-removed expense is rejected without overwriting

- **WHEN** a requester supplies the id of an expense they own that is already soft-deleted
- **THEN** the system raises `ExpenseNotFoundError` (the scoped lookup returns only live expenses)
- **AND** the expense's original `deleted_at` is left unchanged (never overwritten with a new instant)

### Requirement: Soft-deleting an expense rewires nothing

The system SHALL NOT read, move, or update any budget, any other expense, or any other person's data when
soft-deleting an expense. Because expense→budget belonging is derived by date at read-time and never stored,
the removal SHALL touch only the target expense's `deleted_at`. The owner's active-budget `total_spent` and
`remaining` SHALL reflect the removal on the next read purely because the spend computation already sums only
live expenses — with no stored link to maintain.

#### Scenario: A covering budget's spend recomputes without the deleted expense

- **WHEN** an owner soft-deletes an expense whose date falls within their active budget's range
- **THEN** that expense no longer contributes to the budget's `total_spent`
- **AND** the budget's `remaining` rises by the deleted expense's amount on the next read
- **AND** no budget row was read or written as part of the deletion

#### Scenario: No other person's data is touched

- **WHEN** a requester soft-deletes one of their own expenses
- **THEN** only that requester's expense is modified
- **AND** no expense, budget, or pair belonging to any other person is read or affected
