## Why

Repetir um gasto conhecido exige preencher novamente o formulário. Um atalho na listagem permite registrar a mesma despesa com a data de hoje, com confirmação explícita e sem alterar o registro original.

## What Changes

- Long press em uma despesa abre confirmação de recadastro no padrão visual existente, com ação equivalente acessível.
- “Cadastrar” cria diretamente uma nova despesa com descrição, centavos e categoria da selecionada e data civil de hoje, sem abrir formulário.
- Loading bloqueia botões e fechamento durante a gravação. Sucesso ou falha fecha a bottom-sheet e mostra toast com título curto e descrição.
- Filtros permanecem ativos; recadastros no mesmo dia são permitidos. Submissões repetidas durante a operação são descartadas.
- Preserva edição e exclusão pelos gestos existentes e integração de atualização do widget nativo; toque simples não abre edição.

## Capabilities

### New Capabilities

- `expense-reregistration`: Confirmação, criação direta, concorrência, feedback e atualização filtrada da listagem ao repetir uma despesa.

### Modified Capabilities

Nenhuma. Os contratos existentes de filtros, edição e exclusão permanecem válidos.

## Impact

- Apresentação de Expense: listagem, item, mixin, eventos/estados e `ExpensesBloc`, além de previews e testes unitários.
- Reutiliza `IExpenseRepository.create` e o PocketBase compartilhado, sem novo endpoint, schema, dependência ou comunicação entre Blocs/features.
- Componentes de bottom-sheet do core poderão receber suporte visual a loading/bloqueio, preservando os consumidores atuais.
- Sem migração de ownership do `ExpensesBloc`, alterações no formulário, deploy ou homologação remota nesta proposta.
