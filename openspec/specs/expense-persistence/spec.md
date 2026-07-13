# expense-persistence Specification

## Purpose
TBD - created by archiving change add-expense-create. Update Purpose after archive.
## Requirements
### Requirement: Esquema do gasto via migração Flyway

O sistema SHALL criar a tabela `expense` por meio de uma migração Flyway versionada
(`V3__expense.sql`), a partir da qual o jOOQ SHALL regenerar seus models no build. A tabela SHALL guardar
o identificador do gasto, o identificador da pessoa dona, o valor em **centavos como inteiro** (nunca
ponto flutuante), a data em que o gasto aconteceu e a descrição **opcional** (anulável). A tabela SHALL
NOT conter nenhuma coluna que referencie um orçamento.

#### Scenario: Migração cria a tabela expense

- **WHEN** as migrações Flyway rodam no boot
- **THEN** a tabela `expense` existe com colunas para id, id da pessoa, valor em centavos (inteiro), data e
  descrição anulável
- **AND** não há nenhuma coluna de referência a orçamento

#### Scenario: Valor é armazenado em centavos inteiros

- **WHEN** um gasto é persistido
- **THEN** seu valor é gravado como um número inteiro de centavos, sem perda de precisão

### Requirement: Repositório persiste o gasto sem vazar jOOQ

O sistema SHALL definir um port `ExpenseRepository` na `application` (driven) com uma operação de criação
que recebe um `ExpenseEntity` e o persiste, e um adapter `PersistenceExpenseRepository` na
`infrastructure` que o implementa sobre o `DSLContext` do `CoreFactory`. O tipo de registro gerado pelo
jOOQ SHALL NOT escapar da `infrastructure`: a tradução entidade↔registro SHALL ocorrer num mapper de
infraestrutura, e apenas entidades SHALL cruzar de volta para a `application`. Nenhuma exceção de datastore
SHALL cruzar para a `application`.

#### Scenario: Gasto é persistido pelo adapter

- **WHEN** o caso de uso pede ao `ExpenseRepository` para criar um `ExpenseEntity` válido
- **THEN** o adapter insere uma linha na tabela `expense` correspondente àquele gasto

#### Scenario: Tipo jOOQ não vaza da infraestrutura

- **WHEN** o adapter traduz entre o `ExpenseEntity` e o registro jOOQ
- **THEN** a tradução ocorre num mapper de infraestrutura
- **AND** o tipo de registro gerado não aparece em nenhuma assinatura da `application` ou do `domain`

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

