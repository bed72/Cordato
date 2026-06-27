## ADDED Requirements

### Requirement: The web framework is confined to the edge

The system SHALL keep the web framework (BlackSheep) imported only within `infrastructure/http/` and the
`main/` composition root. The inner `domain/` and `application/` layers SHALL NOT import the framework. The web
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

### Requirement: The composition root assembles dependencies with explicit lifetimes

The system SHALL assemble the object graph in a single composition root (`main/`) using the framework's DI
container (Rodi). Adapters that hold state or are costly to build — the in-memory repositories and the gateways
— SHALL be registered as app-scoped singletons shared across requests. Per-request dependencies SHALL be
resolved fresh for each request. Use cases SHALL be constructed with their ports injected by the container; no
use case, controller, or mapper SHALL construct its own dependencies.

#### Scenario: The in-memory store persists across requests within a run

- **WHEN** one request creates a budget and a later request in the same running process reads that person's
  budgets
- **THEN** the later request observes the earlier budget, because the repository is a shared app-scoped
  singleton

#### Scenario: Dependencies are injected, not self-constructed

- **WHEN** a controller handles a request
- **THEN** its use case and that use case's ports were provided by the container, not instantiated inside the
  controller, use case, or mapper

### Requirement: Request input is validated at the boundary

The system SHALL validate the structural shape of each request body at the web boundary using a Pydantic
request model. A body that fails this validation SHALL be rejected with HTTP 422 and a response describing the
offending fields, and the corresponding use case SHALL NOT be invoked. Domain-rule validation (value-object
invariants, cross-entity rules) remains in the domain and SHALL NOT be duplicated at the boundary.

#### Scenario: A malformed body returns 422

- **WHEN** a request body is missing a required field or carries a value of the wrong type
- **THEN** the system responds 422 with the validation details and does not invoke the use case

### Requirement: Domain errors map to HTTP status codes explicitly

The system SHALL translate domain errors to HTTP responses through an explicit, framework-independent mapping
registered as exception handlers — never left to framework defaults. Each domain error SHALL map to a definite
status: a not-found error to 404, a conflict or invariant violation to 409, a malformed value to 422, and an
authentication failure to 401. The pt-BR domain message SHALL be conveyed without leaking sensitive data,
preserving the domain's non-enumeration guarantees. `pydantic.ValidationError` SHALL map to 422.

#### Scenario: A conflict error becomes 409

- **WHEN** a use case raises a conflict or invariant domain error (e.g. an overlapping budget)
- **THEN** the system responds 409 carrying the domain's generic pt-BR message, leaking no sensitive value

#### Scenario: The mapping is total

- **WHEN** any known domain error reaches the web boundary
- **THEN** it is mapped to its designated status by the table, never surfacing as an unhandled 500

### Requirement: The acting person is resolved per request (transitional)

Until real authentication lands, the system SHALL resolve the acting person from a transitional `X-Person-Id`
request header, injected as a request-scoped dependency. This is an explicit placeholder that carries no real
authorization; the forthcoming authentication change SHALL replace it by deriving the person from a validated
session token. A request that requires an acting person but omits the header SHALL be rejected with HTTP 400
rather than defaulting to any person.

#### Scenario: A missing identity header is rejected

- **WHEN** a request that requires an acting person arrives without the `X-Person-Id` header
- **THEN** the system responds 400 and does not invoke the use case

#### Scenario: The header supplies the acting person

- **WHEN** a request carries an `X-Person-Id` header
- **THEN** that identifier is injected as the acting person for the use case invocation
