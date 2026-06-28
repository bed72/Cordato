## MODIFIED Requirements

### Requirement: Request input is bound and validated at the boundary

The system SHALL bind and validate the structural shape of each request body at the web boundary using a
Pydantic request model bound natively by the framework. A body that fails this validation SHALL be rejected with
HTTP **422 Unprocessable Entity** before the corresponding use case is invoked, in the standard error envelope,
carrying an `errors` list of `{key, message}` describing the offending fields — each `message` in **pt-BR**
(translated from the validation error kind, never the framework's raw English) — and the top-level message
`"Dados inválidos."`. Domain-rule validation (value-object invariants, cross-entity rules) remains in the domain
and SHALL NOT be duplicated at the boundary.

#### Scenario: A malformed body returns 422 with field details

- **WHEN** a request body is missing a required field or carries a value of the wrong type
- **THEN** the system responds `422` in the standard error envelope with an `errors` list naming the offending
  fields, and does not invoke the use case

## ADDED Requirements

### Requirement: Errors are returned in a single unified envelope

The system SHALL return every error — domain, validation, and framework-raised HTTP error alike — in **one
consistent JSON envelope**: `status` (the HTTP status), `code` (a stable, programmatic identifier of the error
kind), and `message` (a human message, pt-BR for domain errors), plus an optional `errors` (a list of
`{key, message}` field details) **present only for field-level errors and omitted otherwise**. No error SHALL be
returned in the framework's default error shape. The `message` SHALL be **pt-BR** and SHALL NOT leak sensitive
data, preserving the domain's non-enumeration guarantees; for framework-raised HTTP errors (malformed JSON,
unknown route, wrong method, …) the `message` SHALL be derived from the HTTP status — never the framework's
English detail, which can leak parser internals (e.g. a byte offset).

#### Scenario: Errors share the same core shape

- **WHEN** any error is returned — a domain error, a validation error, or a framework HTTP error
- **THEN** the body always carries `status`, `code`, and `message`, and includes `errors` only when the error is
  field-level

#### Scenario: A domain error is framed in the envelope

- **WHEN** a use case raises a domain error at the boundary
- **THEN** the system responds with `status`, the error's `code`, and its pt-BR `message`, with no `errors`
  field, leaking no sensitive value

#### Scenario: A framework HTTP error is framed in pt-BR

- **WHEN** the framework raises an HTTP error itself (e.g. a malformed JSON body → 400, or an unknown route → 404)
- **THEN** the system responds in the same envelope with a pt-BR `message` derived from the status, not the
  framework's English detail

### Requirement: Domain errors map to HTTP statuses via a framework-independent total table

The system SHALL translate domain errors to HTTP statuses through an explicit mapping that is a
**framework-independent** table (a plain map of error type → HTTP status, holding no framework types),
unit-testable in pure Python. Each feature SHALL own its error→status entries and frame them with handlers
**scoped to that feature's own router** (per route-module, mirroring its scoped dependency injection); the
cross-cutting handlers (validation, the framework HTTP fallback) SHALL be registered once at the app layer. The
mapping SHALL be **total** over the domain errors reachable at a wired boundary: every such error SHALL have an
entry, so none surfaces as an unhandled `500`. A conflict or invariant violation SHALL map to `409`, a malformed
value to `422`, a not-found to `404`, and an authentication failure to `401`.

#### Scenario: A conflict error becomes 409

- **WHEN** a use case raises a conflict or invariant domain error (e.g. an overlapping budget)
- **THEN** the system responds `409` in the unified envelope carrying the domain's generic pt-BR message

#### Scenario: The mapping is total over known errors

- **WHEN** any domain error reachable at a wired boundary occurs
- **THEN** it is mapped to its designated status by the table, never surfacing as an unhandled `500`

#### Scenario: A feature's error handlers are scoped to its router

- **WHEN** a feature is wired into the application
- **THEN** its domain-error handlers are registered on that feature's own router (scoped per route-module),
  without editing other features' maps or the app-level cross-cutting handlers
