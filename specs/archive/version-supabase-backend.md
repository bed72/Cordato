# Version Supabase Backend

## Status

 Implemented

## Objective

Make the Supabase database, authorization policies, database functions, and Edge Function source a
reproducible, reviewable part of the Cordato codebase. A fresh environment must be provisionable from
versioned artifacts rather than from undocumented state in a remote Supabase project.

## Scope

- Add a versioned `supabase/` project structure with configuration, ordered SQL migrations, and Edge Function
  source when an Edge Function is required.
- Establish an initial, non-destructive baseline for the schema currently consumed by the mobile app.
- Version tables, constraints, indexes, triggers, grants, RLS enablement, and RLS policies required by the
  application.
- Define a repeatable local provisioning and validation workflow for a clean Supabase environment.
- Document which configuration values remain environment-specific and must not be committed.

## Non-goals

- Do not redesign the financial data model, add new user-facing features, or migrate historical production data
  without a separately approved migration plan.
- Do not place `service_role` credentials, database passwords, SMTP credentials, or production secrets in the
  repository or the Flutter client.
- Do not implement generated Dart database types, CI/E2E, offline behavior, retry, idempotency, or
  observability as part of this specification.
- Do not use Edge Functions for operations that belong in transactional PostgreSQL RPCs.

## Requirements

### Requirement: Supabase schema is versioned from a clean baseline
The project SHALL contain a Supabase configuration and ordered migrations that create every database object
required by the current mobile application and its authentication/profile integration. The baseline SHALL be
derived from the configured environment before implementation and SHALL not assume an undocumented schema.

#### Acceptance scenarios

- **WHEN** a developer provisions an empty local Supabase environment using the documented workflow
- **THEN** the resulting database SHALL contain the required extensions, schemas, tables, constraints, indexes,
  functions, triggers, grants, and storage configuration in migration order

- **WHEN** the same migrations are applied a second time through the migration tool
- **THEN** the tool SHALL recognize the applied history without requiring manual SQL changes

- **WHEN** a database object used by the Flutter app is introduced or changed
- **THEN** the change SHALL be represented by a new migration rather than an untracked console edit

### Requirement: Authorization is owned by versioned database policy
Every application table SHALL have RLS enabled and explicit policies or authenticated RPC boundaries. Policies
and functions SHALL derive the acting user from `auth.uid()` and SHALL not trust a client-supplied owner id.

#### Acceptance scenarios

- **WHEN** an unauthenticated request reaches an application table or protected function
- **THEN** it SHALL not receive data or mutate data unless an explicit public behavior is documented

- **WHEN** an authenticated user accesses an individually owned record
- **THEN** authorization SHALL be evaluated from the authenticated actor rather than from an owner identifier in
  the request payload

- **WHEN** a policy, grant, or RLS setting changes
- **THEN** the change SHALL be represented in the versioned schema artifacts

### Requirement: Database invariants are database-owned
Constraints and triggers that protect data integrity SHALL be versioned with the schema. This includes the
invariants already assumed by the mobile product, such as valid financial values, civil date ranges, and no
overlap between live budgets of the same owner when those entities are provisioned.

#### Acceptance scenarios

- **WHEN** a client bypasses local Flutter validation and submits invalid data to the database boundary
- **THEN** the database SHALL reject the invalid state

- **WHEN** an invariant requires an extension, index, constraint, trigger, or database function
- **THEN** its creation and removal behavior SHALL be present in ordered migrations

### Requirement: Edge Function source and configuration are reproducible
An Edge Function introduced for external secrets or asynchronous integration SHALL have its source,
configuration, and required non-secret environment variable names versioned under `supabase/functions`.
Deployment instructions SHALL identify secrets supplied by the runtime without storing their values.

#### Acceptance scenarios

- **WHEN** an Edge Function is required by the product
- **THEN** a developer SHALL be able to identify its source, configuration, expected environment variable names,
  and deployment procedure from the repository

- **WHEN** the function needs a privileged credential
- **THEN** the credential value SHALL be supplied only by the server-side runtime and never by Flutter build
  configuration or committed files

### Requirement: Backend setup is documented and verifiable
The repository SHALL document the local setup, migration application, reset, and validation commands. A clean
environment validation SHALL be part of the change that modifies database artifacts.

#### Acceptance scenarios

- **WHEN** a contributor follows the documented backend setup from a fresh checkout
- **THEN** they SHALL be able to provision and validate the local Supabase schema without manual dashboard edits

- **WHEN** a migration fails on a clean environment
- **THEN** the failure SHALL be treated as a release blocker for the change that introduced it

## Dependencies

- Supabase project configuration and a reviewed inventory of the existing remote schema.
- Product approval of the database representation for profiles, expenses, budgets, and future couple views.

## Verification

- Provision a fresh local Supabase environment from the repository.
- Apply migrations and validate the migration history.
- Inspect RLS enablement, policies, grants, constraints, triggers, and function definitions in the fresh database.
- Confirm no secret value is tracked by Git or bundled in Flutter configuration.
