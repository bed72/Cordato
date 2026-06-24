## MODIFIED Requirements

### Requirement: Register a new person

The system SHALL register a new person from a name, an email, and a password, creating a Person with an opaque
`id`, a `created_at` timestamp, `status = active`, and the password stored only as a hash. On success the
system SHALL return the person's public data — `id`, `name`, `email`, `status`, `created_at` — and SHALL NOT
include the password or its hash in that output.

Bringing a person into existence in the `active` state SHALL be reachable only through the entity's creation
factory, which fixes `status = active`; the factory is the sole sanctioned path for registration. Constructing
a person with a caller-supplied `status` SHALL be reserved for rehydrating an already-persisted record (e.g. a
persistence mapper reconstructing a stored person) and SHALL NOT be used to register a new person. There SHALL
be no default that lets a bare construction silently produce an `active` person.

#### Scenario: Successful registration

- **WHEN** a registration is requested with a valid name, a well-formed and unused email, and a
  policy-compliant password
- **THEN** a new Person is created with `status = active`, an assigned `id` and `created_at`, the password
  persisted only as a hash, and the person's public data (without any password field) is returned

#### Scenario: Registration sets the active state through the factory, not a default

- **WHEN** a person is registered
- **THEN** its `active` status comes from the creation factory, and constructing a person without going through
  that factory requires the status to be supplied explicitly (no implicit `active` default)
