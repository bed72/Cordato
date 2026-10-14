## 1. Baseline e plano de corte por command

- [x] 1.1 Reconfirmar CommandIt 9.5.2, listen_it 6.0.0, Modular 7.1.1 e auto_injector 2.2.0 no lockfile e package_config; confrontar APIs usadas com o código instalado, sem upgrade.
- [x] 1.2 Reabrir DashboardScreenStateMixin, ExpenseScreenStateMixin, ExpensesScreenStateMixin, seus widgets, componentes compartilhados e testes antes de editar; registrar baseline de resultados, erros, loading, subscriptions e guards.
- [x] 1.3 Inspecionar status/diff e a change ativa `unify-dashboard-error-screen`; registrar divergência do cabeçalho e preservar suas tarefas/arquivos e a experiência visual vigente.
- [x] 1.4 Enumerar todos os consumidores de cada um dos dezesseis commands migrados, incluindo telas, seções, previews, fakes, testes e módulos; definir unidades completas de migração sem consumers incompatíveis entre etapas.
- [x] 1.5 Confirmar matriz de propriedade das instâncias factory, lazy singletons de feature e root; registrar quais widgets somente observam e quais descartam cada recurso.
- [x] 1.6 Executar os checks aplicáveis ao baseline e registrar falhas anteriores, sem corrigir código não relacionado; confirmar ambiente de validação e acesso seguro aos cenários financeiros.

## 2. Dashboard primeiro: simplificação mínima com Either ainda vigente

- [x] 2.1 Remover os três listeners redundantes de errors em `_financialSignals` e a releitura redundante de errors em `_failed`, usando results para exceção e Left durante esta etapa intermediária.
- [x] 2.2 Separar a ativação de hasFinancialError, a liberação de refresh pendente e a reconstrução visual em callbacks/handlers específicos, preservando a detecção imediata por results.
- [x] 2.3 Fazer seletor e disponibilidade do retry observarem execution listenables pertinentes declarativamente, mantendo builders de seção e evitando setState global vazio para dados já observados.
- [x] 2.4 Preservar `_dependenciesVersion`, `_refreshPendingAfterNavigation`, `_userRefreshPending`, `_isRefreshingDashboard`, isRecovering, hasFinancialError e `_isOpeningExpenses`; revisar a finalidade de cada controle sem criar gerenciador ou command agregador.
- [x] 2.5 Verificar ordem terminal de results/isRunning/value e o scheduling de pendências; não disparar request reentrante nem perder intenção quando a última consulta termina.
- [x] 2.6 Validar abertura, setas bloqueadas, erro imediato/persistente, recuperação e retorno de navegação antes da migração dos tipos; registrar evidências e limitações reais.

Registro da Parte 1: [baseline, inventário, propriedade, implementação e evidências](implementation-part-1.md).
O usuário confirmou a validação da Parte 1 e autorizou a próxima etapa. As tarefas
1.6 e 2.6 foram encerradas por esse aceite, junto aos checks já aprovados.
Não foram fornecidos dispositivo, relatório ou detalhes dos cenários; esse aceite
não representa execução Maestro pelo agente nem cobertura adicional demonstrada.

## 3. Fronteira tipada e fallback nativo de erros

- [x] 3.1 Criar `lib/features/core/presentation/commands/command_failure_exception.dart` com tipo final mínimo que implementa Exception, primary constructor apropriado e ErrorsEntity original obrigatório, sem helper genérico ou DI.
- [x] 3.2 Criar teste unitário de transporte sob `test/features/core/presentation/commands/`, verificando identidade, metadados completos, ordem, nulabilidade e lista vazia, sem testes de UI.
- [x] 3.3 Instalar Command.globalExceptionHandler no bootstrap de `lib/main.dart` após resolver ICrashClient e antes dos consumidores; manter filtro GlobalIfNoLocalErrorFilter, falha tipada sem telemetry/efeito visual e fallback inesperado não fatal com erro/stack.
- [x] 3.4 Confirmar que a composição não cria subscriptions por rebuild, não adiciona paramData à telemetry, não altera FlutterError/PlatformDispatcher indevidamente nem habilita reportAllExceptions.
- [x] 3.5 Exercitar runAsync de um command real sem handler local com falha tipada e exceção inesperada, comprovando conclusão do Future e destino global, restaurando configuração estática ao fim do teste.
- [x] 3.6 Exercitar falha local com Future em erro, comprovando ausência de feedback/reporte duplicado e mantendo a política de AssertionError existente.
- [x] 3.7 Documentar em ARCHITECTURE.md a fronteira repository-Either/command-exception e a política local-first/global fallback, sem descrever domínio como orientado a exceptions.

Registro do grupo 3: [fronteira tipada, fallback e testes](implementation-part-2.md).

## 4. Consultas compartilhadas: commands e todos os consumidores

- [x] 4.1 Migrar GetExpensesCommand para ExpensePageEntity anulável com switch Right/Left; na mesma unidade adaptar DashboardScreenStateMixin, ExpensesSectionWidget, ExpensesScreen/mixin, previews e testes, mantendo acúmulo exclusivamente no consumidor.
- [x] 4.2 Migrar GetInsightsCommand para lista de InsightEntity anulável; adaptar InsightsSectionWidget, Dashboard, previews e testes preservando filtros opcionais, ordem, vazio e período nulo.
- [x] 4.3 Migrar GetExpenseMetricsCommand para ExpenseMetricsEntity anulável; adaptar MetricsSectionWidget, Dashboard, previews e testes preservando total zero e categorias ausentes/vazias.
- [x] 4.4 Migrar UserCommand para UserEntity anulável; adaptar UserNameWidget, UserScreen/mixin, Dashboard e previews/testes preservando saudação, nome/seed e fallback Trocado.
- [x] 4.5 Migrar GetFirstExpenseMonthCommand para DateTime anulável com falha tipada, mantendo pages não ordenadas, next opaco, página vazia com continuação, links repetidos e interrupção cooperativa após dispose sem lançar erro artificial de descarte.
- [x] 4.6 Adaptar Dashboard à saída do limite, distinguindo conclusão válida nula de erro/estado inicial e preservando ajuste civil da seleção e bloqueio anterior em falha.
- [x] 4.7 Usar onData/onNullData nos builders que consomem dados e remover releituras de value para decidir sucesso/erro; manter builders de botão que ignoram o retorno.
- [x] 4.8 Atualizar as suítes de consultas para resultados nativos, CommandFailureException no Future/results/errors, inputs intactos, retry, isolamento e valores vazios, sem alterar stubs de repository para abandonar Either.
- [x] 4.9 Verificar instâncias e descartes dos previews afetados, atualizar contratos descritos em ARCHITECTURE.md/AGENTS.md e executar análise e testes das unidades migradas.

Registro do grupo 4: [consultas nativas, consumidores, propriedade e checks](implementation-part-3.md).

## 5. Dashboard: recuperação com canal nativo e tentativas válidas

- [x] 5.1 Remover a interpretação de Left na Dashboard migrada, usando snapshot terminal com hasError sem observar errors adicionalmente para o mesmo latch.
- [x] 5.2 Manter observação financeira durante ErrorScreen/recuperação e validar que User/limite sem builders locais continuam com fallback global real.
- [x] 5.3 Adaptar refreshExpenses/refreshInsights/refreshMetrics para sucesso da execução corrente, sem consultar value antigo, isSuccess inicial ou Future compartilhado como prova da tentativa solicitada.
- [x] 5.4 Preservar exclusão mútua antes do primeiro await, User em paralelo ao limite na recuperação, limite antes das seções e Future.wait das três consultas com mês vigente.
- [x] 5.5 Preservar latch imediato e persistente, isRecovering iniciado por contexto, loading até o fim do ciclo e liberação somente após três sucessos financeiros válidos, inclusive com falhas auxiliares.
- [x] 5.6 Garantir que a intenção financeira após navegação produz nova leitura quando ficar ocioso, coalescendo sinais e sem consumir a intenção aderindo à execução anterior.
- [x] 5.7 Garantir nova leitura de User após retorno de User/Settings quando uma consulta antiga estiver ocupada, limpando a intenção ao mudar command ou descartar.
- [x] 5.8 Revalidar mounted/versão/identidade em continuations e finally, impedindo que resultado ou descarte antigo altere flags, mês ou latch de um ciclo novo.
- [x] 5.9 Executar matriz Maestro da Dashboard e registrar consultas observadas, resultado visual, ausência de retry extra e limitações de reprodução de dependências.

Registro do grupo 5: [tentativas válidas, pendências, fallback e limites de validação](implementation-part-4.md).
O usuário informou que iniciou o app, confirmou “tudo ok” e autorizou avançar
para o próximo step. A tarefa 5.9 foi encerrada por esse aceite; não foi fornecido
relatório da matriz e esse encerramento não representa execução Maestro da
Dashboard pelo agente nem cobertura adicional demonstrada.

## 6. Consulta simples de ExpenseScreen

- [x] 6.1 Migrar GetExpenseCommand para ExpenseEntity anulável, preservando ID e adaptação tipada; atualizar seu teste para valor nativo e erro original/tipado nos observáveis.
- [x] 6.2 Remover expense, loadErrors e isLoading copiados em ExpenseScreenStateMixin; usar onData/whileRunning/onError/onNullData em ExpenseScreen com feedback localizado existente.
- [x] 6.3 Comparar paramData com widget.id para impedir entidade/erro de ID antigo, mantendo skeleton para snapshot incompatível e criação sem GET.
- [x] 6.4 Preservar uma coordenação pequena para ID final vigente enquanto command estiver ocupado, sem fila de IDs intermediários nem adesão interpretada como execução nova.
- [x] 6.5 Preservar propriedade de Get/Create/Update na screen, cancelamento das assinaturas do formulário e invalidação por troca/descarte, sem dispose duplicado.
- [x] 6.6 Adaptar previews existentes e validar via Maestro loading acessível, sucesso, erro esperado/inesperado e retry sem request duplicada; registrar verificação técnica dos cenários A/B/C quando não expostos pelo fluxo.

Registro do grupo 6: [consulta nativa, ID vigente, edição no iOS e validação restante](implementation-part-5.md).

## 7. Mutações de Expense e feedback do formulário/listagem

- [x] 7.1 Migrar CreateExpenseCommand com ExpenseFormWidget/mixin, consumers/previews/testes para entidade nativa e falha tipada, preservando criação por toque e hold.
- [x] 7.2 Migrar UpdateExpenseCommand com formulário/screen/listagem e testes para entidade nativa, preservando PATCH parcial, ID, descrição, centavos e comparação civil.
- [x] 7.3 Adaptar `_handleCreation` e `_handleUpdate` para snapshot terminal, erro antes dos dados, pointers remotos preservados, fallback inesperado e efeitos uma única vez fora do build.
- [x] 7.4 Manter controllers, validação, `_isPickerOpen`, `_keepFormOpenAfterCreation`, dados em falha, reset após sucesso por hold e callbacks de alteração/navegação nos proprietários atuais.
- [x] 7.5 Migrar DeleteExpenseCommand com confirmação e testes para bool anulável, preservando false sem confirmação, true com remoção e falha tipada com feedback único.
- [x] 7.6 Preservar pendingDeleteId, finalização de dismiss, thresholds, ações acessíveis, rolagem, continuação, remoção/reposicionamento por filtros e verificação de necessidade de mais itens.
- [x] 7.7 Validar Maestro criação simples, hold bem-sucedido/falho/interrompido, picker cancelado, edição parcial e exclusão confirmada/cancelada/falha, sem alterar UX.
- [x] 7.8 Atualizar documentação dos contratos e executar testes de Create/Update/Delete e checks afetados na mesma unidade das alterações.

Registro do grupo 7: [mutações nativas, checks e evidências parciais de interação](implementation-part-6.md).
A tarefa 7.7 foi encerrada por aceite explícito do usuário com as evidências
registradas, sem execução adicional ou ampliação da cobertura demonstrada.
O launcher temporário autorizado foi removido.

## 8. Listagem: remover somente loading derivável

- [x] 8.1 Revisar cada intervalo de isLoading na listagem e substituir cópia de request por execução do command quando equivalente; documentar intervalo local legítimo se algum controle precisar permanecer.
- [x] 8.2 Preservar expenses, hasLoaded, feedback aceito por revisão, nextPageLink, `_retryRefresh`, `_queryRevision`, `_pendingRefreshRevision`, filtros e controller.
- [x] 8.3 Garantir incorporação de página única por operação válida e ausência de efeitos de result/error/finally antigos após troca de lente ou command.
- [x] 8.4 Garantir que refresh/paginação falhos preservam itens e repetem operação correta; remover filtros limpa lente, mantém novos parâmetros e solicita primeira página ao ficar disponível.
- [x] 8.5 Verificar oito placeholders sem itens, três com itens, anúncio de loading, bloqueios de interação, agrupamentos e ausência de flash de vazio.
- [x] 8.6 Validar Maestro filtros combinados, remoção individual, paginação, refresh/retry, edição para fora da lente e exclusão do último item de grupo; registrar efeitos preservados e reduções reais.

Registro do grupo 8: [loading derivado, tentativas válidas e checks](implementation-part-7.md).
A tarefa 8.5 foi verificada por inspeção de composição e scheduling, sem execução
visual adicional. O usuário recusou outro launcher temporário e posteriormente
autorizou encerrar a tarefa 8.6 por aceite explícito e avançar ao step 9, sem
repetir a matriz Maestro nem atribuir cobertura nova aos registros anteriores.

## 9. User: resultados nativos e estado legítimo de avatar

- [x] 9.1 Migrar UpdateUserCommand com EditUserScreen/mixin, consumers/previews/testes para UserEntity anulável, preservando nameFailure, validação, toast e retorno por callback injetado.
- [x] 9.2 Migrar UpdateAvatarCommand com UserScreen/mixin/previews/testes para UserEntity anulável e falha tipada, mantendo verificação de seed da resposta.
- [x] 9.3 Preservar timer de dois segundos, escolha temporária e avatarUser quando necessário; cancelar timer na troca/descarte/exclusão e manter ausência de retry automático.
- [x] 9.4 Migrar DeleteUserCommand e handlers/testes para bool anulável, preservando true/false, limpeza de storage exclusivamente pelo repository e navegação pela observação de sessão.
- [x] 9.5 Validar que erro tipado com lista vazia usa fallback sem throw secundário, e que value antigo não confirma nome/avatar/exclusão de uma tentativa falha.
- [x] 9.6 Validar via Maestro consulta, edição de nome, regeneração coalescida de avatar, seed não devolvida quando reproduzível e confirmação de exclusão em ambiente apropriado, sem descarte manual de singletons do módulo.

Registro do grupo 9: [mutações nativas de User, lifecycle e checks](implementation-part-8.md).
9.1–9.5 foram implementadas e verificadas por testes de commands e inspeção dos
consumidores. 9.6 foi encerrada por aceite explícito do usuário, sem execução
Maestro adicional. Nenhum launcher temporário foi criado ou solicitado novamente,
e não houve alteração de dados da conta em dispositivo.

## 10. Authentication e Settings: migração completa dos consumers

- [x] 10.1 Migrar SignInCommand com SignInScreen/mixin, builders e testes para SessionEntity anulável, preservando credenciais, erro de campo e transição por SessionCommand.
- [x] 10.2 Migrar SignUpCommand com SignUpScreen/mixin/builders/testes para bool anulável, preservando true com confirmação, false sem navegação e falhas esperadas no contexto.
- [x] 10.3 Migrar ResendEmailCommand com tela/mixin/previews/teste no caminho atual existente para bool anulável, preservando cooldown e false sem anúncio de sucesso.
- [x] 10.4 Migrar LogoutCommand com SettingsScreen/mixin/previews/testes para bool anulável, mantendo confirmação, revogação/limpeza no repository e um feedback de erro contextual.
- [x] 10.5 Interpretar CommandFailureException para pointers/toasts e Throwable inesperado para fallback, sem navegação em builders ou commands e sem reintroduzir contracts históricos de Supabase.
- [x] 10.6 Atualizar todos os testes que esperavam Left em execute.value, comprovando falhas em results/errors/Future e sucesso dos valores nativos, com subscriptions e configuração global restauradas.
- [x] 10.7 Validar Maestro sign-in falho/bem-sucedido, sign-up/reenvio e logout confirmado/cancelado/falho, preservando storage e sessão conforme as respostas reais do ambiente.

Registro do grupo 10: [Authentication, Settings, checks e validação pendente](implementation-part-9.md).
10.1–10.6 foram implementadas e verificadas por testes de commands e inspeção dos
consumidores. 10.7 foi encerrada por aceite explícito do usuário, sem execução
Maestro adicional. O simulador ficou inacessível na tentativa anterior; esse
aceite não amplia a cobertura demonstrada nem representa alteração de conta
ou sessão em dispositivo pelo agente.

## 11. Lifecycle dos demais consumidores e fluxos não Either

- [x] 11.1 Implementar religação de listener quando command muda em SignIn, SignUp, ResendEmail, EditUser e Settings, cancelando a assinatura da instância efetivamente observada.
- [x] 11.2 Corrigir observação substituível em AppScreen/AppWidget, preservando SessionCommand root, redirecionamento único, leitura inicial e validade de callbacks pós-frame.
- [x] 11.3 Fazer Callback invalidar ciclo quando command muda, mesmo com URL igual, mantendo `_isRunning`, revisão, tentativa iniciada, enum e distinção entre mesmo link/link novo.
- [x] 11.4 Verificar descarte e substituição com requests pendentes, inclusive Future completado com value anterior na 9.5.2; registrar que guards impedem aplicação/navegação tardia.
- [x] 11.5 Revisar cancelamento de cadeias/operators e propriedade de previews, removendo subscriptions antigas sem descartar singletons compartilhados ou repetir dispose de factory.
- [x] 11.6 Validar fluxos de entrada/confirmação/session e registrar explicitamente quais cenários de substituição foram executados versus inspecionados; usar harness temporário somente se autorizado e removê-lo ao fim.

Registro do grupo 11: [lifecycle, invalidação, testes e limites de validação](implementation-part-10.md).
11.1–11.5 foram implementadas/revisadas, com testes unitários para os limites dos
commands e inspeção técnica dos interleavings de State. 11.6 foi encerrada por
aceite explícito do usuário, sem execução Maestro adicional. Esse aceite não
amplia a cobertura demonstrada; não houve execução runtime dos fluxos ou
substituição artificial de dependências pelo agente.

## 12. Regressão unitária, documentação e encerramento da implementação

- [x] 12.1 Garantir testes de todos os commands migrados para input intacto, null inicial, valor de sucesso, falha tipada com metadata, Throwable inesperado e retry após falha.
- [x] 12.2 Garantir casos relevantes de bool false, lista/página vazia, total zero e limite nulo, sem usar isSuccess/hasData como prova universal de sucesso de negócio.
- [x] 12.3 Garantir concorrência com Completer e observáveis: requests duplicadas bloqueadas, runAsync compartilhado com parâmetros diferentes, isolamento de instâncias e descarte pendente sem publicação tardia de sucesso.
- [x] 12.4 Auditar usos restantes de Either/Left em apresentação: permitir adaptação nos commands e consumo pelo algoritmo do limite, eliminar interpretação de Left nos consumers migrados sem alterar Either no domínio/infrastructure.
- [x] 12.5 Atualizar ARCHITECTURE.md e AGENTS.md na mesma change com matriz de resultados/propriedade, política de erros, estados locais preservados e limites reais da biblioteca; revisar README se orientação de execução mudar.
- [x] 12.6 Executar `flutter pub get` quando aplicável, `flutter analyze` e `flutter test` nesta ordem; registrar falhas existentes ou novas com causa sem esconder resultados e sem criar testes Flutter de UI/módulos/rotas.
- [x] 12.7 Executar/registrar a matriz Maestro aprovada, manter evidência dos cenários efetivamente validados e remover recursos temporários autorizados, sem afirmar cobertura completa não demonstrada.
- [x] 12.8 Revisar diff por camada/escopo, confirmar ausência de nova dependência, geração, comentários Dart, domínio alterado, código de simulação residual e mudanças visuais incidentais.
- [x] 12.9 Validar a change OpenSpec e registrar redução concreta de fontes de verdade/listeners/setState, controles mantidos com justificativa e pendências reais; não fazer commit, sync ou archive sem solicitação explícita.

Registro do grupo 12: [regressão, matriz consolidada, checks e encerramento](implementation-part-11.md).
12.7 foi encerrada por aceite explícito do usuário após falha de acesso ao
simulador, sem nova execução Maestro ou cobertura runtime adicional.
