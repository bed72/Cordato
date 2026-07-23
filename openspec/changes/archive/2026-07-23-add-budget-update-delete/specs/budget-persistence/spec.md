## ADDED Requirements

### Requirement: Repositório busca um orçamento por identificador, sem filtrar por dono ou estado

O `BudgetRepository` SHALL expor uma consulta que, dado o identificador de um orçamento, retorna o
`BudgetEntity` correspondente, ou nenhum resultado quando o identificador não corresponder a nenhum
orçamento existente. Esta consulta SHALL NOT filtrar por pessoa dona nem por estado (vivo/removido) — a
checagem de dono e de vivacidade é responsabilidade de quem consome o resultado na `application`, nunca do
port.

#### Scenario: Busca por id existente retorna o orçamento

- **WHEN** a consulta recebe o identificador de um orçamento existente, de qualquer dono e em qualquer
  estado
- **THEN** a consulta retorna o `BudgetEntity` correspondente

#### Scenario: Busca por id inexistente não retorna nada

- **WHEN** a consulta recebe um identificador que não corresponde a nenhum orçamento
- **THEN** a consulta não retorna nenhum resultado

### Requirement: Repositório atualiza um orçamento existente

O `BudgetRepository` SHALL expor uma operação que recebe um `BudgetEntity` já validado e atualizado e
persiste seu novo valor, intervalo de datas e anotação, localizando a linha pelo identificador do
orçamento. Nenhuma exceção de datastore SHALL cruzar para a `application`.

#### Scenario: Orçamento é atualizado pelo adapter

- **WHEN** o caso de uso pede ao `BudgetRepository` para atualizar um `BudgetEntity` existente com novos
  valor, intervalo e anotação
- **THEN** o adapter atualiza a linha correspondente na tabela `budget` com os novos valores

### Requirement: Repositório remove (soft-delete) um orçamento vivo do próprio dono, de forma idempotente-segura

O `BudgetRepository` SHALL expor uma operação de remoção que, dado o identificador de um orçamento e o
identificador da pessoa dona, transiciona o orçamento para o estado removido **somente se** ele existir,
pertencer àquela pessoa, e estiver **vivo** — as três condições verificadas na mesma operação, sem uma
consulta prévia separada. A operação SHALL retornar se alguma linha foi de fato alterada.

#### Scenario: Orçamento vivo do próprio dono é removido

- **WHEN** a remoção recebe o identificador de um orçamento vivo e o identificador de sua própria pessoa
  dona
- **THEN** o adapter transiciona a linha correspondente para o estado removido
- **AND** a operação retorna que uma linha foi alterada

#### Scenario: Remoção não afeta orçamento de outra pessoa

- **WHEN** a remoção recebe o identificador de um orçamento vivo, mas o identificador de uma pessoa que
  não é a dona daquele orçamento
- **THEN** nenhuma linha é alterada
- **AND** a operação retorna que nenhuma linha foi alterada

#### Scenario: Remoção não afeta orçamento já removido

- **WHEN** a remoção recebe o identificador de um orçamento que já está no estado removido
- **THEN** nenhuma linha é alterada
- **AND** a operação retorna que nenhuma linha foi alterada

## MODIFIED Requirements

### Requirement: Consultar sobreposição de orçamentos vivos por pessoa

O `BudgetRepository` SHALL expor uma consulta que, dado o identificador de uma pessoa e um intervalo de
datas (início e fim, ambos incluídos), retorna se existe algum orçamento **vivo** daquela pessoa cujo
intervalo compartilhe qualquer dia com o intervalo dado — comparação **inclusiva** de fronteira (dois
intervalos que se tocam num único dia contam como sobreposição). A consulta SHALL filtrar estritamente por
`person_id` e por estado vivo, ignorando orçamentos removidos, e SHALL ser resolvida inteiramente no
banco (sem carregar linhas para comparação em memória). A consulta SHALL aceitar um identificador de
orçamento **opcional** a ser excluído da comparação, de modo que a edição de um orçamento existente possa
checar sobreposição contra os **demais** orçamentos vivos da pessoa sem colidir consigo mesma; quando
ausente, a consulta se comporta exatamente como antes (todo orçamento vivo da pessoa é considerado).

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

#### Scenario: Exclui o próprio orçamento da comparação quando informado

- **WHEN** a consulta recebe o identificador de uma pessoa, um intervalo idêntico ao de um de seus
  próprios orçamentos vivos, e o identificador desse mesmo orçamento como exclusão
- **THEN** a consulta retorna que não existe sobreposição

#### Scenario: Sem exclusão, comportamento idêntico ao anterior

- **WHEN** a consulta é feita sem informar nenhum identificador de exclusão
- **THEN** a consulta considera todo orçamento vivo da pessoa na comparação, exatamente como antes desta
  mudança
