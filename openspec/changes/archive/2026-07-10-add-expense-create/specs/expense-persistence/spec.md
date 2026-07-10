# expense-persistence

## Purpose

O esquema e o repositório durável do gasto no contexto `expense`: uma migração Flyway que cria a tabela
`expense`, o port driven `ExpenseRepository` que a `application` enxerga, e o adapter jOOQ
`PersistenceExpenseRepository` que o implementa sobre o `DSLContext` compartilhado. Mantém o tipo de
registro gerado pelo jOOQ contido na `infrastructure` — só entidades cruzam de volta para a `application`.

## ADDED Requirements

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
