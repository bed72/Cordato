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


### Requirement: Consulta de pessoa ativa por identificador

O sistema SHALL prover no `PersonRepository` uma consulta `findById` que retorna a pessoa associada a um
identificador **apenas quando ela estiver ativa**. Quando não houver pessoa com aquele id, ou quando a
pessoa existir mas não estiver ativa (deletada ou inativa), a consulta SHALL retornar ausência de pessoa —
nunca uma pessoa não-ativa. Essa consulta SHALL manter a mesma neutralidade da `findByEmail`: colapsar "não
existe" e "existe mas não-ativa" no mesmo resultado ausente, de modo que uma sessão órfã não distinga os
casos. O adapter durável SHALL implementar o mesmo filtro de status no datastore.

#### Scenario: Id de pessoa ativa retorna a pessoa

- **WHEN** `findById` recebe o identificador de uma pessoa ativa persistida
- **THEN** o sistema retorna essa pessoa

#### Scenario: Id inexistente retorna ausência

- **WHEN** `findById` recebe um identificador que não pertence a nenhuma pessoa
- **THEN** o sistema retorna ausência de pessoa

#### Scenario: Pessoa não-ativa retorna ausência

- **WHEN** `findById` recebe o identificador de uma pessoa deletada ou não-ativa
- **THEN** o sistema retorna ausência de pessoa, indistinguível do id inexistente

### Requirement: Repositório neutraliza o e-mail e marca a pessoa como apagada, numa única escrita

O `PersonRepository` SHALL expor uma operação que, dado o identificador de uma pessoa **ativa**, substitui
seu e-mail por um valor **neutralizado** (sintaticamente válido, globalmente único, e sem capacidade de
autenticar login) e transiciona seu status para **apagada**, como uma única escrita atômica. A operação
SHALL deixar nome, senha (hash) e identificador intocados. Assim como as demais operações estreitas de
`PersonRepository` (`updateName`, `updateEmail`, `updatePassword`), esta é deliberadamente restrita a esses
dois campos, não um `save(person)` genérico.

#### Scenario: E-mail é neutralizado e status transiciona para apagada

- **WHEN** a operação recebe o identificador de uma pessoa ativa
- **THEN** o e-mail persistido dessa pessoa passa a ser um valor neutralizado, sintaticamente válido e único
- **AND** o status persistido dessa pessoa passa a ser apagada
- **AND** o nome, a senha (hash) e o identificador permanecem exatamente como estavam

#### Scenario: Pessoa não-ativa não é afetada

- **WHEN** a operação recebe o identificador de uma pessoa que não existe, ou que já não está ativa
- **THEN** nenhuma linha é alterada
- **AND** a operação retorna que nenhuma pessoa ativa foi encontrada, o mesmo desfecho ausente que
  `findById` reporta

### Requirement: E-mail neutralizado libera o endereço original para um novo cadastro

O sistema SHALL garantir que, após a neutralização, o endereço de e-mail **original** da pessoa apagada não
está mais associado a nenhuma linha ativa — de modo que a checagem de unicidade de um novo cadastro para
esse mesmo endereço não encontre conflito. A garantia de unicidade global do e-mail (autoritativa na
fronteira de persistência, como já vale para `updateEmail`) SHALL continuar valendo entre pessoas ativas;
uma pessoa apagada nunca compete por essa unicidade.

#### Scenario: E-mail original fica disponível após a exclusão

- **WHEN** uma pessoa é marcada como apagada e seu e-mail neutralizado
- **THEN** um cadastro subsequente usando o e-mail original dessa pessoa não é recusado por
  `EmailAlreadyInUse`
