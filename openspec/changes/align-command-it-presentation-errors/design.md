## Context

### Baseline e evidências

O projeto Cordato/Trocado usa commands pequenos injetados por Flutter Modular, contracts de repository com Either e mixins de State para interação, navegação e coordenação. Esta change nasce da auditoria da apresentação e da decisão de avaliar a adaptação de Left para o mecanismo nativo de exceções, sem substituir a arquitetura.

As versões resolvidas na elaboração são CommandIt 9.5.2, listen_it 6.0.0, Flutter Modular 7.1.1 e auto_injector 2.2.0. A documentação web é apoio; o código instalado é a referência para assinaturas e comportamento. Antes da implementação, confirmar que o lockfile e o baseline continuam compatíveis.

Fontes revisadas:

- `pubspec.yaml`, `pubspec.lock`, `.dart_tool/package_config.json` e `ARCHITECTURE.md`.
- `lib/features/core/presentation/commands/interface_command.dart`.
- Commands, telas, mixins e previews de Dashboard, Expense, Insight, Metrics, User, Authentication e Root.
- `command_it-9.5.2/lib/command_it.dart`, `command_builder.dart`, `sync_command.dart`, `error_filters.dart` e `CHANGELOG.md` no cache resolvido.
- `listen_it-6.0.0/lib/listen_it.dart` e `src/custom_value_notifier.dart`.
- `flutter_modular-7.1.1/lib/src/module/module.dart` e `auto_injector-2.2.0/lib/src/auto_injector_base.dart`.
- [Getting started](https://flutter-it.dev/documentation/command_it/getting_started), [results](https://flutter-it.dev/documentation/command_it/command_results), [builders](https://flutter-it.dev/documentation/command_it/command_builders), [errors](https://flutter-it.dev/documentation/command_it/error_handling) e [chaining](https://flutter-it.dev/documentation/command_it/command_chaining).

### Diagnóstico que orienta a mudança

| Local | Classificação | Evidência | Decisão |
| --- | --- | --- | --- |
| Dashboard: results e errors das três consultas | Duplicação comprovada | Mesma reação e releitura das duas fontes de exceção | Usar results para detecção contextual |
| ExpenseScreen: loading, entidade e loadErrors | Duplicação comprovada | Cópias da operação já observada por CommandBuilder | Remover cópias e renderizar snapshot |
| Dashboard: setState vazio em cada sinal | Oportunidade de simplificação | Seções já têm builders próprios | Restringir reconstrução e separar coordenação |
| Builders de dados com onSuccess e leitura de value | Oportunidade de simplificação | Ignoram os dados do snapshot observado | Preferir onData/onNullData |
| FirstExpenseMonth e Callback sem handler local/global | Bug de caminho excepcional em debug identificado por inspeção | Filtro padrão pode lançar assertion antes de completar runAsync | Garantir fallback global real |
| User com builder removido durante ErrorScreen | Risco potencial | Handler local depende da presença do conteúdo | Fallback independente da montagem da seção |
| Consumidores sem religação em didUpdateWidget | Risco potencial | Listener antigo pode sobreviver à troca | Cancelar assinatura da instância observada |
| Filas, revisões, flags de ciclo e erro persistente | Oportunidade avaliada sem substituição nativa suficiente | run/runAsync não garantem nova operação e não conhecem navegação | Preservar responsabilidade local |

### Relação com planejamento existente

`unify-dashboard-error-screen` está ativa. Esta change não conclui suas tarefas nem altera seus arquivos. A recuperação financeira descrita por ela é uma invariante de regressão.

O código atual de `DashboardScreen` não fornece appBar à ErrorScreen, embora a documentação e a change anterior descrevam cabeçalho preservado. Registrar a divergência na baseline; esta refatoração não restaura nem remove cabeçalho incidentalmente. Qualquer correção visual exige decisão separada ou atualização explícita do escopo antes de implementar.

Specs de logout contêm nomes e integração histórica de Supabase. Não usá-las para reintroduzir `signOut`, `LogoutFailure`, clients ou estados antigos. O contrato vigente é `IAuthenticationRepository.logout()` com HTTP e `ErrorsEntity`.

## Goals / Non-Goals

**Goals:**

- Uma fonte de verdade por operação observável: dados e erro corrente pertencem ao command.
- Adaptar Left em um único ponto por operação, na apresentação, antes da publicação pelo CommandIt.
- Preservar identidade e metadados da falha, inputs, API HTTP, dados de domínio e DI.
- Diminuir listeners duplicados e setState usados somente para copiar resultados.
- Manter efeitos dependentes de State/BuildContext na apresentação da tela.
- Tornar explícitos os limites da biblioteca para fila, identidade, descarte e recuperação composta.
- Entregar migrações pequenas, porém completas por command e todos os seus consumidores.

**Non-Goals:**

- Trocar Either nos repositories, mudar status HTTP, validações remotas ou contratos financeiros.
- Introduzir controllers, stores, view models, Bloc, Riverpod, watch_it, get_it ou novos gerenciadores.
- Criar converter genérico de Either, base class de command, registry de listeners ou agregador de tela.
- Upgrade de pacotes, geração de código, comentários Dart novos ou migração estilística fora do escopo.
- Redesenhar tela de erro, feedbacks, navegação, cooldown, hold, datas, filtros ou ordenação.
- Transformar `Right(false)` em exceção ou ausência de histórico em falha.
- Cancelar HTTP, repetir automaticamente requests ou liberar navegação mensal durante loading.
- Eliminar todo mixin ou diminuir linhas sacrificando previsibilidade.

## Decisions

### 1. Either permanece no domínio e nos repositories

O fluxo alvo é:

```text
Screen/Widget -> Command -> IRepository -> Repository -> Data source
                  |
                  + Right<T> -> T no canal de dados
                  + Left<ErrorsEntity> -> CommandFailureException no canal de erro
```

Cada callback assíncrono do command aguarda o repository e faz um switch direto sobre Right/Left. Não há helper genérico, normalização adicional ou try/catch para encapsular indiscriminadamente qualquer throwable.

Uma exceção inesperada do repository permanece a mesma instância e conserva sua stack. Não é convertida em CommandFailureException nem em sucesso nulo. ErrorsEntity.unknown já retornado por um repository como Left é falha esperada do contrato, não prova de defeito técnico identificável nesta fronteira.

Alternativas consideradas: manter Either em toda a apresentação reduz mudanças, mas mantém a interpretação repetida; usar exceptions nos repositories amplia desnecessariamente o escopo; adaptar no widget mantém múltiplos consumidores conhecendo o wrapper. A adaptação no command concentra a tradução sem adicionar camada.

### 2. Exceção compartilhada mínima e somente de apresentação

Criar `lib/features/core/presentation/commands/command_failure_exception.dart`, com `final class`, primary constructor constante quando permitido, `implements Exception` e campo `final ErrorsEntity errors` obrigatório.

O campo conserva a mesma instância recebida pelo Left. Não copiar, ordenar, resumir, preencher ou mutar a lista. Preservar lista vazia e todos os campos de ErrorEntity: title, detail, status, pointer e parameter, inclusive nulos e strings desconhecidas.

O tipo não contém BuildContext, callback, rota, logging, Flutter Modular, acesso ao repository ou regra de negócio. Não requer registro de DI. Sua responsabilidade é identificar e transportar uma falha esperada entre o command e a UI. Não criar uma taxonomia de exceptions por endpoint.

`toString`, se necessário, usa identificação estável sem serializar dados sensíveis ou virar a mensagem exibida à pessoa. Feedback vem de `errors`, ou de fallback localizado já existente.

### 3. Contratos de saída dos commands

Todos os resultados continuam anuláveis quando null é usado como initialValue. Não inventar entidades vazias para permitir tipos não anuláveis.

| Command | Saída alvo de execute | Sucesso particular |
| --- | --- | --- |
| GetExpensesCommand | `ExpensePageEntity?` | Página vazia válida; não acumula páginas |
| GetExpenseCommand | `ExpenseEntity?` | Entidade consultada pelo ID |
| CreateExpenseCommand | `ExpenseEntity?` | Entidade criada |
| UpdateExpenseCommand | `ExpenseEntity?` | Entidade atualizada |
| DeleteExpenseCommand | `bool?` | false não confirma exclusão |
| GetInsightsCommand | `List<InsightEntity>?` | Lista vazia válida |
| GetExpenseMetricsCommand | `ExpenseMetricsEntity?` | Total zero válido |
| UserCommand | `UserEntity?` | Nome/avatar preservados |
| UpdateUserCommand | `UserEntity?` | Nome atualizado |
| UpdateAvatarCommand | `UserEntity?` | Consumidor confere seed devolvida |
| DeleteUserCommand | `bool?` | false não confirma exclusão nem navegação |
| SignInCommand | `SessionEntity?` | Sessão criada pelo repository |
| SignUpCommand | `bool?` | Navega somente em true |
| ResendEmailCommand | `bool?` | Cooldown reinicia somente em true |
| LogoutCommand | `bool?` | Efeitos de sessão continuam no repository/storage |
| GetFirstExpenseMonthCommand | `DateTime?` | null após execução concluída significa ausência de histórico |

No GetFirstExpenseMonthCommand, o algoritmo continua consumindo Either do repository, percorrendo páginas, detectando repetição e interrompendo novas páginas após dispose. Falhas remotas e ciclos de continuação são lançados como CommandFailureException com ErrorsEntity apropriado. A flag cooperativa de descarte permanece; não usar cancel de um command comum como substituto. Depois de detectar o próprio descarte, encerrar o algoritmo com retorno neutro sem lançar uma falha artificial de descarte: a publicação já está invalidada, e uma exceção tardia não deve reabrir o caminho de erro dos notifiers descartados. Essa conclusão neutra nunca conta como recuperação válida na tela.

CallbackCommand continua retornando `EmailVerificationStatusEnum?`. SessionCommand continua com command síncrono `bool?`, subscription de sessão e revisão da leitura inicial. Não fabricar Either ou exceptions para statuses válidos desses fluxos.

Não confundir o campo público `execute` do wrapper com o método deprecated `Command.execute()`: as chamadas atuais usam `.execute.run()`/`.runAsync()` e não precisam de renomeação.

### 4. Política nativa de erros e bootstrap

Manter `GlobalIfNoLocalErrorFilter`, a política nativa padrão da versão instalada. Não acrescentar `LocalErrorFilter` a operações que possam ficar sem listener local; não usar `ErrorReaction.none` com runAsync; não usar throwException para falhas esperadas.

Configurar `Command.globalExceptionHandler` no bootstrap depois da resolução de `ICrashClient` e antes de montar AppWidget e seus consumidores. A atribuição é estável e não cria uma subscription por rebuild:

- CommandFailureException: fallback sem toast, navegação, retry ou reporte de defeito.
- Throwable inesperado que chega ao fallback global: delegação ao `ICrashClient.recordError` existente, com erro original, stack fornecida e `fatal: false`.
- Nenhum encaminhamento de paramData, credenciais, IDs ou nomes de commands para payload novo de telemetry.
- Não habilitar reportAllExceptions, localAndGlobal para todos ou alterar assertionsAlwaysThrow. O comportamento existente de AssertionError permanece deliberadamente fora da adaptação de Left.

O padrão local-first significa que uma exceção tratada localmente não é obrigatoriamente reportada globalmente. Esta change não promete telemetry de toda exceção nem muda a política global do Flutter/PlatformDispatcher. Caso se deseje reporte de todas as exceções inesperadas, isso exige política adicional aprovada, sem duplicação de handlers.

O fallback global garante que uma operação sem handler local, inclusive limite histórico ou Callback, tenha destino de erro e possa completar o Future conforme o filtro. O feedback visual continua no consumidor contextual. `try/catch` de runAsync continua obrigatório; o catch não exibe novamente um toast que já foi emitido pelo listener da mesma operação.

### 5. Snapshot observado determina a UI e os efeitos terminais

Builders que consomem dados usam onData e recebem o valor do snapshot. onNullData representa entrada sem dados; whileRunning representa execução; onError representa falha tipada ou inesperada. Não fornecer onSuccess junto de onData esperando ambos: onSuccess tem precedência.

Buttons cujo layout depende somente de execução podem manter onSuccess/onError. Não fazer alterações mecânicas sem redução de responsabilidade.

Handlers de efeitos observam results quando precisam distinguir dados, erros e parâmetros. Avaliam `isRunning` e erro antes dos dados; não consultam `command.value` para decidir sucesso depois de falha, pois value pode conservar resultado anterior. Listeners síncronos usam o snapshot recebido/lido de results, respeitando a publicação terminal anterior à atualização de value.

Navegação, toasts, callback de alteração, reset de hold e mapeamento de erros de campos não pertencem ao build. Permanecem em handlers específicos ligados ao State. Uma operação terminal produz no máximo um feedback contextual por handler pertinente.

### 6. Dashboard: observação mínima, coordenação preservada

Primeiro simplificar o mixin ainda com os contratos existentes: remover os três listeners de errors e a releitura redundante em `_failed`, sem mexer nas filas. Depois adaptar os resultados dos commands e consumidores relacionados de forma atômica.

Após a migração, falha financeira é snapshot terminal com hasError; Left não é interpretado pela Dashboard. A observação dos três results permanece durante conteúdo, erro global e recuperação, para detectar falha imediata e não depender de builders de seções montadas.

Separar callbacks por responsabilidade: resultados ativam o latch; execução permite drenar pendências; builders observam loading dos controles. `setState` fica para mês, transição do latch e estado do ciclo. Não chamar setState vazio global a cada dado quando a própria seção já observa o command.

Preferir builders Flutter sobre listenables existentes. `Listenable.merge` pode compor assinaturas para controles sem criar uma store; o conjunto de fontes deve ser estável por versão de dependências. Avaliar select/combineLatest do listen_it somente se simplificar de fato e houver cancelamento/descarte explícito das cadeias. Não criar chains no build que acumulem subscriptions.

Manter as seguintes responsabilidades:

| Estado/controle | Motivo para permanecer |
| --- | --- |
| selectedMonth e monthEnd | Lente civil da pessoa e composição das três consultas |
| hasFinancialError | Latch, não mera derivação do resultado atual |
| isRecovering | Tentativa iniciada no erro, distinta de refresh normal que venha a falhar |
| _isRefreshingDashboard | Ciclo sequencial/paralelo, inclusive lacunas entre commands |
| _dependenciesVersion | Validade de continuations e retornos de navegação |
| _refreshPendingAfterNavigation | Uma intenção coalescida posterior às alterações confirmadas |
| _userRefreshPending | Leitura nova depois de eventual edição, não adesão à leitura antiga |
| _isOpeningExpenses | Exclusão mútua de navegação para a listagem |
| mounted e comparação de instâncias | Impedem aplicação em tela ou dependência inválida |

Nenhuma flag de ciclo é removida somente por existir isRunning. É permitido manter os nomes atuais. Não criar enum ou notifier adicional apenas para agrupar essas flags.

### 7. Dashboard: algoritmos e aceitação da tentativa

Na abertura, User, limite e três seções iniciam como atualmente. Mudança de mês reutiliza limite e dispara três seções, bloqueando setas enquanto carrega. Não mostrar dados do mês anterior sob novo título; manter includeLastResultInCommandResults desabilitado nas consultas mensais.

No refresh/retry, capturar versão e motivo do ciclo, bloquear reentrada antes do primeiro await e manter um único mês vigente. User recarrega em paralelo ao limite quando a recuperação requer. O limite, inclusive sucesso nulo, resolve antes das três consultas. Ausência de histórico aplica a regra civil vigente; falha de limite mantém a seleção e bloqueia navegação anterior, sem impedir consultas financeiras.

As três seções usam Future.wait. Cada resultado conta como sucesso somente se a execução solicitada terminou sem erro e pertence ao command/versão/ciclo vigentes. Não usar value, isSuccess inicial, resultado anterior, Future retornado por descarte ou adesão a outra execução como prova de sucesso. Falha ou execução não iniciada não libera o latch.

O latch ativa no primeiro erro financeiro sem esperar as outras seções. Sucessos remanescentes não o liberam. A recuperação libera o conteúdo somente após três sucessos correntes; falha auxiliar de User/limite não prolonga o erro financeiro. Ao terminar ciclo falho, loading encerra e uma nova tentativa é permitida, sem fila de toques bloqueados.

Retorno financeiro com alteração durante execução marca uma única intenção pendente. Ao ficar ocioso, agendar/drenar com versão válida, removendo a intenção antes de iniciar. Retornos adicionais enquanto ocupado coalescem; retorno durante um refresh que possa anteceder a alteração precisa de outro ciclo. Não consumir a intenção aderindo ao Future antigo. Sem alteração confirmada não há recarga financeira.

Retorno de User/Settings aguarda uma leitura ocupada e inicia uma nova leitura, se a dependência ainda for a mesma. A biblioteca não fornece esta semântica automaticamente. Preservar microtask quando necessária para evitar execução reentrante durante publicação terminal.

### 8. ExpenseScreen: dados nativos e consulta identificada

Remover os campos locais `expense`, `loadErrors` e `isLoading` da consulta. A screen renderiza ExpenseEntity por onData, falha por onError e skeleton por whileRunning/onNullData. O formato do erro esperado usa ErrorsEntity; inesperado usa fallback atual, sem string técnica.

Comparar paramData com widget.id em todos os caminhos relevantes. Resultado de A quando a tela pede B não preenche formulário nem mostra erro de A. O skeleton pode ser apresentado para snapshot incompatível até a consulta vigente começar; não armazenar outra cópia da entidade para resolver incompatibilidade.

O mixin mantém um algoritmo pequeno: carregar ID atual quando o command estiver disponível, aguardar execução anterior quando ID mudou, revalidar mounted/identidade e iniciar somente o ID final vigente. Não iniciar várias consultas intermediárias A/B/C que já não representam a tela. O caminho creation, sem ID, não faz consulta. Dispose e substituição de commands factory continuam na screen, enquanto ExpenseFormWidget remove apenas suas assinaturas.

### 9. Formulário e listagem preservam estado que não pertence à operação

No formulário, converter listeners de Right/Left para entidade/CommandFailureException. Manter controllers, valores, data, erros locais, `_isPickerOpen`, `_keepFormOpenAfterCreation`, validação, partial update, toasts e callbacks. Erros remotos por pointer alimentam campos; edição da entrada pode apagar mensagens sem alterar o command. Hold concluído limpa somente depois de sucesso; hold interrompido não envia; erro preserva entrada.

Na listagem, a página nativa é incorporada uma única vez por execução válida. O command não acumula itens. Manter lista, next, filtros, revisão, operação de retry, edição, confirmação e remoção após dismiss. Falha de refresh/paginação preserva itens; troca de lente limpa a lista imediatamente e invalida operação antiga.

Substituir a flag local de loading apenas quando o estado do command e o controle pendente cubram todos os intervalos necessários. A aceitação é comportamental, não a remoção obrigatória de um campo. Se for comprovado um intervalo local legítimo, mantê-lo com justificativa no registro final, sem criar cópia do estado de request.

`hasFailure` pode permanecer como feedback aceito para a revisão vigente. Derivá-lo de um snapshot antigo não é permitido. `hasLoaded` distingue histórico de carregamento da lente. pendingDeleteId não é equivalente a isRunning da exclusão: existe antes da requisição e pode persistir até o gesto terminar. deletingExpenseId pode ser derivado de paramData+execução somente se preservar o comportamento visual atual; não é obrigatório nesta change.

### 10. Lifecycle explícito sem troca de escopos

ICommand continua implementando Disposable. AutoInjector retém instâncias singleton/lazy singleton, não cada factory resolvida. Portanto:

| Registro | Proprietário |
| --- | --- |
| Factory: consultas/mutações Expense, UserCommand, UpdateAvatar, Insights, Metrics e FirstExpenseMonth | Tela consumidora; remove listeners e descarta instância |
| Lazy singleton em `/user`: DeleteUser e UpdateUser | Modular quando última rota do escopo sai; tela remove listeners |
| Lazy singleton em `/settings`: Logout | Modular; tela remove listeners |
| Lazy singleton root: SignIn, SignUp, Callback, ResendEmail, Session | Escopo compartilhado; telas não descartam ao sair |
| Commands criados por preview | Wrapper ou tela, conforme propriedade já existente; nunca ambos |

Para commands substituíveis, guardar a assinatura da instância observada. `ListenableSubscription.cancel()` permite remover a assinatura mesmo após widget.command apontar para outro objeto. Cancelar antes de religar/descartar; nunca remover do command novo supondo que isso limpa o antigo.

Consumidores pequenos podem manter addListener/removeListener quando a propriedade for inequívoca e didUpdateWidget remover da instância antiga. Não exigir uma conversão mecânica universal para listen. Se usar operators, cancelar a cadeia e liberar notifiers derivados próprios.

Em Callback, mudança de command invalida o ciclo mesmo com URL igual. Preservar `_isRunning` local, revisão, espera do mesmo link e execução do link final. Em Root, preservar subscription compartilhada e redirecionamento único; listeners ou callbacks pós-frame obsoletos não navegam após troca/descarte.

### 11. Testes e validação sem novas camadas

Atualizar testes de cada command migrado: entidade/valor de sucesso, erros esperados em results/errors e Future, metadata, input intacto, null inicial, false/zero/vazio, duplicação bloqueada e instâncias isoladas. Usar repository mocks existentes, Completer e observáveis. Testar a exceção compartilhada como contrato puro de transporte.

O teste de expected failure instala handler local ou global real conforme cenário e verifica tanto erro do Future quanto snapshot. Cenários globais restauram configuração estática em tearDown, sem estado compartilhado entre suítes. Não confundir addListener vazio de suporte ao roteamento com comprovação de feedback da tela.

Verificar descarte pendente: na 9.5.2 o Future pode completar com value anterior; não atualizar tela ou interpretar como sucesso da tentativa. Remover subscriptions e descartar cada command manual exatamente uma vez; aguardar o lifecycle assíncrono da biblioteca quando necessário.

Não criar testes Flutter automatizados de widgets, screens, temas, mixins de UI, módulos ou rotas. Fluxos reais são validados com Maestro. Testes unitários de commands não são apresentados como garantia de todo interleaving de State. Os cenários de troca de dependências não expostos pelo app precisam de verificação técnica explícita/inspeção e evidência registrada; se houver harness temporário autorizado, removê-lo ao terminar e não deixar menus ou hooks de simulação na aplicação.

### 12. Matriz de verificação e critérios de conclusão

| ID | Cenário | Meio principal | Evidência mínima |
| --- | --- | --- | --- |
| C01 | Right de entidade/lista/página | Unitário do command | Mesma instância/valor no Future e results.data |
| C02 | Left com vários erros | Unitário do command/exceção | Mesmo ErrorsEntity no erro, pointer/parameter/ordem preservados |
| C03 | Lista de erros vazia | Unitário + inspeção de handler | Transporte vazio e fallback seguro, sem acesso indevido a first |
| C04 | Throwable inesperado | Unitário do command | Mesma instância no Future/results; não encapsulada como falha esperada |
| C05 | Sem handler local | Unitário com callback global real | Future termina; falha esperada não é reportada; inesperada chega ao fallback |
| C06 | Right(false), vazio e zero | Unitários e fluxo pertinente | Resultado válido; confirmação/vazio preservados na UI |
| C07 | Limite nulo e páginas não ordenadas | Unitário FirstExpenseMonth | Menor mês correto ou null concluído sem falha |
| C08 | runAsync A/B e duplicação | Unitário com Completer | Sem GET extra; adesão não conta como execução de B |
| C09 | Dispose durante execução | Unitário com Completer | Sem publicação tardia de sucesso, nova página ou assinatura sobrevivente |
| C10 | Sucesso anterior seguido de falha | Unitário + fluxo pertinente | Snapshot com erro; value antigo não produz efeito de sucesso |
| D01 | Abertura e mudança mensal | Maestro | Mesma lente das três seções, tamanho seis, setas bloqueadas |
| D02 | Uma falha antes das outras conclusões | Maestro controlado | Erro imediato e persistente, sem aguardar ou flash de conteúdo |
| D03 | Retry falha e depois recupera | Maestro controlado | Uma tentativa por toque válido, loading estável, três sucessos correntes |
| D04 | User/limite falhos e financeiro válido | Maestro controlado | Fallback e bloqueio anterior, sem prolongar latch financeiro |
| D05 | Limite nulo/ajustado durante recovery | Maestro controlado | Seleção civil correta e parâmetros das consultas subsequentes |
| D06 | Cadastro/listagem retorna com/sem alteração | Maestro | Mês preservado, recarga somente após sinal confirmado |
| D07 | Retorno enquanto leitura anterior carrega | Maestro controlado ou verificação técnica | Uma intenção coalescida gera leitura nova após idle |
| D08 | Dependência muda/descarte durante retry | Verificação técnica, runtime se autorizado | Revisão antiga não altera flags/mês/latch nem finaliza ciclo novo |
| E01 | Consulta de edição e retry | Maestro | Skeleton acessível, entidade correta e mensagem contextual |
| E02 | IDs A/B/C e retirada de ID | Verificação técnica, runtime se autorizado | Resultado incompatível ignorado; somente ID final consultado |
| E03 | Toque simples e hold | Maestro | Navegação ou reset corretos; falha/interrupção preservam entrada |
| E04 | PATCH parcial e erros de pointer | Unitário + Maestro | Inputs omitidos preservados e erros em campos corretos |
| E05 | Listagem: lente, refresh, página e retry | Maestro | Itens/continuação preservados ou limpos conforme operação/lente |
| E06 | Edição/exclusão da listagem | Maestro | Confirmação, gesto, reposicionamento, filtros e rolagem preservados |
| U01 | Nome e avatar | Maestro | Um efeito de sucesso, seed conferida e autosave coalescido |
| A01 | SignIn/SignUp/Resend/Logout | Maestro + unitários | Sessão/booleanos/cooldown/erros e confirmação inalterados |
| A02 | Callback: mesmo link e link novo | Unitário existente + verificação técnica | Sem GET duplicado do mesmo link e sem efeito do link obsoleto |
| L01 | Troca de command e listener | Verificação técnica, runtime se autorizado | Assinatura antiga cancelada, nova única e nenhum efeito tardio |
| L02 | Screen/preview/module ownership | Inspeção + execução de previews | Nenhum double dispose ou descarte prematuro |

Critérios mensuráveis: os três listeners financeiros duplicados de errors deixam de existir; ExpenseScreen deixa de copiar os três campos de consulta; consumers migrados não interpretam Left; nenhuma nova abstração de estado ou dependência é adicionada; a propriedade dos recursos e os cenários acima têm evidência ou pendência explicitamente registrada. Redução absoluta de linhas ou remoção de toda flag não é critério de aceitação. Uma tarefa de execução pendente não é marcada como concluída apenas porque foi inspecionada estaticamente.

## Risks / Trade-offs

- [Mais statements no callback de cada command] → Aceitar o switch curto como adaptação explícita e evitar converter genérico; o ganho está nos consumidores e na semântica.
- [Migração parcial quebra consumers e previews] → Alterar cada contrato com todos os imports, callbacks, testes e consumidores na mesma unidade integrável.
- [Falhas esperadas chegam a crash reporter] → Identificar CommandFailureException no fallback global e não reportá-la como defeito; não ativar reporte global indiscriminado.
- [value anterior parece sucesso após exceção] → UI e listeners usam results e priorizam erro; teste Right anterior seguido de falha.
- [Sucesso nulo do limite parece ausência de execução] → O ciclo que aguarda runAsync diferencia conclusão de erro; não usar hasData como prova de sucesso desse command.
- [Resultados antigos contam para retry] → Capturar versão/instância e provar execução da tentativa vigente; manter guards após await.
- [Fila perdida ao aderir a runAsync ocupado] → Manter intenção pendente e iniciar uma execução nova quando o conjunto ficar ocioso.
- [Ordem de results, isRunning e value] → Preservar liberação síncrona e scheduling necessário; não eliminar listeners de coordenação antes de verificar ordem.
- [Cadeias listen_it acumuladas no build] → Preferir composição simples; instalar uma cadeia por conjunto de dependências e liberar recursos próprios.
- [Dispose duplicado] → Respeitar a matriz de propriedade, inclusive previews; CommandIt rejeita descarte duplicado em debug.
- [Regressão invisível no cabeçalho de erro] → Congelar baseline visual atual e registrar divergência com a change anterior; não corrigir silenciosamente.
- [Cobertura UI insuficiente] → Registrar quais cenários Maestro realmente rodaram e quais verificações de lifecycle são estáticas/pendentes.

## Migration Plan

1. Reconfirmar baseline, versões, limites de propriedade e coordenação da Dashboard. Registrar falhas prévias e divergência de cabeçalho.
2. Fazer a simplificação mínima da Dashboard com Either ainda vigente, removendo somente observação duplicada e separando reconstrução/coordenação. Validar antes de mudar saída dos commands.
3. Introduzir CommandFailureException, testes puros e fallback global nativo. Atualizar documentação de fronteira. Nenhum command precisa migrar sem seu consumidor.
4. Migrar consultas compartilhadas GetExpenses/GetInsights/GetExpenseMetrics/User e limite histórico com Dashboard, ExpensesScreen, UserScreen, seções, previews e testes envolvidos na mesma unidade. Preservar algoritmo de limite e ciclo corrente.
5. Migrar GetExpense e simplificar ExpenseScreen. Validar loading, erro, retry e ID final vigente antes de mexer em mutações.
6. Migrar comandos de criação/edição/exclusão Expense com formulário/listagem; depois User e Authentication com todos os consumidores. Não converter enum de Callback nem sync de Session.
7. Finalizar lifecycle dos consumidores substituíveis e loading de listagem apenas onde comprovadamente derivável. Documentar controles preservados e justificativas.
8. Executar análise, testes e Maestro; atualizar ARCHITECTURE.md e AGENTS.md com os contratos novos e resultados reais. README somente quando orientação de desenvolvimento mudar.

Cada etapa deixa o projeto analisável e suas unidades relevantes testáveis. Se o tamanho de uma etapa exigir subdivisão, o limite de corte é um command mais todos os consumidores, não uma feature arbitrária. Shared getters e tipos não podem ficar parcialmente migrados.

Rollback é por unidade completa, preservando alterações do usuário: restaurar contrato de saída, consumidores, testes e documentação do command correspondente juntos. Não usar reset/revert destrutivo nem tocar HTTP/storage/dados. O tipo de exceção e fallback global podem coexistir temporariamente com commands não migrados.

## Open Questions

Não há decisão arquitetural obrigatória em aberto para escrever a proposta. A implementação depende da aprovação desta mudança e deve confirmar:

- O baseline de Dashboard e a continuidade da change ativa antes de tocar seu mixin; divergência visual de cabeçalho permanece fora do escopo.
- Dispositivo disponível e API/ambiente controlado para reproduzir falhas e atrasos sem alterar dados reais indevidamente.
- Se cenários artificiais de substituição de dependências exigirem harness temporário, autorização e mecanismo de descarte; ausência desse recurso não autoriza afirmar validação runtime.
- Se os escopos efetivos mudaram desde a auditoria, atualizar a matriz antes de remover qualquer dispose ou assinatura.
