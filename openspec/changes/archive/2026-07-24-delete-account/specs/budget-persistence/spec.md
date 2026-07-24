## ADDED Requirements

### Requirement: Repositório remove definitivamente (hard-delete) todos os orçamentos de uma pessoa

O `BudgetRepository` SHALL expor uma operação que, dado o identificador de uma pessoa, **remove fisicamente**
todos os orçamentos que ela possui — vivos e já removidos (soft-deleted) — do datastore. Essa operação é
distinta da remoção de um único orçamento (`delete`), que apenas transiciona o estado para removido: aqui
não sobra linha nenhuma. A operação existe para servir ao cascata de exclusão de conta de `identity`, nunca
ao fluxo de auto-remoção de um orçamento específico. Nenhuma exceção de datastore SHALL cruzar para a
`application`. Uma pessoa sem nenhum orçamento SHALL resultar num no-op silencioso, não um erro.

#### Scenario: Todos os orçamentos da pessoa são removidos fisicamente

- **WHEN** a operação recebe o identificador de uma pessoa com orçamentos vivos e removidos
- **THEN** nenhuma linha da tabela `budget` daquela pessoa continua existindo após a operação

#### Scenario: Orçamentos de outras pessoas não são afetados

- **WHEN** a operação recebe o identificador de uma pessoa
- **THEN** os orçamentos pertencentes a qualquer outra pessoa permanecem intactos

#### Scenario: Pessoa sem orçamentos é um no-op

- **WHEN** a operação recebe o identificador de uma pessoa sem nenhum orçamento
- **THEN** nenhuma linha é alterada
- **AND** nenhuma exceção é lançada
