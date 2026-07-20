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

### Requirement: Consultar os gastos de uma pessoa por keyset

O `ExpenseRepository` SHALL expor uma consulta que retorna os gastos de uma pessoa dado o seu identificador,
uma **posição de cursor** opcional (após a qual continuar) e um **limite** de itens, como uma lista de
`ExpenseEntity`. A consulta SHALL filtrar estritamente por `person_id`, retornando apenas os gastos daquele
dono, e SHALL retornar uma **lista vazia** quando não há gastos após a posição dada (nunca `null`, nunca
erro). Os resultados SHALL vir ordenados de forma determinística — por `spent_on` decrescente com desempate
estável por `id` — e, quando uma posição de cursor é dada, SHALL conter apenas gastos **estritamente após**
essa posição `(spent_on, id)`, no máximo `limite` itens, com o recorte e a ordenação feitos **no banco**
(keyset + `LIMIT`, não offset, não em memória). O adapter jOOQ SHALL mapear cada record de volta para um
`ExpenseEntity` de domínio, sem que o tipo record escape da camada de infraestrutura. A consulta SHALL
reusar a tabela `expense` existente (V3), sem nova migração.

#### Scenario: Retorna a primeira fatia do dono, ordenada e limitada

- **WHEN** a consulta recebe o identificador de uma pessoa com gastos, sem cursor, e um limite
- **THEN** o repositório retorna no máximo `limite` `ExpenseEntity` daquele dono
- **AND** apenas gastos com aquele `person_id` aparecem
- **AND** vêm ordenados por `spent_on` decrescente, com desempate estável por `id`

#### Scenario: Continua estritamente após a posição do cursor

- **WHEN** a consulta recebe uma posição de cursor `(spent_on, id)` daquele dono
- **THEN** o repositório retorna apenas gastos estritamente após essa posição na ordem determinística
- **AND** não repete o gasto na posição do cursor nem os anteriores a ela

#### Scenario: Pessoa sem gastos (ou cursor esgotado) retorna lista vazia

- **WHEN** a consulta recebe o identificador de uma pessoa sem gastos após a posição dada
- **THEN** o repositório retorna uma lista vazia
- **AND** não retorna `null` nem sinaliza erro

### Requirement: A listagem é servida por um cache distribuído com invalidação por escrita

O sistema SHALL servir a consulta de listagem de uma pessoa **através de um cache distribuído (Valkey)**,
como um decorator do `ExpenseRepository` que envolve o adapter de persistência, de modo que
`application`/`domain` permaneçam inconscientes do cache. A leitura SHALL ser **read-through**: um acerto
serve do cache; um erro serve do datastore e popula o cache com um TTL. A chave de cache SHALL ser escopada
por **pessoa**, posição de página (cursor) e limite, de modo que a página de uma pessoa nunca colida com a
de outra. Uma indisponibilidade do cache SHALL degradar para o datastore (tratada como um *miss*), nunca
falhar a leitura — o cache acelera, não é a fonte da verdade.

#### Scenario: Leitura read-through popula e reusa o cache

- **WHEN** a mesma página de uma pessoa é listada duas vezes sem nenhuma escrita entre as leituras
- **THEN** a primeira leitura consulta o datastore e popula o cache
- **AND** a segunda leitura é servida do cache com o mesmo resultado

#### Scenario: Cache indisponível degrada para o datastore

- **WHEN** o cache está indisponível durante uma listagem
- **THEN** o sistema serve a página a partir do datastore
- **AND** a leitura não falha por causa do cache

### Requirement: Toda escrita invalida a listagem cacheada do dono

O sistema SHALL invalidar a listagem cacheada de uma pessoa **sempre que o conjunto de gastos dela muda**,
imediatamente após a escrita persistir. A regra SHALL ser definida por **mutação**, não por rota: **criar**
um gasto (a única escrita existente hoje) SHALL invalidar a listagem do **dono**; **editar** e **apagar** um
gasto (quando essas operações existirem) SHALL igualmente invalidar a listagem do **dono**. A invalidação
SHALL escopar-se ao **dono** afetado — a escrita de uma pessoa SHALL NOT invalidar a listagem de outra. A
invalidação SHALL residir em **um único ponto** (o decorator de cache do `ExpenseRepository`), no caminho
de escrita de cada operação de mutação, de modo que nenhum use case invalide cache à mão e nenhuma mutação
futura possa deixar de invalidar. A estratégia de invalidação SHALL NOT depender de varredura de chaves
(`KEYS`/`SCAN`); páginas obsoletas SHALL deixar de ser servidas de imediato e expirar por TTL como piso de
correção.

#### Scenario: Registrar um gasto invalida a listagem do dono

- **WHEN** uma pessoa registra um gasto após ter uma página sua em cache
- **THEN** a listagem cacheada daquela pessoa é invalidada
- **AND** uma nova listagem do dono reflete o gasto recém-registrado, não a página obsoleta

#### Scenario: A invalidação de uma pessoa não afeta outra

- **WHEN** uma pessoa registra um gasto
- **THEN** apenas a listagem cacheada daquela pessoa é invalidada
- **AND** a listagem cacheada de outra pessoa permanece válida

