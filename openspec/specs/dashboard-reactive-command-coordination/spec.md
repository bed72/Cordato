# dashboard-reactive-command-coordination Specification

> Coordenação por commands/Either é histórica; Dashboard usa Bloc sobre contratos
> de aplicação. O mês é preservado e todo retorno da listagem provoca recarga,
> mesmo sem mutação. Consulte [a referência vigente](../../README.md).

## Purpose
TBD - created by archiving change align-command-it-presentation-errors. Update Purpose after archive.
## Requirements
### Requirement: Dashboard usa uma fonte de erro financeiro por operação

DashboardScreenStateMixin SHALL observar results dos três commands financeiros e SHALL NOT observar errors adicionalmente para a mesma detecção de falha. Após migração dos commands, falha financeira SHALL ser resultado terminal com hasError. A observação SHALL permanecer ativa quando as seções estiverem ocultas na ErrorScreen. Falhas auxiliares de User/limite SHALL NOT ativar o latch financeiro.

#### Scenario: Falha de uma seção
- **WHEN** Metrics, Insights ou recentes terminam com falha tipada ou exceção inesperada
- **THEN** o latch de erro é ativado imediatamente por seu snapshot
- **AND** não há segunda reação causada por listener redundante de errors

#### Scenario: Seções desmontadas durante erro
- **WHEN** a tela está em erro global e uma consulta financeira termina
- **THEN** o mixin continua observando a conclusão
- **AND** a detecção não depende do CommandBuilder de uma seção montada

### Requirement: Estado local da Dashboard representa o fluxo da tela

A Dashboard SHALL manter mês selecionado, erro persistente, motivo de recuperação, exclusão mútua do ciclo, revisão de dependências e intenções de atualização após navegação. SHALL NOT criar cópias locais de entidades, listas ou exceções já disponíveis nos commands. Estado agregado de loading SHALL ser derivado da execução e do ciclo local, não de flags por request.

#### Scenario: Lacuna entre consultas
- **WHEN** o limite termina e as três seções ainda vão iniciar no mesmo ciclo
- **THEN** o ciclo permanece ocupado para reentrada e interação mensal
- **AND** o fim isolado do command de limite não libera outro refresh

#### Scenario: Refresh normal falha
- **WHEN** um refresh iniciado em conteúdo normal recebe erro financeiro
- **THEN** o latch ativa e o ciclo permanece válido até terminar
- **AND** a classificação de tentativa não é alterada por derivar isRecovering de hasFinancialError

### Requirement: Reconstrução visual é separada da coordenação

Seções SHALL continuar usando seus próprios CommandBuilders. Controles externos que dependem de execução SHALL observar os listenables pertinentes declarativamente. Listeners de coordenação SHALL existir somente para efeitos, latch e pendências, sem setState vazio indiscriminado para cada dado já observado por uma seção. O conjunto de fontes SHALL ser atualizado na troca de dependências e SHALL NOT acumular cadeias no build.

#### Scenario: Seção recebe resultado independente
- **WHEN** Insights conclui enquanto Metrics ainda carrega
- **THEN** o conteúdo de Insights atualiza pelo seu builder
- **AND** o controle mensal permanece bloqueado pelo loading agregado sem exigir cópia de resultado no State

#### Scenario: Rebuild sem mudança de dependências
- **WHEN** a Dashboard é reconstruída por um estado local
- **THEN** não registra novamente subscriptions ou operators permanentes
- **AND** não inicia novas consultas somente por causa desse rebuild

### Requirement: Lente mensal e loading permanecem consistentes

Abertura e troca de mês SHALL preservar o intervalo civil compartilhado, tamanho seis dos recentes e ano/mês de Insights. Setas SHALL continuar bloqueadas enquanto qualquer consulta relevante ou ciclo estiver ocupado, incluindo retry. Troca de mês SHALL NOT mostrar dados anteriores sob o novo título. Estado vazio válido SHALL NOT ser falha.

#### Scenario: Toques rápidos nas setas
- **WHEN** a pessoa tenta trocar de mês novamente durante loading
- **THEN** o toque não muda selectedMonth nem enfileira nova consulta
- **AND** as três seções permanecem consultando a mesma lente vigente

#### Scenario: Novo mês sem dados antigos
- **WHEN** a Dashboard muda de outubro para setembro
- **THEN** apresenta loading de setembro nas seções
- **AND** não utiliza value anterior ou includeLastResult para exibir outubro sob setembro

### Requirement: Erro financeiro persiste até recuperação corrente completa

O latch SHALL ativar no primeiro erro e SHALL permanecer após sucesso das outras operações. Retry SHALL manter a mesma instância, mês e ErrorScreen até três sucessos financeiros da tentativa vigente. Sucesso anterior, inicialValue, adesão a execução anterior ou conclusão causada por descarte SHALL NOT contar para recuperação.

#### Scenario: Falha antes de consultas restantes
- **WHEN** Metrics falha antes das outras duas consultas terminarem
- **THEN** a tela de erro aparece sem aguardar as demais
- **AND** sucessos remanescentes não restauram conteúdo

#### Scenario: Recuperação com outro erro
- **WHEN** duas seções têm sucesso e uma falha no retry
- **THEN** o conteúdo normal não aparece nem temporariamente
- **AND** ao fim do ciclo o loading termina e outra tentativa é permitida

#### Scenario: Value de sucesso anterior preservado
- **WHEN** a tentativa atual falha mas o command conserva value antigo
- **THEN** esse value não libera o latch
- **AND** a decisão utiliza apenas a conclusão válida da tentativa corrente

### Requirement: Recuperação mantém sequência e isolamento auxiliares

Retry SHALL bloquear reentrada antes do primeiro await, consultar User em paralelo ao limite e consultar as três seções em paralelo após aplicar eventual ajuste civil de limite. Falha auxiliar SHALL NOT impedir recuperação financeira. Sucesso nulo do limite SHALL ser tratado como histórico ausente. Nenhum toque bloqueado SHALL criar retry pendente.

#### Scenario: Limite exige ajuste
- **WHEN** o novo primeiro mês válido é posterior à seleção
- **THEN** o ciclo ajusta o mês conforme a regra existente sem avançar além do atual
- **AND** as três consultas financeiras usam o mês ajustado

#### Scenario: Histórico removido completamente
- **WHEN** o limite conclui normalmente com null
- **THEN** o ciclo aplica a regra existente para ausência de histórico
- **AND** não trata null como exceção nem impede as consultas financeiras

#### Scenario: User e limite falham
- **WHEN** ambas as consultas auxiliares falham e as três financeiras têm sucesso
- **THEN** o latch é liberado ao fim do ciclo financeiro válido
- **AND** User mantém fallback e navegação anterior fica bloqueada conforme o limite

#### Scenario: Retry pressionado enquanto ocupado
- **WHEN** a pessoa aciona novamente retry durante consulta anterior ou recuperação
- **THEN** nenhuma nova execução nem intenção pendente de retry é criada

### Requirement: Alterações após navegação produzem uma leitura nova

Retorno do cadastro/listagem com alteração confirmada SHALL recarregar o limite e as três seções no mês preservado. Se houver consulta ou ciclo ocupado, SHALL guardar uma única intenção coalescida e executar novo ciclo quando ficar ocioso. Sem alteração SHALL NOT recarregar dados financeiros. O retorno SHALL ser invalidado por descarte ou troca de dependências.

#### Scenario: Cadastro retorna durante carregamento inicial
- **WHEN** uma criação confirmada retorna enquanto a Dashboard ainda carrega
- **THEN** a atualização fica pendente sem adesão consumidora ao Future antigo
- **AND** uma nova leitura financeira começa após o conjunto relevante ficar ocioso

#### Scenario: Múltiplos sinais durante execução
- **WHEN** mais de um retorno válido pede refresh antes do conjunto ficar ocioso
- **THEN** há uma intenção pendente coalescida
- **AND** não são iniciados vários ciclos simultâneos

#### Scenario: Retorno sem mudanças
- **WHEN** a pessoa cancela ou volta sem criação, atualização ou exclusão confirmada
- **THEN** selectedMonth é preservado e não há novas consultas financeiras

### Requirement: Retorno de User e Settings respeita leitura ocupada

Após retorno válido de User ou Settings, a Dashboard SHALL solicitar uma leitura nova de User. Se a leitura atual estiver ocupada, SHALL esperar seu término e disparar outra, sem interpretar seu resultado como posterior à navegação. A intenção SHALL ser limpa na troca de command ou descarte.

#### Scenario: Nome editado durante leitura antiga
- **WHEN** a navegação termina com UserCommand ainda executando leitura iniciada antes da edição
- **THEN** a Dashboard marca atualização posterior
- **AND** inicia nova leitura quando a anterior termina e a instância continua válida

#### Scenario: Command de User substituído
- **WHEN** o command muda antes de retornar a navegação
- **THEN** o retorno não dispara leitura na instância obsoleta
- **AND** não reaproveita sua intenção para o command novo sem validação

### Requirement: Ciclos obsoletos não alteram a Dashboard

Toda continuation que aplica mês, flags, latch, pendências ou navegação SHALL verificar mounted e identidade/revisão pertinentes. A substituição de dependências SHALL cancelar observações antigas, invalidar ciclos e não permitir que finally antigo encerre loading de um ciclo novo. Dispose SHALL impedir setState e execução posterior.

#### Scenario: Dependências trocadas durante retry
- **WHEN** novos commands são recebidos antes dos antigos terminarem
- **THEN** as conclusões antigas não restauram conteúdo nem alteram o mês atual
- **AND** seu finally não encerra o ciclo das novas dependências

#### Scenario: Future completa ao descartar command
- **WHEN** o descarte completa runAsync com value anterior conforme CommandIt 9.5.2
- **THEN** a revisão inválida impede contar esse valor como sucesso atual
- **AND** nenhum callback inicia outras consultas no State descartado

### Requirement: Refatoração não corrige visual ou navegação incidentalmente

A Dashboard SHALL preservar os textos, rotas, FAB, estrutura de erro e callbacks do baseline vigente, sem introduzir retry localizado ou navegação nova. Divergências conhecidas entre código e change anterior, especialmente cabeçalho no erro, SHALL ser registradas e SHALL NOT ser corrigidas silenciosamente nesta migração.

#### Scenario: Comparação visual antes e depois
- **WHEN** o mesmo cenário de conteúdo ou erro é apresentado antes e depois da refatoração
- **THEN** a estrutura e feedbacks existentes permanecem equivalentes
- **AND** eventual correção de cabeçalho exige escopo separado explicitamente aprovado
