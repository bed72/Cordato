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
Pydantic request model bound natively by the framework. A body that fails this validation SHALL be rejected
with a client error before the corresponding use case is invoked. Domain-rule validation (value-object
invariants, cross-entity rules) remains in the domain and SHALL NOT be duplicated at the boundary.

> The canonical status code and error envelope for a rejected body are owned by the separate
> domain-error→HTTP-status mapping change; until it lands, the framework's default validation response applies.

#### Scenario: A malformed body is rejected before the use case

- **WHEN** a request body is missing a required field or carries a value of the wrong type
- **THEN** the system rejects it at the boundary with a client error and does not invoke the use case

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

