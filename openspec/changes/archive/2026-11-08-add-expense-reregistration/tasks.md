## 1. Estado e criação na listagem

- [x] 1.1 Adicionar evento concreto e estados sealed de recadastro ao ExpensesBloc, preservando dados imutáveis, ownership e contrato existente.
- [x] 1.2 Delegar a IExpenseRepository.create com descrição, centavos e categoria copiados e data civil explícita; tratar ExpenseException, MissingAuthenticatedUserException e erros inesperados conforme arquitetura.
- [x] 1.3 Definir droppable, busy e coordenação entre recadastro, consultas, paginação, edição e exclusão; proteger respostas antigas e fechamento pendente sem flags paralelas de lifecycle.
- [x] 1.4 Recarregar a primeira página após criação confirmada com os filtros ativos; separar falha da recarga de falha da criação e impedir novo POST automático.

## 2. Confirmação e feedback

- [x] 2.1 Criar widget público de confirmação assíncrona na feature Expense, reutilizando scaffold e botões do core sem alterar o comportamento dos consumidores de confirmação existentes.
- [x] 2.2 Conectar long press e ação semântica ao fluxo, preservando swipes de edição e exclusão, sem edição por toque simples; capturar o dia local ao confirmar e representá-lo como meia-noite UTC sem conversão.
- [x] 2.3 Renderizar loading pelo estado do Bloc, bloquear botões e fechamento durante envio e fechar somente a bottom-sheet correspondente ao concluir; manter recursos e handlers substanciais nos mixins específicos.
- [x] 2.4 Mostrar toast único após fechamento com textos de sucesso acordados e erro local pelo formatter, com título curto, descrição segura e fallback definido.

## 3. Testes unitários e previews

- [x] 3.1 Cobrir no Bloc estado inicial, delegação exata inclusive categoria other, cópia de despesa de hoje, sucesso, erros esperados preservados, identidade ausente, erro inesperado e retry manual.
- [x] 3.2 Cobrir concorrência com Completer: submissões descartadas, interação com consulta/exclusão, respostas antigas, fechamento pendente e falha de recarga sem repetir criação.
- [x] 3.3 Cobrir preservação dos filtros e paginação, inclusive data fora do intervalo, e conversão de data civil com entradas determinísticas; adicionar testes unitários do formatter para mensagens seguras.
- [x] 3.4 Conferir cobertura existente do repository para payload de criação, owner, data, categoria e sinalização de atualização do widget, complementando somente lacunas com SDK real e transporte mockado.
- [x] 3.5 Atualizar previews com ownership explícito e cenários de sucesso, falha e loading sem rede; compilar pelo catálogo compartilhado, sem criar testes de UI.
- [x] 3.6 Conferir manualmente confirmação, ordem dos botões, loading, bloqueio de fechamento, cancelamento, toast e acessibilidade nos previews/dispositivo. Teste manual confirmado pelo usuário antes do arquivamento.

## 4. Documentação e verificação

- [x] 4.1 Atualizar README.md com o atalho e seus limites e ARCHITECTURE.md com a coordenação adotada, preservando a ausência de dependências entre Blocs/features.
- [x] 4.2 Executar flutter pub get, flutter analyze e flutter test, incluindo arquitetura e testes da feature; registrar resultados e bloqueios reais sem alegar homologação remota ou build nativo não executado.
