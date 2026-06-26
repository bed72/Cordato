## ADDED Requirements

### Requirement: The default budget groups the owner's expenses that fall in no live budget

The system SHALL return, for a given `person_id`, a **default budget ("No budget")** — a read-time view that
groups exactly the owner's **live** expenses whose `occurred_on` is contained by **none** of that person's
**live** budgets' inclusive ranges. It is the complement of the real budgets over the person's ledger.
The view is **derived at read-time and never stored**: there is no row, no entity, no identity — building it
SHALL NOT mutate any expense or budget. An expense's membership is purely date-containment logic, with no
foreign key, consistent with *derive, don't store*.

#### Scenario: An expense outside every live budget lands in the bucket

- **WHEN** a person has a live expense whose day falls within none of their live budgets' ranges
- **THEN** that expense is part of the default budget

#### Scenario: An expense covered by a live budget is excluded

- **WHEN** a person has a live expense whose day falls within a live budget's inclusive range
- **THEN** that expense is **not** part of the default budget

#### Scenario: Boundary days count as covered

- **WHEN** a live expense's day equals the `start_date` or the `end_date` of a live budget (the range is
  inclusive on both ends)
- **THEN** that expense is covered by that budget and is excluded from the default budget

#### Scenario: Membership is evaluated against every live budget

- **WHEN** a person has several non-overlapping live budgets and a live expense falls within one of them
- **THEN** that expense is excluded from the default budget, regardless of how many other budgets exist

### Requirement: The default budget has no limit and no remaining

The system SHALL NOT give the default budget an `amount` (limit) or a `remaining` value. It is a leftover
bucket, not a real budget: it carries only `total_spent` — the exact-decimal sum of exactly the expenses it
groups — and the expenses themselves. This is what distinguishes it from the active budget, which has a
limit and derives `remaining`.

#### Scenario: total_spent is the exact sum of the bucket's expenses

- **WHEN** the default budget groups one or more expenses
- **THEN** its `total_spent` equals the exact-decimal sum of those expenses' amounts

#### Scenario: An empty bucket has zero total

- **WHEN** a person has no live expense outside their live budgets (every expense is covered, or there are
  no expenses)
- **THEN** the default budget is empty and its `total_spent` is zero

### Requirement: The default budget reflects only live data

The system SHALL ignore soft-deleted expenses and soft-deleted budgets when computing the default budget. A
soft-deleted budget no longer covers anything, and a soft-deleted expense is never grouped.

#### Scenario: A soft-deleted expense is never in the bucket

- **WHEN** a person has a soft-deleted expense outside every live budget
- **THEN** that expense does not appear in the default budget

#### Scenario: A soft-deleted budget covers nothing

- **WHEN** an expense's day falls only within the range of a budget that has been soft-deleted
- **THEN** that expense is treated as covered by no budget and lands in the default budget

### Requirement: The default budget reads only the owner's own data

The system SHALL compute the default budget from only the requesting person's own live budgets and live
expenses. The view grants no access to anyone else's data.

#### Scenario: Only the owner's ledger is considered

- **WHEN** a person's default budget is computed while other people own budgets and expenses
- **THEN** only the requester's own live budgets and expenses determine the result

### Requirement: Budgeting reads the ledger across no module boundary

The system SHALL read the owner's expenses into budgeting through a port owned by the `budgeting` context,
stated in budgeting's own vocabulary, and SHALL NOT introduce any dependency from `budgeting` on the
`expenses` module. Because the default bucket needs the individual expenses (not merely a sum), this is a
distinct port from the existing spend reader. The concrete adapter that reads the underlying ledger is wired
at the composition root — the only layer permitted to know both modules.

#### Scenario: Budgeting depends only on its own port

- **WHEN** the default budget is computed
- **THEN** the owner's expenses are obtained through a budgeting-owned reader port, with no import of the
  expenses feature from budgeting's domain or application
