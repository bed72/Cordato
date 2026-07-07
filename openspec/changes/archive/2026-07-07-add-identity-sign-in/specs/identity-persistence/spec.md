## ADDED Requirements

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
