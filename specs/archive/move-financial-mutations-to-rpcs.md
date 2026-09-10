# Move Financial Mutations To RPCs

## Status

 Implemented

## Objective

Move invariant-sensitive financial writes from Flutter-managed table mutations to authenticated PostgreSQL RPCs.
The database must execute each mutation atomically and remain the authority for ownership and financial rules.

## Scope

- Define authenticated RPC contracts for creating, editing, and removing an expense.
- Define authenticated RPC contracts for creating, editing, and removing a budget.
- Define authenticated RPC contracts for issuing, accepting, and dissolving a couple pairing when the `couple`
  context is implemented.
- Replace direct financial `.insert`, `.update`, and `.delete` calls in Flutter infrastructure adapters with the
  relevant RPC invocation.
- Map expected database failures to existing or new bounded-context failures without exposing provider errors to
  presentation.

## Non-goals

- Do not implement idempotency, background retry, offline queues, cache, generated database types, or analytics.
- Do not turn read queries or derived views into Edge Functions.
- Do not add a client-supplied owner identifier, a persisted `budget_id` on expenses, or shared financial
  ownership for a couple.
- Do not define UI, pagination, categorization, or insight features beyond the write boundaries required here.

## Requirements

### Requirement: Financial mutations use authenticated RPC boundaries
All create, edit, and removal operations for expenses and budgets SHALL invoke an authenticated database RPC.
Flutter infrastructure SHALL not perform direct table writes for those financial records.

#### Acceptance scenarios

- **WHEN** an authenticated user creates, edits, or removes an expense
- **THEN** the Flutter adapter SHALL invoke the corresponding RPC and use its returned result or expected failure

- **WHEN** an authenticated user creates, edits, or removes a budget
- **THEN** the Flutter adapter SHALL invoke the corresponding RPC and use its returned result or expected failure

- **WHEN** a future adapter attempts a direct write to a financial table
- **THEN** architecture review and tests SHALL reject the implementation in favor of the approved RPC boundary

### Requirement: Individual ownership is derived from authentication
Each financial mutation RPC SHALL resolve the actor through `auth.uid()` and SHALL create or modify only records
owned by that actor. The RPC contract SHALL not accept an owner identifier that can grant authority over another
person's data.

#### Acceptance scenarios

- **WHEN** a user creates a financial record
- **THEN** the database SHALL assign ownership from the authenticated actor

- **WHEN** a user attempts to edit or remove another person's financial record
- **THEN** the operation SHALL fail without changing that record

- **WHEN** a client provides an owner id in a financial mutation payload
- **THEN** the RPC contract SHALL reject or ignore it and SHALL not use it for authorization

### Requirement: Expense and budget invariants are atomic
Each expense or budget mutation SHALL validate its full business invariant and persist its result in one database
transaction. Financial amounts remain integer BRL cents, financial dates remain civil dates, an expense never
persists a budget foreign key, and live budgets of one owner cannot overlap.

#### Acceptance scenarios

- **WHEN** an expense has a non-positive amount or invalid civil date according to the product rules
- **THEN** its RPC SHALL reject the mutation without persisting a partial record

- **WHEN** a budget would overlap another live budget of the same owner
- **THEN** its RPC SHALL reject the mutation without changing either budget

- **WHEN** concurrent budget requests compete for an overlapping date range
- **THEN** at most one resulting live budget state SHALL satisfy the request and the database SHALL preserve the
  non-overlap invariant

### Requirement: Couple mutations preserve individual financial ownership
When the couple context is implemented, pairing operations SHALL be executed by authenticated transactional RPCs.
They SHALL create and dissolve only the read-sharing relationship and SHALL never transfer, merge, or grant
write access to either person's expenses or budgets.

#### Acceptance scenarios

- **WHEN** an eligible recipient accepts a valid invitation
- **THEN** the database SHALL atomically create one valid couple relationship without changing either owner's
  financial records

- **WHEN** a user attempts to accept their own, expired, already consumed, or otherwise invalid invitation
- **THEN** the RPC SHALL fail without creating a couple relationship

- **WHEN** a couple relationship is dissolved
- **THEN** the read-sharing relationship SHALL be removed while individual financial records remain unchanged

### Requirement: Expected database failures are translated at the feature boundary
Flutter infrastructure adapters SHALL map expected RPC failures to feature-owned failures. Presentation SHALL
receive safe, actionable messages and SHALL not receive raw PostgREST, PostgreSQL, or Supabase exception details.

#### Acceptance scenarios

- **WHEN** an RPC rejects an overlapping budget or unauthorized mutation
- **THEN** the corresponding feature command SHALL receive a typed expected failure that presentation can map

- **WHEN** an unexpected provider or transport failure occurs
- **THEN** the failure SHALL remain distinguishable for diagnostic handling and SHALL not be mislabeled as a
  business-rule failure

## Dependencies

- `specs/version-supabase-backend.md` must be implemented first.
- Approved table definitions and RLS policy model for the financial contexts.

## Verification

- Unit-test each Flutter RPC adapter and failure mapping.
- Execute RPC integration tests against a local Supabase instance with authorized and unauthorized actors.
- Confirm no financial Flutter adapter contains a direct table write after the migration.
