## ADDED Requirements

### Requirement: Repositório remove definitivamente (hard-delete) todos os gastos de uma pessoa

O `ExpenseRepository` SHALL expor uma operação que, dado o identificador de uma pessoa, **remove
fisicamente** todos os gastos que ela possui do datastore. Essa é a primeira operação de remoção que
`expense` ganha; existe para servir ao cascata de exclusão de conta de `identity`. Nenhuma exceção de
datastore SHALL cruzar para a `application`. Uma pessoa sem nenhum gasto SHALL resultar num no-op
silencioso, não um erro.

#### Scenario: Todos os gastos da pessoa são removidos fisicamente

- **WHEN** a operação recebe o identificador de uma pessoa com gastos registrados
- **THEN** nenhuma linha da tabela `expense` daquela pessoa continua existindo após a operação

#### Scenario: Gastos de outras pessoas não são afetados

- **WHEN** a operação recebe o identificador de uma pessoa
- **THEN** os gastos pertencentes a qualquer outra pessoa permanecem intactos

#### Scenario: Pessoa sem gastos é um no-op

- **WHEN** a operação recebe o identificador de uma pessoa sem nenhum gasto
- **THEN** nenhuma linha é alterada
- **AND** nenhuma exceção é lançada

### Requirement: A remoção definitiva invalida a listagem cacheada do dono

A remoção definitiva de todos os gastos de uma pessoa SHALL invalidar a listagem cacheada dessa pessoa,
seguindo a mesma regra por-mutação que a capability já define para criar/editar/apagar um gasto — nenhuma
página obsoleta daquela pessoa SHALL continuar sendo servida do cache após a remoção.

#### Scenario: Remoção definitiva invalida o cache do dono

- **WHEN** todos os gastos de uma pessoa são removidos definitivamente, após ela ter uma página sua em
  cache
- **THEN** a listagem cacheada daquela pessoa é invalidada
