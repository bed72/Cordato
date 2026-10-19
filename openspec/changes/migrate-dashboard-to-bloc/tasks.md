## 1. Baseline e dependências

- [ ] 1.1 Revisar alterações locais de HTTP e a change introduce-exception-http-insight; confirmar os contratos executáveis e registrar sobreposições sem sobrescrever trabalho existente.
- [ ] 1.2 Mapear consumidores de commands, seções, cabeçalho e previews da Dashboard e registrar baseline de análise/testes e comportamento visual.
- [ ] 1.3 Adicionar versões compatíveis de bloc, flutter_bloc e bloc_concurrency, e bloc_test como dependência de desenvolvimento; executar flutter pub get.

## 2. Cancelamento independente do Dio

- [ ] 2.1 Criar capacidade framework-free de sinal/cancelamento e cancelamento tipado em core/domain, com testes de idempotência, sinal previamente cancelado e liberação de assinaturas.
- [ ] 2.2 Integrar sinal opcional ao HTTP e ponte por request para CancelToken, preservando requests sem sinal e removendo assinaturas em todos os caminhos terminais.
- [ ] 2.3 Testar com adapter controlável: cancelamento ativo, sinal cancelado antes do envio, várias requests do mesmo ciclo e isolamento de requests independentes ao mesmo endpoint.
- [ ] 2.4 Preservar cancelamento tipado antes dos catches genéricos do cliente e helper de resposta; testar que não vira status artificial, erro genérico ou sucesso vazio.

## 3. Propagação pelas leituras da Dashboard

- [ ] 3.1 Adicionar sinal opcional aos contratos e implementações de User.getById, Expense.get, Insight.get e Metrics.getExpenses e seus data sources, sem adicionar cancelamento às escritas.
- [ ] 3.2 Propagar cancelamento tipado antes dos catches genéricos dos repositories/data sources e manter mapeamentos atuais de falhas reais.
- [ ] 3.3 Atualizar todos os consumidores, mocks, fakes e previews afetados pelas assinaturas; preservar chamadas existentes sem sinal e commands fora da Dashboard.
- [ ] 3.4 Testar delegação do sinal e propagação de cancelamento por cada cadeia repository/data source/HTTP, incluindo leituras sem sinal, filtros, paginação e falhas reais.

## 4. Estado e ciclo financeiro do Bloc

- [ ] 4.1 Criar DashboardBloc, eventos e estado imutável específicos da tela, com mês, resultados/status das seções, usuário, limite e fase de recuperação; derivar disponibilidade das ações sem flags duplicadas no mixin.
- [ ] 4.2 Implementar uma coordenação compartilhada entre tipos de eventos financeiros, rejeitando eventos bloqueados antes de poderem interromper handlers aceitos; adicionar identidade e escopo de cancelamento por ciclo.
- [ ] 4.3 Implementar abertura paralela e troca mensal com intervalo civil, agrupamento de métricas, seis recentes e ano/mês de Insights; preservar limites, estados vazios e sucessos parciais independentes.
- [ ] 4.4 Migrar a leitura do primeiro mês para o fluxo Bloc: páginas sem ordem presumida, next opaco, detecção de repetição, null válido e interrupção de paginação após cancelamento.
- [ ] 4.5 Implementar refresh e alteração confirmada com releitura de limite, ajuste civil e três seções paralelas; alteração confirmada cancela e substitui imediatamente o ciclo vigente.
- [ ] 4.6 Implementar primeira falha financeira com ErrorScreen imediata, cancelamento das demais leituras financeiras e proteção contra conclusões, catches e finally antigos.
- [ ] 4.7 Implementar recuperação completa: User paralelo ao limite, seções após o limite, erro persistente até sucessos vigentes, bloqueio de retry repetido e isolamento de falhas auxiliares.
- [ ] 4.8 Implementar leitura de User com geração/cancelamento independentes, substituição após retorno de User/Settings e preservação de fallback e avatar; alteração financeira não cancela User.
- [ ] 4.9 Implementar fechamento idempotente e invalidação de retornos de navegação; cancelar todos os escopos e impedir novas páginas ou emissões tardias.
- [ ] 4.10 Conectar reporte único de exceções inesperadas expostas ao Bloc ao ICrashClient, sem reporte de falhas de negócio/cancelamentos nem alterações no handler global de CommandIt.

## 5. Testes determinísticos do Bloc

- [ ] 5.1 Criar doubles públicos em test/support e testar abertura, consultas com durações distintas, vazios válidos, limites mensais, virada de ano e fevereiro bissexto.
- [ ] 5.2 Testar bloqueio de seta, refresh e retry durante ocupação: sem cancelamento acidental, enfileiramento ou perda do ciclo vigente, inclusive entre tipos distintos de eventos.
- [ ] 5.3 Testar alteração confirmada durante abertura, refresh e recuperação: cancelamento imediato, leitura nova e nenhuma espera por Future antigo.
- [ ] 5.4 Testar resultados, erros e finally obsoletos com adapter que ignore cancelamento, garantindo que não alteram dados, mês, loading ou erro do ciclo novo.
- [ ] 5.5 Testar primeira falha e recuperação completa, falha repetida, falhas auxiliares, leitura antiga de User e reporte único de exceção inesperada.
- [ ] 5.6 Testar paginação histórica fora de ordem, continuação repetida, histórico vazio, ajuste do mês e interrupção antes da página seguinte após cancelamento.
- [ ] 5.7 Testar fechamento/substituição durante consulta e retornos obsoletos de navegação; remover subscriptions e fechar todos os recursos criados nos testes.

## 6. Integração visual e propriedade dos recursos

- [ ] 6.1 Registrar/criar um Bloc por Dashboard no módulo da rota, definir único proprietário do fechamento e preservar callbacks e argumentos de navegação existentes.
- [ ] 6.2 Adaptar DashboardScreen, cabeçalho e seções para dados/status do Bloc com BlocBuilder/BlocSelector, sem commands ou cópias de estado no mixin.
- [ ] 6.3 Reduzir ou remover DashboardScreenStateMixin conforme necessidade visual; manter navegação fora do Bloc e encaminhar alteração confirmada somente ao Bloc vigente.
- [ ] 6.4 Adicionar skeletons no lugar dos dois controles mensais durante carregamento normal, preservando mês/ano, dimensões e ausência de foco/callbacks/ações semânticas nos placeholders.
- [ ] 6.5 Preservar ErrorScreen sem AppBar, textos, FAB, seis recentes, cards, avatar, estados vazios e navegação; manter seletor e conteúdo normal ocultos no erro/recuperação.
- [ ] 6.6 Adaptar previews e seus recursos; remover GetFirstExpenseMonthCommand e testes exclusivos após confirmar ausência de outros consumidores e cobertura equivalente do Bloc.

## 7. Documentação e verificação final

- [ ] 7.1 Atualizar ARCHITECTURE.md e AGENTS.md com o piloto Bloc, propriedade de recursos, direção de dependências, cancelamento e convivência temporária com commands; revisar README conforme impacto.
- [ ] 7.2 Atualizar testes arquiteturais aplicáveis para manter domínio livre de Dio/Bloc/Flutter e apresentação livre de clientes HTTP, sem criar testes de widgets ou módulos Modular.
- [ ] 7.3 Executar flutter pub get, flutter analyze e flutter test, incluindo test/architecture; registrar falhas anteriores ou externas sem ocultá-las.
- [ ] 7.4 Validar com Maestro abertura, skeleton dos controles e bloqueio mensal, troca de mês, erro global/retry e retorno com e sem alterações; confirmar dispositivos e hierarquia antes de executar flows.
- [ ] 7.5 Validar a change com openspec validate migrate-dashboard-to-bloc --strict e revisar o diff final: sem mudanças de telas fora do escopo além de adaptações obrigatórias de contratos, sem commands na Dashboard e sem estado financeiro duplicado.
- [ ] 7.6 Comparar a complexidade total com o baseline: eliminar validações de snapshots e microtasks de pendência em vez de somente transferir o mixin para outro arquivo; registrar resultado antes de propor expansão para outra tela.
