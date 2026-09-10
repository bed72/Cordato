# Synchronize Architecture Documentation

## Status

Proposed

## Objective

Make the Cordato documentation an accurate guide to the repository that contributors can trust when implementing
the next feature. Architectural decisions, module composition, feature status, Supabase ownership, and validation
commands must describe the code that is actually tracked.

## Scope

- Reconcile `README.md`, `ARCHITECTURE.md`, and `AGENTS.md` with the current Flutter source tree and tests.
- Correct stale statements about registered dependencies, composed modules, routes, authentication behavior, and
  implemented feature status.
- Document the relationship between Flutter, the versioned Supabase backend, migrations, RLS, transactional RPCs,
  and future integration tests as those capabilities are delivered.
- Preserve the product rule that a couple is a read-only point of view, not a financial owner.
- Define a documentation review step for changes that alter structure, routes, Supabase contracts, or validation.

## Non-goals

- Do not rename Cordato, Trocado, packages, deep-link schemes, routes, or assets merely to make prose uniform.
- Do not alter product scope, database schema, feature behavior, or test policy as part of documentation-only
  synchronization.
- Do not duplicate full API, migration, or RLS implementation details in multiple documents; link to the
  authoritative artifact instead.

## Requirements

### Requirement: Documented architecture matches tracked source
The architecture documentation SHALL describe the modules, feature layers, dependency direction, routes, and
registrations that exist in the tracked Flutter source. It SHALL not present removed or unimplemented code as
current behavior.

#### Acceptance scenarios

- **WHEN** a contributor compares the documented application composition with `lib/app_module.dart` and feature
  modules
- **THEN** each documented module and registration SHALL exist, and each relevant existing module SHALL be
  represented or intentionally omitted with rationale

- **WHEN** a contributor follows the documented route map
- **THEN** the route paths and their authentication expectations SHALL match the implemented application

- **WHEN** a document refers to a storage client, command, or authentication API
- **THEN** the referenced artifact or current replacement SHALL exist in the source tree

### Requirement: Product and backend boundaries are explicit
Documentation SHALL identify which financial contexts are implemented, which are planned, and which backend
artifacts are authoritative. It SHALL state that individual ownership is enforced by Supabase policy and
transactional RPCs once those artifacts exist, while Flutter presentation does not grant authority.

#### Acceptance scenarios

- **WHEN** a contributor plans a financial feature
- **THEN** the documentation SHALL direct them to the owning context, database migration/RPC boundary, and
  applicable authorization tests

- **WHEN** a contributor reads the couple model
- **THEN** the documentation SHALL state that pairing enables only the approved combined read view and never
  cross-user financial writes

- **WHEN** a planned context is not yet implemented
- **THEN** the documentation SHALL label it as planned instead of describing hypothetical classes or routes as
  current code

### Requirement: Development and verification instructions are reproducible
The README and contributor guidance SHALL list the current commands, required non-secret configuration names, and
validation responsibilities for Flutter and Supabase work. They SHALL distinguish unit tests from database/RLS
integration tests and release verification.

#### Acceptance scenarios

- **WHEN** a developer prepares the Flutter application locally
- **THEN** the documentation SHALL provide the current non-secret Supabase configuration names and application
  commands without embedding credential values

- **WHEN** a change affects Flutter architecture, Supabase schema/RPCs, RLS, Android release configuration, or
  tests
- **THEN** contributor guidance SHALL identify the documentation and verification artifacts that must be reviewed

- **WHEN** an instruction references a validation command
- **THEN** the command SHALL exist or the document SHALL clearly state its prerequisite and intended environment

### Requirement: Documentation changes are scoped and reviewed
Documentation synchronization SHALL preserve existing product decisions and avoid speculative replacement
architecture. A structural code change SHALL update the canonical document that owns the affected rule in the
same change.

#### Acceptance scenarios

- **WHEN** a change adds, removes, or relocates a module, route, contract, or validation command
- **THEN** the same change SHALL update the canonical architecture or contributor document

- **WHEN** a document contains a legacy product name or configuration detail
- **THEN** it SHALL be retained only when it describes an active compatibility requirement; otherwise the
  discrepancy SHALL be corrected through an explicitly scoped decision

## Dependencies

- A source-tree audit of current modules, routes, dependencies, and tests.
- The final artifact locations from the Supabase versioning, RPC, RLS test, and Android release changes when
  those are implemented.

## Verification

- Compare every updated architecture statement against the referenced source or tracked backend artifact.
- Run every documented Flutter command in the environment where it is declared applicable.
- Review README, ARCHITECTURE, and AGENTS together for contradictory descriptions of current behavior.
