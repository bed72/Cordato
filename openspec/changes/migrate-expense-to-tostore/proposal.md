# Proposal

## Decisão posterior

Após a implementação desta migração, o usuário solicitou remover o fluxo CSV
e tratar backup nativo em outra tarefa. As seções e specs de CSV desta mudança
registram o estado anterior, não o produto atual. CRUD e consultas locais de
Expense permanecem; README.md, ARCHITECTURE.md e AGENTS.md descrevem a remoção.

## Why

A versão local já abre o ToStore e registra o schema de despesas, mas Expense e a exportação CSV ainda dependem do PocketBase removido. É necessário completar esses fluxos sem restaurar autenticação ou migrar Metrics incidentalmente.

## What Changes

- CRUD, filtros, paginação e sugestões consultam o ToStore compartilhado.
- Datas civis e valores monetários mantêm sua semântica, com validação de categoria.
- **BREAKING**: exportação local deixa de exigir proprietário e conectividade; documentos não transportam identidade.
- Preservam-se ownership dos Blocs, navegação, formato CSV e limpeza de anexos.
- Testes de infraestrutura usam banco real e persistência em diretório temporário.

## Capabilities

### New Capabilities

- `local-expenses`: persistência e consulta local de despesas individuais.

### Modified Capabilities

- `expense-csv-export`: histórico local completo sem identidade autenticada ou conexão remota.

## Impact

Expense, adapter/modelos de exportação de Settings, testes e documentação da transição. Nenhuma dependência nova, migração remota, alteração nativa ou implementação de Metrics.
