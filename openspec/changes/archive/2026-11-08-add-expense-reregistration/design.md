## Context

`ExpensesBloc` já coordena consultas e exclusão pela interface `IExpenseRepository`. O contrato oferece `create` com centavos, descrição, categoria e data; o repository lê o proprietário autenticado e sinaliza atualização mensal do widget nativo após criar. Não há necessidade de endpoint ou contrato adicional.

`showConfirmationBottomSheetWidget` fecha antes de chamar `onConfirm`, portanto não atende sozinho ao loading solicitado. O wrapper `showBottomSheetWidget` oferece configuração de drag e barreira, mas esses parâmetros são definidos ao abrir a rota. As regras atuais de AGENTS.md e ARCHITECTURE.md prevalecem sobre specs históricas de commands/HTTP próprio.

## Goals / Non-Goals

**Goals:** criar diretamente uma cópia com a data de hoje; confirmar antes da escrita; impedir submissões concorrentes; encerrar a confirmação com feedback seguro; preservar filtros e integração existente.

**Non-Goals:** abrir formulário, editar o original, deduplicar gastos, criar recorrência automática, migrar ownership da listagem, alterar backend ou adicionar dependências entre features.

## Decisions

### Operação no Bloc da listagem

Adicionar evento concreto e estados sealed de recadastro ao `ExpensesBloc`, consumindo apenas `IExpenseRepository.create`. Não usar `ExpenseBloc`, repository concreto ou PocketBase na apresentação. Manter factory estável e fechamento pela screen, conforme o ownership atual.

O evento leva a despesa selecionada e a data civil capturada ao confirmar. A UI captura `DateTime.now()` naquele momento; o construtor do evento representa seus componentes civis como `DateTime.utc(year, month, day)`, sem converter o instante local para UTC. Isso evita deslocamento de dia e permite testes determinísticos com data explícita. Copiar os centavos inteiros, descrição e categoria exatamente, inclusive `other`; nunca reutilizar ID ou proprietário.

### Confirmação assíncrona sem estado de execução paralelo

Criar widget público específico de Expense em arquivo próprio, reutilizando scaffold, tema e botões do core. Exibir “Recadastrar”, “Recadastre essa despesa com a data atual.”, “Voltar” e “Cadastrar”, nessa ordem. Fornecer a instância explícita do Bloc sem transferir ownership.

Usar a rota de bottom-sheet com drag e toque externo desabilitados desde a abertura; “Voltar” cancela antes do envio. Back do sistema é permitido antes do envio e bloqueado enquanto o estado indicar gravação, com `PopScope`. Isso evita tentar alterar parâmetros estáticos da barreira durante o request. O bloqueio de gesto antes do envio é uma escolha técnica conservadora, mantendo cancelamento explícito disponível.

Durante o envio, o estado do Bloc governa loading e desabilitação dos dois botões. Após sucesso ou falha, o listener fecha somente essa bottom-sheet; a listagem mostra um único toast após o fechamento. Não usar o helper que fecha antes de gravar nem flags locais espelhando loading/erro/sucesso. Handlers e lifecycle substanciais ficam em mixins específicos.

O fechamento da rota modal usa seu Navigator local, como os pickers existentes. `context.pop` do Modular 7.1.1 remove uma página declarativa antes de considerar o Navigator, podendo fechar a listagem em vez da bottom-sheet; a navegação entre páginas continua nas extensões do BuildContext.

### Concorrência e lifecycle

Usar `droppable` no evento de recadastro e incluir a operação na política de busy da listagem. Enquanto grava, bloquear nova confirmação, edição, exclusão e paginação. Coordenar consultas concorrentes por revisão e preservar/adiar pedidos de refresh para que resposta anterior não sobrescreva a mutação. `droppable` isolado não serializa handlers de tipos diferentes.

Após sucesso, recarregar a primeira página com os filtros atuais, mantendo o resultado da criação separado da consulta: falhar a recarga não transforma criação confirmada em falha nem permite retry automático do POST. Após falha de criação, preservar os itens e filtros anteriores. Encerrar o Bloc ou invalidar handlers impede emissão/efeitos posteriores, mas não cancela gravação remota.

### Feedback e isolamento

Sucesso: título “Despesa cadastrada”; descrição “Uma nova despesa foi registrada com a data de hoje.” Falha: título “Não foi possível cadastrar”; descrição local segura pelo formatter de Expense, com fallback “Tente novamente em instantes.” Não mostrar mensagens remotas diretamente.

Preservar `ErrorsEntity` em falhas esperadas, incluindo `MissingAuthenticatedUserException`; falhas inesperadas usam fallback e `addError`. A sinalização de mutação permanece no repository, sem import de Root/Metrics. Manter os consumidores atuais das confirmações de exclusão/logout intactos.

### Verificação

Cobrir Bloc, formatter e contratos de arquitetura com testes unitários, usando Completer para pendências. Reutilizar testes de infraestrutura da criação e complementar somente lacunas. Previews manuais cobrem confirmação, loading, acessibilidade e feedback; não criar testes de UI.

## Risks / Trade-offs

- Long press pouco descobrível → disponibilizar ação semântica “Recadastrar despesa”, preservando os swipes de edição e exclusão, sem adicionar edição por toque simples.
- Timeout pode ocorrer após escrita no servidor → não prometer idempotência, não repetir automaticamente; nova confirmação manual pode criar duplicata.
- Data de hoje fora do filtro → preservar filtros e exibir sucesso mesmo sem o novo item na consulta.
- Recarga após sucesso pode falhar → separar feedback de criação do erro da consulta, sem reenviar criação.
- Encerramento da tela durante request → respeitar `isClosed`, `emit.isDone` e `mounted`, sem prometer cancelamento da operação remota.

## Migration Plan

Implementar apenas no Flutter com API atual, validar e distribuir nova versão. Sem migração de dados ou deploy do backend. Reverter a UI não remove registros já criados.

## Open Questions

Nenhuma bloqueante. Os comportamentos de confirmação, loading, fechamento, feedback, duplicatas e filtros foram acordados com o usuário.
