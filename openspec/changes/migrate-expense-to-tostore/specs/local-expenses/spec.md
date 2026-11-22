# Spec Delta

## Purpose

Permitir cadastro, manutenção e consulta de despesas no dispositivo, sem conta ou serviço remoto.

## ADDED Requirements

### Requirement: Local expense persistence

Expenses SHALL persist locally with generated string IDs, positive integer cents, a supported category and a civil date. Creation without a date SHALL use today's local calendar date. No operation SHALL require an owner or authenticated identity.

#### Scenario: Persistent creation
- **WHEN** a valid expense is created and storage is reopened
- **THEN** its ID, exact cents, description, category and civil date remain available

### Requirement: Partial mutations and missing records

Updates SHALL change only supplied fields. Reading, updating or deleting an absent ID SHALL report an expected application failure. Confirmed mutations SHALL request monthly widget refresh; unsuccessful mutations SHALL NOT.

#### Scenario: Updating a single field
- **WHEN** only cents are supplied for an existing expense
- **THEN** its other fields remain unchanged

#### Scenario: Unknown ID
- **WHEN** an absent expense is read, updated or deleted
- **THEN** an expected not-found failure is reported

### Requirement: Filtered pages

Queries SHALL preserve category and inclusive civil-date filters on every page, deterministic ordering and immutable page contents. A next page SHALL be exposed only if another matching record exists.

#### Scenario: Last civil day
- **WHEN** a range ends on a given civil date
- **THEN** expenses on that date are included without timezone conversion

### Requirement: Recent description suggestions

Suggestions SHALL search descriptions case-insensitively, inspect at most 30 recent matching records and deduplicate descriptions case-insensitively. Each suggestion SHALL retain the most recent matching expense's category and amount.

#### Scenario: Repeated description
- **WHEN** matching recent records have descriptions differing only by case
- **THEN** only the most recent one supplies the suggestion

### Requirement: Safe local failures

Expected storage failures SHALL become application failures without native messages. Invalid parsing and programming errors SHALL remain unexpected, never empty success.

#### Scenario: Malformed stored category
- **WHEN** a stored record contains an unsupported category
- **THEN** parsing fails instead of substituting a default category
