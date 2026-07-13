# expense-persistence

## ADDED Requirements

### Requirement: Consultar os gastos de uma pessoa

O `ExpenseRepository` SHALL expor uma consulta que retorna **todos os gastos de uma pessoa** dado o seu
identificador, como uma lista de `ExpenseEntity`. A consulta SHALL filtrar estritamente por
`person_id`, retornando apenas os gastos daquele dono, e SHALL retornar uma **lista vazia** quando a
pessoa não possui gastos (nunca `null`, nunca erro). Os resultados SHALL vir ordenados de forma
determinística — por `spent_on` decrescente com desempate estável por `id` —, e o adapter jOOQ SHALL
mapear cada record de volta para um `ExpenseEntity` de domínio, sem que o tipo record escape da camada de
infraestrutura. A consulta SHALL reusar a tabela `expense` existente (V3), sem nova migração.

#### Scenario: Retorna os gastos do dono, ordenados

- **WHEN** a consulta recebe o identificador de uma pessoa que possui gastos
- **THEN** o repositório retorna a lista de `ExpenseEntity` daquele dono
- **AND** apenas gastos com aquele `person_id` aparecem
- **AND** os gastos vêm ordenados por `spent_on` decrescente, com desempate estável por `id`

#### Scenario: Pessoa sem gastos retorna lista vazia

- **WHEN** a consulta recebe o identificador de uma pessoa sem nenhum gasto
- **THEN** o repositório retorna uma lista vazia
- **AND** não retorna `null` nem sinaliza erro
