## 1. Estado ativo dos filtros

- [x] 1.1 Conferir `ExpensesScreen`, seu mixin, widgets usados, previews e testes correspondentes; verificar o export de `InputChip` em `material_ui` e a referência visual de Cordato.
- [x] 1.2 Inicializar `activeCategory` e `activePeriod` pelos parâmetros da tela antes da primeira consulta, preservando os contratos públicos e a rota existente.
- [x] 1.3 Atualizar rótulos, vazio, consultas e pertencimento após edição para usar exclusivamente filtros ativos; manter rótulo pt-BR conhecido e fallback textual para categoria futura.
- [x] 1.4 Preservar filtros locais em rebuilds e troca isolada do command; reinicializar a lente somente após mudança efetiva nas entradas, respeitando o descarte da instância anterior.

## 2. Transição de consulta após remoção

- [x] 2.1 Criar handlers independentes para remover categoria ou período, limpando os dois limites civis juntos no segundo caso e sem chamar `onExpensesChanged`.
- [x] 2.2 Centralizar a disponibilidade da remoção e verificar as mesmas condições nos handlers: consultas, edição e confirmação/execução de exclusão bloqueiam a interação.
- [x] 2.3 Reiniciar itens, cursor, flags de resultado/erro e retry; preservar o controller e voltar ao topo com verificação de montagem e `hasClients`.
- [x] 2.4 Consultar a primeira página com tamanho 20, continuação nula e apenas filtros restantes; impedir que links da lente anterior sejam reutilizados.
- [x] 2.5 Apresentar skeleton inicial sem resultados antigos durante troca de lente; manter erro e filtros novos após falha, com retry da primeira página e possibilidade de remover o filtro restante.
- [x] 2.6 Preservar comportamento de refresh/paginação da mesma lente: itens retidos em falha, retry da operação correta e envio dos filtros ativos em todas as consultas.
- [x] 2.7 Proteger respostas, alterações de flags em finalizações e callbacks post-frame pela identidade do command e revisão atual; impedir novas páginas após descarte.
- [x] 2.8 Tratar reconfiguração de entradas durante execução do mesmo command sem concorrência: aguardar o término e disparar uma única primeira página da configuração vigente, invalidando trabalho pendente obsoleto.

## 3. Pílulas e composição do cabeçalho

- [x] 3.1 Criar `ExpensesFiltersWidget` público, `final`, com primary constructor `const`, parâmetros de rótulo e callbacks anuláveis, no diretório de widgets da tela.
- [x] 3.2 Compor `InputChip` com ícone de fechar à direita, ação nativa `onDeleted`, `BounceWidget` e estilo baseado no tema/referência; preservar alvo Material acessível e não adicionar ação ao corpo da pílula.
- [x] 3.3 Usar `Wrap` com espaçamentos horizontal/vertical de 8 pixels, categoria antes do período e quebra de linha sem truncamento; usar rótulo mensal com ano ou limites civis para intervalo não mensal.
- [x] 3.4 Restaurar descrição fixa “Acompanhe todas as suas despesas.” e inserir as pílulas 12 pixels abaixo dela somente quando existirem filtros.
- [x] 3.5 Manter pílulas no cabeçalho da lista lazy, fora da exclusão semântica do texto; configurar rótulos de remoção localizados e garantir que callbacks desabilitados não exponham ações executáveis.

## 4. Previews e documentação

- [x] 4.1 Atualizar previews da tela para categoria + mês, somente mês, somente categoria, ausência de filtros, loading, erro e vazio, usando os widgets reais e fakes existentes.
- [ ] 4.2 Verificar nos previews o layout em temas claro/escuro, largura reduzida, escala de texto ampliada e categorias com nomes longos, sem overflow ou perda do alvo de toque.
- [x] 4.3 Atualizar `ARCHITECTURE.md`, `README.md` e `AGENTS.md` para descrever descrição fixa, pílulas, filtros locais, remoção independente e diferença entre troca de lente e refresh.

## 5. Verificação automatizada e revisão

- [x] 5.1 Formatar apenas arquivos Dart alterados; executar `flutter analyze` e `flutter test`, registrando qualquer falha ou bloqueio. Executar `flutter pub get` antes dessas verificações somente se aplicável por alteração de dependências/configuração.
- [x] 5.2 Conferir que os testes existentes de consulta continuam cobrindo filtros e paginação; se alguma camada testada precisar mudar, atualizar seus testes sem criar testes Flutter de widgets/screens/rotas ou abstrações artificiais de testabilidade.
- [x] 5.3 Revisar o diff para garantir preservação da navegação por categoria, “Ver tudo”, contracts HTTP, agrupamentos, descarte e alterações existentes do usuário; confirmar ausência de comentários novos no Dart e de credenciais nos artefatos.

## 6. Validação de interação com Maestro

- [ ] 6.1 Preparar build atualizado e sessão de desenvolvimento com despesas em categorias/meses distintos e histórico suficiente para mais de uma página; descobrir dispositivo e inspecionar hierarquia antes de escrever seletores. Registrar bloqueio se sessão/dispositivo/dados não estiverem disponíveis.
- [ ] 6.2 Validar abertura pelo card e por “Ver tudo”, descrição fixa, ordem das pílulas, remoção de categoria mantendo mês e remoção de mês mantendo categoria, verificando queries/resultados correspondentes.
- [ ] 6.3 Validar as duas ordens de remoção até consulta geral, retorno ao topo, ausência de itens/cursor antigos, paginação de 20 itens e persistência dos filtros restantes em refresh e retry.
- [ ] 6.4 Validar loading e toques rápidos, bloqueio durante edição/exclusão e recuperação após falha; confirmar que uma remoção bloqueada não executa depois automaticamente.
- [ ] 6.5 Validar erro na primeira página da nova lente, erro de refresh/paginação e vazio contextual, mantendo filtros novos e sem reintroduzir mês/categoria removidos.
- [ ] 6.6 Validar que editar a data após remover mês mantém a despesa no histórico quando pertence à categoria ativa, e que exclusão/reordenação continuam preservando grupos, rolagem e paginação.
- [ ] 6.7 Validar voltar sem mutações após remover filtros, preservando o mês da Dashboard sem recarga financeira; reabrir pelo card deve restaurar os filtros enviados nessa nova abertura. Confirmar o retorno com recarga após edição/exclusão bem-sucedida em dados de demonstração.
- [ ] 6.8 Validar ações de remoção acessíveis, estados desabilitados, layout claro/escuro e texto ampliado; registrar resultados e limitações sem declarar cenários bloqueados como executados.

## Verificação parcial após o step 3

- `flutter analyze` sem apontamentos e `flutter test --reporter failures-only` com 642 testes aprovados.
- Maestro no Android, com a tela real e os fakes de preview existentes: descrição fixa, remoção nas duas ordens, preservação do filtro restante, corpo sem ação de remoção e ações nativas com rótulos localizados.
- Durante loading, o rótulo permanece visível e desabilitado, sem ação acessível de remoção. Screenshot conferido no tema escuro.
- A execução com a API abriu a tela de boas-vindas após tentar carregar a sessão; a validação autenticada permanece pendente. Os cenários com fakes não validam queries HTTP nem retorno à Dashboard.
- O launcher temporário foi removido e o build com `lib/main.dart` foi reinstalado no dispositivo.

## Encerramento e arquivamento

- Arquivamento e sincronização das specs principais autorizados pelo usuário com as pendências preservadas.
- Verificação final: quatro arquivos Dart alterados já formatados, `flutter analyze` sem apontamentos e 642 testes aprovados.
- Os testes existentes de command, repository e data source continuam cobrindo filtros e paginação; essas camadas e seus contratos não foram alterados.
- A validação em 320 pixels com texto ampliado em 2× revelou rótulos multilinha fora do fundo do chip. A tentativa de medição manual foi removida a pedido do usuário; o widget mantém a composição simples e os ajustes de estilo do usuário. A tarefa 4.2 continua pendente.
- As tarefas 6.1–6.8 permanecem pendentes: a validação parcial com fakes não equivale ao fluxo autenticado, às queries HTTP ou aos cenários completos de edição, exclusão, refresh, retry e retorno à Dashboard.
