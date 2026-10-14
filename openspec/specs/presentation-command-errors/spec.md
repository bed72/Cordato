# presentation-command-errors Specification

## Purpose
TBD - created by archiving change align-command-it-presentation-errors. Update Purpose after archive.
## Requirements
### Requirement: Adaptação de Either somente na apresentação

Commands assíncronos cujo repository retorna `Either<ErrorsEntity, T>` SHALL aguardar esse resultado e publicar `T` para Right ou lançar `CommandFailureException` para Left. Os contratos de repository, DTOs, data sources, inputs e políticas HTTP SHALL permanecer existentes. A tradução SHALL ficar no callback específico de cada command e SHALL NOT introduzir helper genérico, base class ou camada adicional.

#### Scenario: Entidade publicada diretamente
- **WHEN** GetExpenseCommand recebe Right de uma ExpenseEntity
- **THEN** o Future de runAsync e results.data contêm a entidade original, sem Either
- **AND** results.hasError é false e os atributos não são normalizados

#### Scenario: Falha do repository adaptada
- **WHEN** GetExpensesCommand recebe Left de ErrorsEntity
- **THEN** a operação expõe CommandFailureException no canal nativo de erro
- **AND** o repository continua retornando Either e nenhuma resposta parcial é publicada como sucesso

### Requirement: Exceção tipada conserva integralmente a falha

`CommandFailureException` SHALL ser um tipo mínimo em `core/presentation/commands/`, implementar Exception e armazenar a mesma instância de ErrorsEntity recebida. SHALL preservar ordem, nulabilidade, lista vazia, title, detail, status, pointer e parameter. SHALL NOT realizar IO, logging, navegação, tradução visual ou validação de domínio.

#### Scenario: Metadados JSON API mantidos
- **WHEN** o Left contém múltiplos erros com pointer e parameter distintos
- **THEN** exception.errors é a mesma instância do Left
- **AND** todos os erros e seus campos mantêm ordem e conteúdo

#### Scenario: Lista de erros vazia
- **WHEN** o Left contém ErrorsEntity com lista vazia
- **THEN** a exceção conserva a lista vazia
- **AND** o consumidor pode aplicar fallback localizado sem acessar first indevidamente

### Requirement: Exceções inesperadas não são convertidas em falhas esperadas

Quando o repository lançar um throwable inesperado, o command SHALL preservar o erro e sua stack pelo mecanismo nativo de CommandIt. SHALL NOT substituir o erro por CommandFailureException, ErrorsEntity.unknown ou resultado nulo de sucesso. Uma ErrorsEntity.unknown retornada como Left SHALL continuar classificada como falha esperada do contrato.

#### Scenario: Repository lança StateError
- **WHEN** um repository mock lança uma instância de StateError
- **THEN** runAsync completa com erro da mesma instância e results registra essa exceção
- **AND** o consumidor visual usa fallback sem expor a mensagem técnica

#### Scenario: Repository retorna erro genérico por contrato
- **WHEN** o repository retorna Left de ErrorsEntity.unknown
- **THEN** o command lança CommandFailureException com esse objeto
- **AND** o fallback global não presume que existe uma exceção técnica original disponível

### Requirement: Contratos de sucesso e estado inicial explícitos

As saídas dos commands migrados SHALL usar as entidades, listas, páginas ou booleanos indicados no design, com initialValue nulo quando existente. SHALL preservar os records e argumentos atuais. Commands de listagem SHALL publicar somente a página corrente. Commands SHALL NOT inventar valor de domínio inicial para eliminar nulabilidade.

#### Scenario: Command recém criado
- **WHEN** um command migrado é instanciado antes de qualquer execução
- **THEN** value é null, results não contém erro e nenhuma consulta é feita
- **AND** o estado inicial não é contado como conclusão de uma operação da tela

#### Scenario: Inputs preservados
- **WHEN** o command recebe ID codificável, datas civis, parâmetros opcionais ou filtros incompletos
- **THEN** delega os mesmos valores ao repository
- **AND** esta adaptação não adiciona defaults, trim, timezone, validação ou normalização

### Requirement: Valores vazios e booleanos não são falhas artificiais

Right de lista/página vazia, total zero ou bool false SHALL permanecer resultado no canal de dados. A interpretação de confirmação SHALL permanecer contextual: exclusões somente se confirmam em true, sign-up somente navega em true, reenvio somente reinicia cooldown em true e efeitos de logout/session permanecem no repository/storage. SHALL NOT lançar falha artificial para Right(false).

#### Scenario: Exclusão não confirmada
- **WHEN** DeleteExpenseCommand ou DeleteUserCommand recebe Right(false)
- **THEN** publica false sem hasError
- **AND** o consumidor não remove dados nem anuncia exclusão bem-sucedida

#### Scenario: Consulta financeira vazia
- **WHEN** Insights retorna lista vazia, Expenses retorna página vazia ou Metrics retorna total zero
- **THEN** os commands publicam os respectivos valores como sucesso
- **AND** a Dashboard não ativa erro global por esses valores

#### Scenario: Reenvio não aceito
- **WHEN** ResendEmailCommand publica false
- **THEN** o fluxo preserva a ausência de confirmação de reenvio
- **AND** não reinicia cooldown nem anuncia sucesso apenas por ausência de exceção

### Requirement: Limite histórico nulo é sucesso concluído

GetFirstExpenseMonthCommand SHALL publicar DateTime civil ou null para histórico ausente, lançar a exceção tipada para falha de consulta ou continuação repetida e continuar sem acumular despesas. Sucesso nulo concluído SHALL NOT ser interpretado como erro ou como uma tentativa que não executou. O algoritmo SHALL percorrer página vazia com next, não presumir ordenação e parar novas páginas após descarte.

#### Scenario: Histórico ausente
- **WHEN** a execução percorre o histórico e não encontra despesas
- **THEN** runAsync conclui normalmente com null e results não contém erro
- **AND** a Dashboard aplica o comportamento de ausência de histórico previsto no ciclo

#### Scenario: Erro em página posterior
- **WHEN** uma página subsequente retorna Left
- **THEN** o command lança CommandFailureException sem publicar limite parcial
- **AND** o erro conserva seus metadados originais

#### Scenario: Continuação repetida
- **WHEN** um link next já visitado volta a ocorrer
- **THEN** a operação termina com falha tipada usando o erro genérico existente
- **AND** não entra em loop de requests

#### Scenario: Descarte após request de página
- **WHEN** o command é descartado enquanto aguarda uma página e detecta o descarte ao retornar
- **THEN** encerra seu algoritmo sem solicitar next nem lançar erro artificial de descarte
- **AND** nenhuma conclusão neutra é aplicada como recuperação válida por um consumidor obsoleto

### Requirement: Política nativa com fallback global real

A composição do app SHALL instalar Command.globalExceptionHandler antes de montar consumidores e SHALL manter o filtro nativo GlobalIfNoLocalErrorFilter de CommandIt 9.5.2. Falhas tipadas que chegam ao fallback SHALL NOT gerar toast, navegação, retry ou reporte técnico. Exceções inesperadas que chegam ao fallback SHALL ser reportadas pelo ICrashClient existente como não fatais, preservando erro e stack, sem adicionar paramData à telemetry. SHALL NOT ativar reporte indiscriminado de todas as falhas nem ErrorReaction.none em runAsync.

#### Scenario: Falha esperada sem listener local
- **WHEN** uma operação sem listener de results/errors lança CommandFailureException
- **THEN** o fallback global está disponível e não falha por ausência de handler
- **AND** o Future conclui com erro tipado, sem reporte de defeito ou feedback duplicado

#### Scenario: Exceção inesperada sem listener local
- **WHEN** CallbackCommand ou limite histórico lança exceção inesperada sem handler local
- **THEN** o erro alcança o fallback e o reporter não fatal existente
- **AND** runAsync não fica pendente por uma assertion de ausência de globalExceptionHandler

#### Scenario: Erro tratado localmente
- **WHEN** o filtro nativo encontra listener local efetivo
- **THEN** a falha é tratada no contexto do consumidor
- **AND** o sistema não promete reporte global adicional nem executa feedback global

### Requirement: Future e observáveis mantêm semânticas distintas

Consumidores que usam runAsync SHALL tratar a conclusão com erro além de observar o command. Um listener de efeito SHALL NOT ser reproduzido pelo catch da mesma operação. runAsync ocupado SHALL ser tratado como possível compartilhamento de execução, não como fila ou garantia de novos parâmetros. Guards contra dependências obsoletas SHALL continuar após await.

#### Scenario: Listener e await da mesma falha
- **WHEN** um handler mostra erro contextual e outro trecho aguarda a mesma operação
- **THEN** o catch impede propagação não tratada
- **AND** não mostra um segundo toast nem produz um segundo callback de falha visual

#### Scenario: Segunda chamada com parâmetros diferentes
- **WHEN** runAsync é chamado com B enquanto existe Future pendente de A
- **THEN** o consumidor não presume que B foi consultado
- **AND** a intenção de executar B é coordenada explicitamente quando necessária

### Requirement: Dados anteriores não mascaram erro corrente

Builders e listeners de resultado SHALL decidir pelo snapshot de results e priorizar erro antes de dados. SHALL NOT usar value anterior como sucesso da execução falha, nem isSuccess como prova de sucesso de negócio ou de execução iniciada. includeLastResultInCommandResults SHALL NOT ser habilitado apenas para ocultar a migração de contrato.

#### Scenario: Sucesso seguido de falha
- **WHEN** um command publica entidade A e sua próxima execução falha
- **THEN** o consumidor trata o erro corrente de results
- **AND** não navega, salva ou recupera a tela usando A conservada em value

#### Scenario: Publicação terminal síncrona
- **WHEN** um listener recebe resultado terminal antes da atualização de value
- **THEN** interpreta o dado e o parâmetro de results
- **AND** não depende da sincronização atômica com value ou isRunning

### Requirement: Commands não baseados em Either preservam sua semântica

CallbackCommand SHALL continuar publicando EmailVerificationStatusEnum e SessionCommand SHALL continuar usando command síncrono bool anulável, observação de storage e revisão da leitura inicial. Status invalid/failure de confirmação SHALL NOT ser convertido em CommandFailureException artificial. A UI SHALL NOT consultar isRunning do command síncrono de Session.

#### Scenario: Confirmação inválida
- **WHEN** o repository retorna status invalid ao CallbackCommand
- **THEN** o fluxo continua usando esse enum para feedback e navegação existentes
- **AND** não altera o contrato remoto para Either ou exceptions

#### Scenario: Evento de sessão ultrapassa leitura inicial
- **WHEN** chega um evento novo enquanto loadSession aguarda leitura antiga
- **THEN** a revisão existente impede sobrescrita pelo valor antigo
- **AND** nenhum mecanismo novo de loading síncrono é introduzido

