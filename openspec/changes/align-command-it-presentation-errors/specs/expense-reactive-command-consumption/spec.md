## ADDED Requirements

### Requirement: Consulta simples usa estado do command sem cópias

ExpenseScreen SHALL renderizar loading, ExpenseEntity e falha da consulta diretamente pelo CommandBuilder de GetExpenseCommand. ExpenseScreenStateMixin SHALL NOT armazenar cópias de entidade, erro remoto ou loading da request. O mixin SHALL conservar somente propriedade de recursos e coordenação necessária da consulta por ID. Criação sem ID SHALL continuar sem GET.

#### Scenario: Edição carregada com sucesso
- **WHEN** a consulta do ID vigente publica ExpenseEntity
- **THEN** onData compõe o formulário com essa entidade
- **AND** nenhum setState copia a entidade para outro campo do State

#### Scenario: Falha remota de consulta
- **WHEN** a consulta vigente lança CommandFailureException
- **THEN** onError apresenta o erro localizado usando ErrorsEntity preservada e retry existente
- **AND** não depende de loadErrors preenchido por await

#### Scenario: Tela de criação
- **WHEN** ExpenseScreen recebe id nulo
- **THEN** compõe o formulário de criação e não executa GetExpenseCommand

### Requirement: Snapshot incompatível não preenche a edição atual

O consumidor SHALL verificar paramData contra o ID vigente antes de exibir entidade ou erro. Se o ID mudar durante request ocupada, SHALL iniciar uma consulta nova para o ID final vigente após a anterior terminar, validando mounted e command. SHALL NOT interpretar adesão a runAsync ocupado como consulta do novo ID nem enfileirar todos os IDs intermediários.

#### Scenario: ID muda de A para B
- **WHEN** B passa a ser solicitado enquanto A está carregando
- **THEN** resultado ou erro de A não preenche nem informa falha de B
- **AND** B é consultado quando a execução anterior termina e a tela permanece válida

#### Scenario: A para B para C durante execução
- **WHEN** múltiplas mudanças de ID ocorrem antes da conclusão de A
- **THEN** somente o ID final C é solicitado pela recarga pendente
- **AND** nenhuma resposta de A ou B substitui o formulário de C

#### Scenario: ID removido enquanto consulta carrega
- **WHEN** o widget passa a criação sem ID durante consulta antiga
- **THEN** sua conclusão não transforma criação em edição nem inicia GET desnecessário

### Requirement: Loading e retry de edição preservam apresentação

A consulta de edição SHALL manter skeleton acessível, anúncio “Carregando despesa”, formulário desabilitado durante carregamento e ação “Tentar novamente” após falha. Estado inicial e snapshot incompatível SHALL manter representação coerente de carregamento, sem flash de dados de outra despesa. Retry SHALL solicitar o ID vigente e ser bloqueado contra request duplicada.

#### Scenario: Retry de consulta falha
- **WHEN** a pessoa aciona retry da edição e a consulta está ociosa
- **THEN** o ID vigente é consultado novamente e o skeleton permanece durante execução
- **AND** falha posterior mantém o retry e os textos existentes

#### Scenario: Toques repetidos no retry
- **WHEN** a consulta de edição já está em execução
- **THEN** novos toques não iniciam nem enfileiram request duplicada

### Requirement: Mutações do formulário usam canal nativo de falha

ExpenseFormWidgetStateMixin SHALL receber entidades nativas nos resultados de Create/Update e CommandFailureException para erros remotos. SHALL mapear amount, description e occurred_on pelos pointers existentes, usando fallback/toast para erros restantes ou inesperados. Valores digitados, validação local e mensagens apagadas por edição SHALL permanecer estado do formulário, não do command.

#### Scenario: Vários erros de campo
- **WHEN** uma criação falha com pointers de amount, description e occurred_on
- **THEN** as mensagens preservadas aparecem nos campos correspondentes
- **AND** nenhuma parte da entrada é limpa e os erros restantes usam feedback contextual existente

#### Scenario: Entrada corrigida após falha
- **WHEN** a pessoa modifica um campo com erro
- **THEN** a mensagem desse campo pode ser removida localmente conforme o comportamento existente
- **AND** não é necessário apagar todo o canal de erro do command

### Requirement: Criação por toque ou hold preserva efeitos

Sucesso da criação SHALL produzir um toast e sinalizar alteração financeira uma vez. Toque simples SHALL executar a navegação injetada; hold concluído SHALL limpar descrição, centavos e erros, redefinir hoje e permanecer na tela. Falha SHALL preservar dados nos dois modos. Hold interrompido SHALL NOT enviar. Pickers cancelados SHALL preservar entrada e exclusão mútua visual existente.

#### Scenario: Hold com sucesso
- **WHEN** o hold conclui e CreateExpenseCommand publica entidade criada
- **THEN** a tela permanece aberta e reinicia o formulário conforme a regra existente
- **AND** um único toast e um único callback de alteração são emitidos

#### Scenario: Hold com falha
- **WHEN** o hold envia e o command termina com falha esperada ou inesperada
- **THEN** a entrada e a data são preservadas
- **AND** não há callback de sucesso ou navegação

#### Scenario: Toque simples com retorno à Dashboard
- **WHEN** a criação por toque termina com sucesso no contexto returnToPrevious
- **THEN** usa o callback injetado para retornar à mesma instância da Dashboard
- **AND** não transforma o command em proprietário da navegação

### Requirement: Atualização parcial preserva comparação e retorno

Edição SHALL continuar enviando somente atributos alterados, comparando data por ano/mês/dia e mantendo int em centavos. O botão SHALL continuar habilitado somente com alterações válidas e sem hold. Sucesso SHALL devolver a entidade atualizada e sinalizar alteração uma vez. Falha SHALL manter formulário e feedbacks existentes.

#### Scenario: Somente data civil muda
- **WHEN** a pessoa altera apenas a data de uma despesa
- **THEN** UpdateExpenseCommand recebe ID e occurredOn alterado com demais atributos omitidos
- **AND** o retorno de sucesso preserva a entidade publicada pelo repository

#### Scenario: Falha com value antigo
- **WHEN** uma atualização falha após sucesso anterior no mesmo command
- **THEN** a falha corrente é tratada pelo snapshot
- **AND** o valor antigo não é devolvido à listagem como atualização confirmada

### Requirement: Página nativa é incorporada somente na lente vigente

ExpensesScreen SHALL consumir ExpensePageEntity diretamente e SHALL manter acúmulo/ordenação no mixin existente. Cada execução válida SHALL incorporar uma página uma vez. Requests, resultados e callbacks antigos SHALL ser invalidados por command e revisão. Próximos links SHALL continuar opacos, com pageSize 20 e filtros ativos preservados.

#### Scenario: Segunda página válida
- **WHEN** o command publica a próxima página da lente atual
- **THEN** seus itens são incorporados uma vez e next é substituído pela continuação recebida
- **AND** a ordem civil, estabilidade entre dias iguais e agrupamentos permanecem existentes

#### Scenario: Página antiga chega após troca de lente
- **WHEN** a lente mudou antes de uma consulta anterior terminar
- **THEN** os itens e a continuação antigos não são incorporados
- **AND** erro/finalização antigos não modificam loading ou feedback da nova lente

### Requirement: Loading de listagem não duplica a execução sem motivo

Loading visual e bloqueios da listagem SHALL usar a execução do command quando ela representar integralmente a request. Uma flag local SHALL existir somente para um intervalo de coordenação comprovadamente distinto e documentado. Acúmulo, hasLoaded, feedback aceito, operação de retry e intenção pendente SHALL NOT ser removidos como se fossem todos resultados do command.

#### Scenario: Paginação com itens existentes
- **WHEN** uma página seguinte carrega
- **THEN** os itens anteriores permanecem e o rodapé mostra três placeholders
- **AND** interações incompatíveis permanecem bloqueadas sem uma cópia desnecessária de isRunning

#### Scenario: Primeira página sem itens
- **WHEN** a lente atual ainda não tem itens e está carregando
- **THEN** mostra oito placeholders e o anúncio existente
- **AND** não apresenta vazio antes de carregamento válido

### Requirement: Falha repete a operação correta e preserva dados

Falha de refresh ou paginação da mesma lente SHALL preservar itens, controller e continuação apropriada, oferecendo retry da operação que falhou. Troca/remoção de filtro SHALL limpar itens e feedback anteriores, manter filtros novos em falha e repetir primeira página. A recarga pendente SHALL solicitar a combinação final vigente após request anterior, sem consumir a intenção por adesão ao Future antigo.

#### Scenario: Falha na paginação
- **WHEN** a segunda página falha
- **THEN** itens existentes permanecem e retry pede a continuação da operação falha
- **AND** não volta à primeira página por causa da migração para exceptions

#### Scenario: Filtro removido com falha na consulta nova
- **WHEN** a pessoa remove a categoria e a nova consulta falha
- **THEN** a categoria permanece removida, a lista permanece vazia e retry pede primeira página da lente atual
- **AND** não reaplica parâmetros iniciais nem sinaliza alteração financeira

### Requirement: Exclusão e edição preservam gesto e confirmação

Exclusão SHALL continuar exigindo confirmação, removendo item e sinalizando alteração somente em true, com feedback único. pendingDeleteId SHALL preservar sua função antes da request e até a finalização de gesto pertinente. Edição SHALL continuar usando navegação injetada, preservando rolagem/continuação e removendo ou reposicionando a despesa conforme os filtros ativos. Alterar o canal de falha SHALL NOT alterar thresholds, gesto, acessibilidade ou experiência visual.

#### Scenario: Exclusão não confirmada remotamente
- **WHEN** DeleteExpenseCommand publica false
- **THEN** o item permanece e recebe o fallback de falha existente
- **AND** não emite alteração financeira nem toast de exclusão confirmada

#### Scenario: Último item de um grupo removido
- **WHEN** uma exclusão true termina e o item é retirado
- **THEN** o cabeçalho vazio desaparece, a rolagem/continuação é preservada e a necessidade de mais itens é verificada

#### Scenario: Edição deixa os filtros ativos
- **WHEN** a entidade atualizada passa a ter data ou categoria fora da lente atual
- **THEN** a listagem remove o item sem alterar filtros ou mês da Dashboard

### Requirement: Propriedade de commands e controllers de Expense é preservada

ExpenseScreen e ExpensesScreen SHALL descartar seus commands factory exatamente uma vez e remover seus recursos próprios. ExpenseFormWidget SHALL remover assinaturas e controllers que criou, sem descartar commands pertencentes à screen. Substituição e descarte SHALL invalidar efeitos, callbacks de alteração e continuations antigos.

#### Scenario: Formulário desmontado por skeleton
- **WHEN** um formulário filho é substituído durante consulta da screen
- **THEN** remove seus listeners/controllers sem descartar commands ainda pertencentes à screen

#### Scenario: Screen descartada durante save
- **WHEN** a operação termina depois do descarte da screen
- **THEN** nenhum toast, navegação, setState ou callback financeiro é produzido pelo State descartado
