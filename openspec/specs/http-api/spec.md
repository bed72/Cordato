# http-api Specification

## Purpose
TBD - created by archiving change web-create-budget. Update Purpose after archive.
## Requirements
### Requirement: The web framework is confined to the edge

The system SHALL keep the web framework (Litestar) imported only within `infrastructure/http/` and the
composition root. The inner `domain/` and `application/` layers SHALL NOT import the framework. The web
controller is a driving adapter and therefore lives in `infrastructure/http/`, where it MAY know the framework
(the mirror of a repository as an outbound adapter); it drives a use case, which carries no HTTP or framework
types and stays framework-independent and unit-testable without spinning up a server. There SHALL be no
separate `presentation/` layer — the HTTP edge (controller, request/response DTOs, and their mappers) belongs to
`infrastructure/http/`.

#### Scenario: Inner layers do not import the framework

- **WHEN** the `domain/` and `application/` modules of a feature are inspected
- **THEN** none of them imports the web framework, and use cases expose only application `data` types

#### Scenario: A use case runs without the framework

- **WHEN** a use case is exercised directly with its command and injected ports (fakes)
- **THEN** it returns its read-model with no HTTP server and no web framework involved

### Requirement: The composition root assembles dependencies in layered scopes

The system SHALL assemble the object graph in a single composition root using the framework's native, **layered**
dependency injection. Only genuinely **cross-cutting** ports (the clock and identifier provider) SHALL be
contributed at the **application layer**, shared by every feature. Every **feature** SHALL contribute its own
dependencies **scoped to that feature** (its own router), never merged into a shared application-wide namespace,
so two features' dependency keys cannot collide; the framework SHALL resolve each handler's graph through the
layered scope (feature scope, then application scope). Adapters that hold state or are costly to build — the
in-memory repositories and the gateways — SHALL be provided as app-scoped singletons shared across requests,
and rebuilt fresh on each composition so a test can assemble an isolated application. Per-request dependencies
SHALL be provided fresh for each request. Use cases SHALL be constructed with their ports injected by the
framework's DI; no use case, controller, or mapper SHALL construct its own dependencies. Each module SHALL
contribute only its own object graph through its `main/` builder; the composition root SHALL orchestrate the
builders, SHALL be the only place that knows every module, and SHALL itself hold only the cross-cutting layer.

#### Scenario: The in-memory store persists across requests within a run

- **WHEN** one request creates a budget and a later request in the same running process acts on that person's
  budgets
- **THEN** the later request observes the earlier budget, because the repository is a shared app-scoped
  singleton

#### Scenario: A feature's dependencies are scoped to that feature

- **WHEN** a feature contributes its repository and use-case providers
- **THEN** they are registered in that feature's own scope, not the application-wide namespace, so another
  feature MAY contribute a dependency of the same name without collision

#### Scenario: Dependencies are injected, not self-constructed

- **WHEN** a controller handles a request
- **THEN** its use case and that use case's ports were provided by the framework's DI, not instantiated inside
  the controller, use case, or mapper

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

### Requirement: All routes are served under a version prefix

The system SHALL serve every HTTP route under a single API version prefix (`/v1`), owned by the composition
root. A controller SHALL declare only its bare resource path and SHALL NOT hardcode the version; the composition
root SHALL apply the prefix to every feature's routes. Introducing a new API version SHALL be a composition-root
concern (a new parent scope), never an edit spread across controllers.

#### Scenario: A resource is reachable under the version prefix

- **WHEN** a controller declares the resource path `/budgets` and is mounted by the composition root
- **THEN** the route is served at `/v1/budgets`, and the controller itself names no version

### Requirement: The API publishes a documented OpenAPI schema and interactive docs

The system SHALL generate an OpenAPI schema from the request/response models and serve it, together with an
interactive Swagger UI, at a documentation path (`/schema`). The schema SHALL carry the API title, version, and
description. Each operation SHALL be grouped under a resource **tag** and carry a human-readable **summary** and
**description**; request and response fields SHALL carry descriptions and examples so the schema (and the Swagger
"try it out" form) is self-explanatory rather than a bare shape.

#### Scenario: The OpenAPI schema and Swagger UI are available

- **WHEN** the documentation path is requested
- **THEN** the system returns the OpenAPI schema (and the Swagger UI), describing the wired routes

#### Scenario: Operations are tagged and documented

- **WHEN** the schema for a route is inspected
- **THEN** the operation carries a tag, a summary, and a description, and its request/response fields carry
  descriptions and examples

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

