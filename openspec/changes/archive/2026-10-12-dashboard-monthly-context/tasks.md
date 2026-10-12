## 1. Consultas de despesas por período

- [x] 1.1 Ler as camadas de Expense, widgets compartilhados, testes e alterações locais; adicionar `from`/`to` opcionais aos contratos e implementação do repository e data source.
- [x] 1.2 Serializar filtros civis pelo helper existente e manter endpoint protegido relativo, tradução de erros e validação integral das páginas.
- [x] 1.3 Ajustar composição da query de paginação para reaplicar intervalo explícito e tamanho, remover filtros temporais incompatíveis e preservar a continuação e demais parâmetros.
- [x] 1.4 Evoluir o record de `GetExpensesCommand` e atualizar todos os consumidores, previews, doubles e testes no mesmo conjunto de alterações.
- [x] 1.5 Testar delegação com e sem intervalo, limite incompleto sem default, serialização sem conversão de fuso, paginação sem/com filtros conflitantes, erros por pointer, centavos inválidos e descarte do command.

## 2. Consultas mensais de insights

- [x] 2.1 Ler as camadas de Insight e testes; adicionar ano/mês opcionais aos contratos, repository e data source e enviar somente filtros não nulos.
- [x] 2.2 Evoluir `GetInsightsCommand` para receber ano/mês e atualizar todos os consumidores, previews, doubles e testes.
- [x] 2.3 Testar consulta mensal e geral, filtro incompleto com erro `source.parameter`, preservação de análise com período de vários meses, período nulo, vazio, parsing inválido e descarte.

## 3. Contexto mensal da Dashboard

- [x] 3.1 Ler Dashboard, Metrics, widgets compartilhados e alterações locais; substituir o estado exclusivo de Metrics pelo mês compartilhado e calcular seu intervalo civil.
- [x] 3.2 Compor o seletor como controle da Dashboard, mantendo mês/ano visíveis em todos os estados e impedindo avanço além do mês atual, sem swipe mensal.
- [x] 3.3 Consultar as três seções em paralelo com o mesmo mês em abertura, troca, refresh e retorno; apresentar loading sem dados antigos sob o novo título.
- [x] 3.4 Coordenar bloqueio das setas durante qualquer consulta, incluindo retry, liberando após sucesso ou erro; descartar listeners e impedir atualizações obsoletas de lifecycle.
- [x] 3.5 Oferecer retry independente em cada seção, incluindo recentes, e ajustar vazio mensal preservando o comportamento dos insights vazios e gráfico com total zero.

## 4. Listagem mensal e retorno do cadastro

- [x] 4.1 Fazer o callback de “Ver tudo” transportar o mês e a rota `/expenses` receber um intervalo tipado opcional; manter a entrada geral sem argumento.
- [x] 4.2 Exibir mês/ano e semântica do recorte na listagem e manter o intervalo em abertura, páginas de 20, refresh e retry, preservando os agrupamentos.
- [x] 4.3 Ajustar retorno de edição para remover itens movidos para fora do período ou reposicioná-los dentro dele, preservando rolagem, paginação e comportamento de exclusão.
- [x] 4.4 Ajustar retorno de cadastro iniciado pela Dashboard para preservar seu mês após toque simples ou cancelamento; manter hoje como data inicial, hold e acesso independente ao cadastro.

## 5. Documentação e previews

- [x] 5.1 Atualizar previews e fakes afetados para contexto mensal, loading, vazio, falha e listagem filtrada, usando os contratos novos e o wrapper existente.
- [x] 5.2 Atualizar `ARCHITECTURE.md`, `AGENTS.md` e `README.md` com contexto mensal, queries, paginação filtrada e contratos de navegação, preservando alterações locais do usuário.

## 6. Verificação

- [x] 6.1 Executar `flutter pub get`, `flutter analyze` e `flutter test`, nessa ordem; registrar e corrigir falhas relacionadas sem adicionar testes Flutter de widgets, screens, tema, módulos ou rotas.
- [ ] 6.2 Confirmar em execução a API para mês atual explícito, histórico, vazio e paginação filtrada; verificar formato dos erros com filtros incompletos sem persistir credenciais.
- [ ] 6.3 Validar com Maestro abertura, setas, limite do mês atual, virada de ano/fevereiro, loading agregado, falha parcial, retries e rolagem horizontal dos insights sem troca de mês.
- [ ] 6.4 Validar com Maestro “Ver tudo” no mês, paginação, refresh, edição dentro/fora do recorte, exclusão e retorno à Dashboard com o mês preservado.
- [ ] 6.5 Validar com Maestro cadastro com data inicial de hoje, retorno por toque simples, cancelamento, hold e entrada independente, incluindo mês histórico preservado; registrar resultados e bloqueios reais antes de concluir.

## Registro da Etapa 1 — Contratos e consultas mensais

- Grupos 1 e 2 concluídos, com consumidores atuais e previews mantendo filtros nulos.
- `flutter pub get`: concluído.
- `flutter analyze`: sem apontamentos.
- `flutter test`: 543 testes passaram, incluindo camadas de dados e commands de Expense e Insight.
- Contratos e composição de queries documentados em `ARCHITECTURE.md`, `AGENTS.md` e `README.md`.
- A coordenação mensal da Dashboard, navegação contextualizada e validações reais de API/Maestro pertencem às etapas seguintes.

## Registro da Etapa 2 — Dashboard com contexto mensal

- Grupo 3 implementado: mês compartilhado, intervalo civil, consultas paralelas, seletor da Dashboard, limite do mês atual e bloqueio agregado durante consultas e retries.
- As seções renovam suas chaves por mês e apresentam skeleton durante a troca; erros e retries são independentes. Recentes possuem vazio mensal e Insights vazios continuam ocultos.
- Refresh e retorno à mesma instância da Dashboard preservam a seleção. Listeners são removidos antes do descarte e retornos obsoletos de navegação são ignorados.
- Previews afetados pelos contratos de seção e documentação atualizados para o comportamento desta etapa.
- `flutter pub get`: concluído. `flutter analyze`: sem apontamentos. `flutter test`: 543 testes passaram.
- Validação de interação com Maestro pendente: a descoberta de dispositivos retornou todos com `connected: false`. É necessário iniciar um simulador/emulador com o app atualizado para confirmar visualmente o critério de conclusão e os cenários de loading, falhas e retry.
- As tarefas de navegação contextualizada do grupo 4 e a validação completa da change continuam pendentes.

## Registro da Etapa 3 — “Ver tudo” contextualizado

- Tarefas 4.1 a 4.3 implementadas. O callback recebe o mês selecionado e `/expenses` transporta o record opcional `({DateTime from, DateTime to})`; sem argumento mantém a listagem geral.
- Header, semântica e vazio identificam mês/ano. A carga centralizada preserva o intervalo em abertura, páginas de 20, refresh e retry, mantendo os agrupamentos existentes.
- Edição compara datas civis com limites inclusivos: fora do período remove o item; dentro dele substitui ou reposiciona. Edição e exclusão preservam controller e continuação e verificam se é necessário carregar mais itens.
- Contratos de navegação e comportamento da listagem documentados em `ARCHITECTURE.md`, `AGENTS.md` e `README.md`.
- `flutter pub get`: concluído. `flutter analyze`: sem apontamentos. `flutter test`: 543 testes passaram. `git diff --check`: sem apontamentos. `openspec validate dashboard-monthly-context`: válido.
- Validação interativa do critério de conclusão permanece pendente na tarefa 6.4: Maestro retornou todos os dispositivos com `connected: false`. Iniciar um simulador/emulador com o app atualizado para confirmar paginação, refresh, edição dentro/fora do mês, exclusão e retorno à Dashboard.

## Registro da Etapa 4 — Retorno do cadastro

- Tarefa 4.4 implementada. A Dashboard empilha `/expense` com o record `(returnToPrevious: true)`; sucesso por toque simples fecha o formulário com `pop`, mantendo a instância e o mês selecionado. Cancelamento retorna pela mesma pilha.
- A Dashboard recarrega recentes, insights e métricas em paralelo no mês preservado. Se alguma consulta ainda estiver em execução no retorno, a recarga aguarda o término de todas, inclusive falhas; troca de dependências e descarte invalidam retornos pendentes.
- O formulário continua iniciando com hoje. Hold mantém o comportamento de limpar após sucesso e permanecer aberto. Sem argumento ou com `returnToPrevious: false`, sucesso no cadastro independente navega para `/dashboard`. ID textual mantém o fluxo de edição.
- Documentação dos contratos e lifecycle atualizada em `ARCHITECTURE.md`, `AGENTS.md` e `README.md`.
- `flutter pub get`: concluído. `flutter analyze`: sem apontamentos. `flutter test`: 543 testes passaram. `git diff --check`: sem apontamentos. `openspec validate dashboard-monthly-context`: válido.
- O critério de conclusão ainda precisa de confirmação interativa na tarefa 6.5. Maestro retornou todos os dispositivos com `connected: false`; é necessário iniciar um simulador/emulador com o app atualizado para validar mês histórico, data inicial de hoje, toque simples, cancelamento, hold e entrada independente.
