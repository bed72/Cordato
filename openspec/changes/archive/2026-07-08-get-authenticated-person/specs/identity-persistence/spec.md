## ADDED Requirements

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
