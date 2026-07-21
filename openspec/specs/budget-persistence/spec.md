# budget-persistence Specification

## Purpose
TBD - created by archiving change add-budget-create. Update Purpose after archive.
## Requirements
### Requirement: Esquema do orçamento via migração Flyway

O sistema SHALL criar a tabela `budget` por meio de uma migração Flyway versionada (`V4__budget.sql`), a
partir da qual o jOOQ SHALL regenerar seus models no build. A tabela SHALL guardar o identificador do
orçamento, o identificador da pessoa dona, o valor em **centavos como inteiro** (nunca ponto flutuante), a
data de início, a data de fim, a anotação **opcional** (anulável) e o **estado** do orçamento (vivo ou
removido). A tabela SHALL NOT conter nenhuma coluna que referencie gastos.

#### Scenario: Migração cria a tabela budget

- **WHEN** as migrações Flyway rodam no boot
- **THEN** a tabela `budget` existe com colunas para id, id da pessoa, valor em centavos (inteiro), data
  de início, data de fim, anotação anulável e estado
- **AND** não há nenhuma coluna de referência a gastos

#### Scenario: Valor é armazenado em centavos inteiros

- **WHEN** um orçamento é persistido
- **THEN** seu valor é gravado como um número inteiro de centavos, sem perda de precisão

### Requirement: Repositório persiste o orçamento sem vazar jOOQ

O sistema SHALL definir um port `BudgetRepository` na `application` (driven) com uma operação de criação
que recebe um `BudgetEntity` e o persiste, e um adapter `PersistenceBudgetRepository` na `infrastructure`
que o implementa sobre o `DSLContext` do `CoreFactory`. O tipo de registro gerado pelo jOOQ SHALL NOT
escapar da `infrastructure`: a tradução entidade↔registro SHALL ocorrer num mapper de infraestrutura, e
apenas entidades SHALL cruzar de volta para a `application`. Nenhuma exceção de datastore SHALL cruzar
para a `application`.

#### Scenario: Orçamento é persistido pelo adapter

- **WHEN** o caso de uso pede ao `BudgetRepository` para criar um `BudgetEntity` válido
- **THEN** o adapter insere uma linha na tabela `budget` correspondente àquele orçamento, no estado vivo

#### Scenario: Tipo jOOQ não vaza da infraestrutura

- **WHEN** o adapter traduz entre o `BudgetEntity` e o registro jOOQ
- **THEN** a tradução ocorre num mapper de infraestrutura
- **AND** o tipo de registro gerado não aparece em nenhuma assinatura da `application` ou do `domain`

### Requirement: Consultar sobreposição de orçamentos vivos por pessoa

O `BudgetRepository` SHALL expor uma consulta que, dado o identificador de uma pessoa e um intervalo de
datas (início e fim, ambos incluídos), retorna se existe algum orçamento **vivo** daquela pessoa cujo
intervalo compartilhe qualquer dia com o intervalo dado — comparação **inclusiva** de fronteira (dois
intervalos que se tocam num único dia contam como sobreposição). A consulta SHALL filtrar estritamente por
`person_id` e por estado vivo, ignorando orçamentos removidos, e SHALL ser resolvida inteiramente no
banco (sem carregar linhas para comparação em memória).

#### Scenario: Detecta sobreposição de fronteira

- **WHEN** a consulta recebe o identificador de uma pessoa com um orçamento vivo terminando em uma data
  **D**, e um intervalo que começa em **D**
- **THEN** a consulta retorna que existe sobreposição

#### Scenario: Não detecta sobreposição em intervalos adjacentes

- **WHEN** a consulta recebe o identificador de uma pessoa com um orçamento vivo terminando em uma data
  **D**, e um intervalo que começa em **D+1**
- **THEN** a consulta retorna que não existe sobreposição

#### Scenario: Ignora orçamentos removidos

- **WHEN** a consulta recebe o identificador de uma pessoa cujo único orçamento sobreposto ao intervalo
  dado está no estado removido
- **THEN** a consulta retorna que não existe sobreposição
