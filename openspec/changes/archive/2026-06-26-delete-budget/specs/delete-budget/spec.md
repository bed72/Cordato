## ADDED Requirements

### Requirement: A person can soft-delete one of their own budgets

The system SHALL allow a person to remove one of their **own** budgets by supplying the requester
(`requester_id`) and the target `budget_id`. Removal SHALL be a **soft-delete**: the system stamps the
budget's `deleted_at` with the current instant (obtained from the clock port) and persists it, keeping the
row. The operation SHALL return nothing — its only outcome is the budget's disappearance from normal reads.
The `deleted_at` instant SHALL never be set inside the domain by reading the wall clock directly; it SHALL be
supplied by the use case from the clock port.

#### Scenario: Owner soft-deletes a live budget

- **WHEN** a requester supplies the id of a live budget they own
- **THEN** that budget's `deleted_at` is stamped with the clock's current instant
- **AND** the budget is persisted in that removed state
- **AND** the operation returns nothing

#### Scenario: The removed budget leaves normal reads but survives for audit

- **WHEN** an owner has soft-deleted one of their budgets
- **THEN** that budget no longer appears in the repository's normal reads (it is excluded from
  `list_live_for_person` and `find_active_for_person`)
- **AND** the budget still appears in the explicit audit read (`list_including_removed`) with its `deleted_at`
  set

### Requirement: Deleting a budget is authorized by a non-leaking scoped lookup

The system SHALL resolve the target budget **scoped to the requester** — by owner and id together — so that a
person can only ever delete a budget they own. An unknown id, a budget owned by another person, and a budget
that is already soft-deleted SHALL all be indistinguishable to the caller: each SHALL reject with the same
pt-BR, non-leaking `BudgetNotFoundError` and SHALL change nothing. The resolution SHALL be the first step, so
that a failed authorization pays for no further work, and the error SHALL never reveal whether another
person's budget exists.

#### Scenario: Unknown budget id is rejected

- **WHEN** a requester supplies an id that matches no budget
- **THEN** the system raises `BudgetNotFoundError`
- **AND** no budget is modified or persisted

#### Scenario: A budget owned by another person is rejected and not leaked

- **WHEN** a requester supplies the id of a budget owned by a different person
- **THEN** the system raises `BudgetNotFoundError`
- **AND** the message is identical to the unknown-id case (the other person's budget is never revealed)
- **AND** that budget is left untouched, still live

#### Scenario: Re-deleting an already-removed budget is rejected without overwriting

- **WHEN** a requester supplies the id of a budget they own that is already soft-deleted
- **THEN** the system raises `BudgetNotFoundError` (the scoped lookup returns only live budgets)
- **AND** the budget's original `deleted_at` is left unchanged (never overwritten with a new instant)

### Requirement: Soft-deleting a budget rewires nothing

The system SHALL NOT read, move, or update any expense, any other budget, or any other person's data when
soft-deleting a budget. Because the active-budget derivation and the non-overlap invariant both consider only
live budgets, and expense→budget belonging is derived by date at read-time and never stored, the removal SHALL
touch only the target budget's `deleted_at`. The freed date range SHALL reopen — a new budget may then be
created over the dates the deleted one occupied — and the expenses that fell inside SHALL re-resolve to the
default "No budget" bucket on the next read, with no stored link to maintain.

#### Scenario: The deleted budget's date range reopens for a new budget

- **WHEN** an owner soft-deletes a budget
- **THEN** that budget no longer participates in the non-overlap check (it is excluded from
  `list_live_for_person`)
- **AND** a new budget may be created over the same dates the deleted budget occupied, without an overlap
  conflict

#### Scenario: A day covered by the deleted budget has no active budget

- **WHEN** an owner soft-deletes the budget whose range contains a given day
- **THEN** `find_active_for_person` returns no active budget for that day
- **AND** the owner's expenses on that day re-resolve to the default "No budget" bucket on the next read
- **AND** no expense was read or written as part of the deletion

#### Scenario: No other person's data is touched

- **WHEN** a requester soft-deletes one of their own budgets
- **THEN** only that requester's budget is modified
- **AND** no budget, expense, or pair belonging to any other person is read or affected
