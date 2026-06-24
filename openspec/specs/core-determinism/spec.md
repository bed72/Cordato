# core-determinism Specification

## Purpose
TBD - created by archiving change harden-identity-architecture. Update Purpose after archive.
## Requirements
### Requirement: Shared kernel supplies the current time

The system SHALL expose, from the `core/` shared kernel, a clock port (`ClockInterface`) that returns the
current time as a timezone-aware timestamp. Any feature that needs the current time SHALL depend on this port
rather than reading the wall clock directly, so the pure domain stays deterministic under test. The port
contract SHALL be `async`, and its concrete adapter SHALL live in `core/infrastructure/gateways/`.

#### Scenario: Clock returns a timezone-aware instant

- **WHEN** a caller awaits the clock port's `now()`
- **THEN** it receives a `datetime` that is timezone-aware (its `tzinfo` is set), never a naive timestamp

#### Scenario: Domain code never reads the wall clock directly

- **WHEN** a use case in any feature needs `created_at` (or any current time)
- **THEN** it obtains the value through the injected clock port, and no entity, value object, or domain service
  calls `datetime.now` itself

### Requirement: Shared kernel supplies opaque identifiers

The system SHALL expose, from the `core/` shared kernel, an identifier-provider port
(`IdentifierProviderInterface`) that returns a fresh, globally-unique, opaque identifier as a string. Any
feature that needs to assign an entity `id` SHALL depend on this port rather than generating identifiers
inline. The port contract SHALL be `async`, its concrete adapter SHALL live in `core/infrastructure/gateways/`,
and the produced identifier SHALL be time-ordered so it preserves index locality when persistence lands.

#### Scenario: Each generation yields a fresh unique identifier

- **WHEN** a caller awaits the identifier-provider port's `generate()` twice
- **THEN** it receives two distinct, non-empty identifier strings

#### Scenario: Domain code never generates identifiers directly

- **WHEN** a use case in any feature needs an `id` for a new entity
- **THEN** it obtains the value through the injected identifier-provider port, and no entity or domain service
  calls a UUID/identifier function itself

