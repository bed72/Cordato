# Test Supabase Authorization And Invariants

## Status

Archived. The database test suite is implemented, but its execution remains
pending until a disposable Supabase test environment is available. Do not run
the reset-and-test workflow against the Coolify instance with real data.

## Objective

Prove the Supabase authorization model and database invariants with real database integration tests. Mobile mocks
are insufficient evidence that RLS, authenticated RPCs, constraints, and couple read sharing behave safely.

## Scope

- Add a repeatable integration-test harness against a clean local Supabase environment provisioned from tracked
  migrations.
- Execute authorization scenarios with at least two distinct authenticated users and an unauthenticated actor.
- Test table/RPC authorization for profiles and each implemented financial context.
- Test expense, budget, and couple invariants at the database boundary as their migrations and RPCs are added.
- Make the suite fail when a migration, policy, grant, function, or constraint weakens the documented behavior.

## Non-goals

- Do not replace Flutter unit tests, widget tests, or manual visual testing.
- Do not test against production data or use production credentials.
- Do not implement CI, idempotency, offline behavior, retries, telemetry, or client-generated database types.
- Do not claim a feature is authorized until its migrations and RPCs exist in the local test environment.

## Requirements

### Requirement: Authorization tests use isolated real actors
The integration suite SHALL create or impersonate separate authenticated principals for at least owner A, owner B,
simulating authorization only through mocks.

#### Acceptance scenarios

- **WHEN** the suite executes an owner-only read or mutation as owner A
- **THEN** the database SHALL evaluate it using owner A's authenticated identity

- **WHEN** the suite executes the same operation as owner B or without authentication
- **THEN** it SHALL assert the database's actual denied or permitted outcome

- **WHEN** the suite finishes
- **THEN** its data SHALL be isolated from other tests and shall not require a shared remote environment

### Requirement: Individually owned records reject cross-user access
For every implemented owner-scoped table and mutation RPC, tests SHALL prove that the owner can perform the
documented operation and another authenticated user cannot read, write, update, or delete the owner's record
outside an explicitly permitted read-only couple projection.

#### Acceptance scenarios

- **WHEN** owner A creates an individually owned profile, expense, or budget record
- **THEN** owner A SHALL receive the documented permitted result

- **WHEN** owner B directly reads or mutates owner A's individually owned record
- **THEN** the database SHALL not disclose or alter the record

- **WHEN** a client attempts to impersonate owner A by supplying A's identifier in a request
- **THEN** the database SHALL continue to authorize from the JWT actor and deny unauthorized access

### Requirement: Financial invariants are tested at the database boundary
The suite SHALL verify the database behavior for monetary values, civil dates, budget ranges, and expense-to-budget
derivation once the associated schema and RPCs exist. Tests SHALL include concurrent conflict behavior where an
invariant depends on competing writes.

#### Acceptance scenarios

- **WHEN** a financial mutation contains a zero or negative amount, invalid date, or invalid date range
- **THEN** the database SHALL reject it without persisting a partial state

- **WHEN** one owner attempts to create or edit a live budget that overlaps another live budget
- **THEN** the database SHALL reject the overlap while allowing the same date range for a different owner

- **WHEN** concurrent requests attempt incompatible budget ranges for one owner
- **THEN** the resulting database state SHALL contain no overlapping live budgets

- **WHEN** an expense is queried in a budget projection
- **THEN** its membership SHALL be derived from its civil date and SHALL not rely on a persisted budget foreign key

### Requirement: Couple sharing is read-only and reversible
Once couple RPCs and projections exist, the suite SHALL prove that a valid pair can obtain only the documented
combined read view. It SHALL prove that pairing does not grant cross-user financial writes and that dissolution
removes sharing without deleting individual history.

#### Acceptance scenarios

- **WHEN** two eligible users establish a valid couple relationship
- **THEN** each user SHALL receive the documented combined read projection without gaining write permission over
  the other user's records

- **WHEN** a user attempts to accept an invalid, expired, self-issued, or consumed invitation
- **THEN** no couple relationship or duplicate membership SHALL be created

- **WHEN** the relationship is dissolved
- **THEN** the combined read permission SHALL be removed and both users' individual records SHALL remain intact

### Requirement: Database policy regressions block backend changes
The integration suite SHALL run against migrations from a clean state and SHALL be required for changes to
tables, RLS policies, grants, triggers, financial RPCs, or couple projections.

#### Acceptance scenarios

- **WHEN** a schema change alters an authorization or invariant boundary
- **THEN** the affected integration scenario SHALL be added or updated in the same change

- **WHEN** a policy or function change permits an unauthorized cross-user operation
- **THEN** the integration suite SHALL fail before the change is accepted

## Dependencies

- `specs/version-supabase-backend.md` must be implemented first.
- `specs/move-financial-mutations-to-rpcs.md` must be implemented before financial RPC scenarios.

## Verification

- Provision a clean local Supabase database from migrations before the suite.
- Run owner A, owner B, and unauthenticated cases for every implemented protected boundary.
- Run concurrent budget-conflict scenarios after the budget RPC exists.
- Confirm the suite does not read production settings or credentials.
