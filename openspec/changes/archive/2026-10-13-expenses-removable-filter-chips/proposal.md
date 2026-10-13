## Why

A listagem já recebe mês e categoria pela Dashboard, mas comunica essas lentes na descrição e não permite removê-las. Pílulas removíveis tornam os filtros explícitos e permitem ampliar a consulta para todas as categorias ou para o histórico completo na mesma tela.

## What Changes

- Manter o título “Despesas” e tornar a descrição fixa: “Acompanhe todas as suas despesas.”
- Exibir filtros ativos abaixo da descrição em pílulas Material `InputChip`, com texto e ícone de fechar à direita, dispostas em `Wrap`.
- Mostrar categoria antes do período; o mês representa um único filtro, removendo `from` e `to` juntos.
- Inicializar filtros locais pelos argumentos existentes da rota; remover uma pílula altera somente a consulta da listagem.
- Remover categoria mantém o período. Remover mês mantém categoria e consulta seu histórico completo. Remover ambos consulta o histórico geral.
- Reiniciar resultados, continuação e rolagem ao remover um filtro, consultando a primeira página de 20 itens e apresentando skeleton sem dados da lente anterior.
- Preservar os filtros restantes na paginação, refresh, retry, vazio, edição e exclusão, inclusive após falha na primeira consulta da nova lente.
- Desabilitar remoções durante consultas, edição ou confirmação/execução de exclusão; ignorar retornos assíncronos obsoletos e respeitar o descarte.
- Preservar o mês da Dashboard e seu mecanismo atual de recarga após alterações financeiras confirmadas. Remover filtros não é uma alteração financeira.
- Atualizar previews, documentação e validação de interação com Maestro.

## Capabilities

### New Capabilities

- `expenses-removable-filters`: apresentação das pílulas, estado local, remoção independente, transição de consulta, acessibilidade e isolamento da navegação de origem.

### Modified Capabilities

- `expenses-period-query`: o período recebido passa a ser o contexto inicial da listagem; consultas, paginação e mutações respeitam o período atualmente ativo, que pode ser removido para consultar todo o histórico.

## Impact

- Feature proprietária: `expense`, em `presentation/screens/expenses/`. Alterações esperadas em `ExpensesScreen`, `ExpensesScreenStateMixin` e novo widget público de filtros no diretório `widgets/` da tela.
- Reutiliza `GetExpensesCommand`, repository, data source e os filtros HTTP já existentes. Não exige endpoint, dependência ou mudança de contrato de consulta; uma nova primeira página sem continuação impede recuperar filtros removidos de links antigos.
- Preserva `/expenses`, os records aceitos pela rota e os callbacks de Dashboard, edição e alteração financeira.
- Reutiliza `material_ui`, tema e formatters atuais. O componente de Trocado é referência visual, não dependência do aplicativo.
- Atualiza previews de Expense e os documentos `ARCHITECTURE.md`, `README.md` e `AGENTS.md` onde descrevem apresentação e estado dos filtros.
- Validação visual e de fluxo com Maestro; não introduz testes Flutter de widgets, screens ou rotas.
