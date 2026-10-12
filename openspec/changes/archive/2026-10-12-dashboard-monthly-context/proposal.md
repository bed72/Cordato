## Why

A Dashboard permite navegar por meses no gráfico, mas mantém despesas recentes e insights fora desse recorte, produzindo uma leitura financeira inconsistente. A API já oferece os filtros necessários para que o mês selecionado seja o contexto compartilhado das três seções.

## What Changes

- Transformar o seletor do gráfico em navegação mensal da Dashboard, somente por setas, iniciando no mês atual e impedindo meses futuros.
- Consultar gráfico, insights e seis despesas recentes em paralelo para o mesmo mês, com estados independentes e sem exibir resultados anteriores sob o novo período.
- Bloquear as setas enquanto qualquer consulta da Dashboard estiver em execução e liberá-las após conclusão, inclusive em caso de erro.
- Preservar o mês em refresh e retorno do cadastro ou da listagem; o cadastro continua com data inicial de hoje.
- Abrir “Ver tudo” no mês selecionado e preservar o intervalo durante paginação, refresh, retry, edição e exclusão.
- Evoluir os contratos de consulta de Expense e Insight e atualizar todos os consumidores, doubles e testes. Consultas sem filtro continuam disponíveis.
- Documentar os contratos e validar integração e interação conforme as convenções do projeto.

## Capabilities

### New Capabilities

- `dashboard-monthly-navigation`: contexto mensal compartilhado, navegação, carregamento, atualização e preservação do mês.
- `insights-monthly-query`: consulta de insights por ano e mês com preservação integral da análise retornada.
- `expenses-period-query`: consulta de despesas por intervalo civil e listagem completa contextualizada pelo mês da Dashboard.

### Modified Capabilities

Nenhuma spec canônica existente cobre esses comportamentos; as capacidades acima serão adicionadas.

## Impact

- Dashboard: screen, mixin de estado, seletor mensal, seções e callbacks de navegação.
- Expense: contratos de repository/data source, implementações, `GetExpensesCommand`, listagem, rota e retorno do cadastro.
- Insight: contratos, repository, data source e `GetInsightsCommand`.
- Metrics: reutilização do contrato atual com `start_date`, `end_date` e `group_by=category`.
- API: consumo dos filtros existentes; sem mudança de backend ou dependência adicional prevista.
- Previews, doubles e testes das camadas afetadas; validação de UI com Maestro.
- `ARCHITECTURE.md`, `AGENTS.md` e `README.md` para refletir a nova navegação e os contratos.
