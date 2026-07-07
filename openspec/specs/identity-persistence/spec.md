# identity-persistence

## Purpose

Durable storage for `identity`'s person records. Person data is persisted so it survives process
restarts, and e-mail uniqueness is enforced at the datastore (a `UNIQUE` constraint) — including under
concurrent registration — resolving to the same non-enumerating conflict outcome `person-signup` already
returns. The `PersonRepository` port keeps its shape; only the durable adapter and its uniqueness
guarantees are new, so `application` and `domain` are unaffected by the storage choice.
## Requirements
### Requirement: Durable person storage

The system SHALL store person records in a durable datastore so that a registered
person persists across application restarts. The `PersonRepository` port keeps its
current shape; the durable adapter honors the same contract, so `application` and
`domain` code are unaffected by the storage change.

#### Scenario: Registered person survives a restart

- **WHEN** a person has been registered and the application process is restarted
- **THEN** a subsequent `existsByEmail` for that person's email returns `true`

#### Scenario: Saved person is queryable by email

- **WHEN** `save` completes for a person with a given email
- **THEN** `existsByEmail` for that exact email returns `true`, and for any other
  email returns `false`

### Requirement: Datastore-enforced email uniqueness

The system SHALL enforce email uniqueness at the datastore via a `UNIQUE` constraint,
not only by the pre-check the use case runs. When a `save` would create a second person
with an already-stored email, the datastore SHALL reject it, and the repository adapter
SHALL surface that rejection as the same conflict outcome the use case already returns
for a known-duplicate email, so no doomed write silently succeeds.

#### Scenario: Concurrent duplicate registrations — only one persists

- **WHEN** two registrations for the same email run concurrently and both pass the
  `existsByEmail` pre-check before either has committed
- **THEN** exactly one person is stored for that email and the other registration
  results in the `EmailAlreadyInUse` failure — never two rows for the same email

#### Scenario: Duplicate save after commit is rejected

- **WHEN** `save` is called with an email that is already stored
- **THEN** the datastore rejects the write and the outcome is the `EmailAlreadyInUse`
  conflict, with no second row created

### Requirement: Conflict outcome preserves non-enumeration

The persistence layer SHALL NOT change identity's existing guarantee that a registration
conflict is worded so an attacker cannot distinguish "email is registered" from other
failure modes. The datastore-enforced uniqueness path SHALL resolve to the exact same
`EmailAlreadyInUse` result the use case already returns — no new, more-specific error
leaks out of the adapter.

#### Scenario: Constraint violation is not exposed verbatim

- **WHEN** a `save` is rejected by the `UNIQUE` constraint
- **THEN** the caller observes the standard `EmailAlreadyInUse` failure, not a raw
  database exception or a datastore-specific message

### Requirement: Consulta de pessoa ativa por e-mail

O sistema SHALL prover no `PersonRepository` uma consulta `findByEmail` que retorna a pessoa associada a um
e-mail **apenas quando ela estiver ativa**. Quando não houver pessoa com aquele e-mail, ou quando a pessoa
existir mas não estiver ativa (deletada ou inativa), a consulta SHALL retornar ausência de pessoa — nunca
uma pessoa não-ativa. A consulta backing o login SHALL manter a mesma neutralidade de vazamento do
contexto: colapsar "não existe" e "existe mas não-ativa" no mesmo resultado ausente.

#### Scenario: E-mail de pessoa ativa retorna a pessoa

- **WHEN** `findByEmail` recebe o e-mail de uma pessoa ativa persistida
- **THEN** o sistema retorna essa pessoa

#### Scenario: E-mail inexistente retorna ausência

- **WHEN** `findByEmail` recebe um e-mail que não pertence a nenhuma pessoa
- **THEN** o sistema retorna ausência de pessoa

#### Scenario: Pessoa não-ativa retorna ausência

- **WHEN** `findByEmail` recebe o e-mail de uma pessoa deletada ou não-ativa
- **THEN** o sistema retorna ausência de pessoa, indistinguível do e-mail inexistente

