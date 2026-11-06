## MODIFIED Requirements

### Requirement: Mês compartilhado da Dashboard

A Dashboard SHALL iniciar no mês civil atual e usar um único mês selecionado para métricas, insights e despesas recentes. O seletor SHALL permanecer visível e representar o mês selecionado nos estados normais de loading, sucesso e vazio. Durante erro financeiro global ou sua recuperação, o seletor SHALL ficar oculto e a seleção SHALL permanecer no estado da mesma instância da Dashboard.

#### Scenario: Abertura mensal

- **WHEN** a Dashboard é aberta em outubro de 2026
- **THEN** o seletor exibe outubro de 2026 e as três consultas são iniciadas em paralelo para esse mês
- **AND** Metrics recebe 2026-10-01 e 2026-10-31 com agrupamento por categoria, Insights recebe ano 2026 e mês 10 e Expenses recebe o intervalo com tamanho 6

#### Scenario: Mês preservado no erro

- **WHEN** uma seção falha com setembro de 2026 selecionado
- **THEN** o seletor fica oculto na tela de erro
- **AND** setembro de 2026 permanece selecionado para a recuperação

### Requirement: Coordenação e isolamento do carregamento

A Dashboard SHALL desabilitar ambas as setas enquanto qualquer consulta de seção estiver em execução e liberá-las conforme o limite mensal após conclusão bem-sucedida. Trocar o mês SHALL carregar as três seções sem mostrar resultados do mês anterior sob o novo título. Sem falhas, loading, sucesso e vazio das seções SHALL permanecer independentes. Falha de qualquer uma das três consultas financeiras SHALL substituir imediatamente o Scaffold normal por `ErrorScreen`, mesmo que as demais consultas estejam carregando ou tenham sucesso. A Dashboard SHALL NOT apresentar retries localizados de seção. O descarte ou substituição de dependências SHALL remover listeners e invalidar conclusões obsoletas.

#### Scenario: Consultas com tempos distintos

- **WHEN** métricas e despesas terminam com sucesso, mas insights ainda carregam
- **THEN** os resultados concluídos aparecem e as duas setas permanecem desabilitadas até a conclusão bem-sucedida de insights

#### Scenario: Falha parcial

- **WHEN** insights falham e as outras duas consultas terminam com sucesso
- **THEN** a Dashboard apresenta somente a tela de erro global sem cabeçalho e com uma ação de retry no footer
- **AND** não exibe métricas, insights, recentes, seletor mensal ou botão flutuante

#### Scenario: Falha antes das outras conclusões

- **WHEN** métricas falham enquanto insights e despesas ainda estão em execução
- **THEN** a tela de erro aparece imediatamente sem esperar as consultas restantes
- **AND** o retry permanece desabilitado enquanto há consultas da Dashboard em execução
- **AND** sucessos posteriores das consultas restantes não removem a tela de erro

#### Scenario: Erros de despesas e exceções

- **WHEN** despesas retornam Left ou qualquer command financeiro conclui com exceção observável
- **THEN** a mesma tela de erro global é apresentada
- **AND** não são exibidas mensagens técnicas ou erros duplicados por seção

#### Scenario: Nova seleção sem dados antigos

- **WHEN** a pessoa muda de outubro para setembro
- **THEN** as três seções apresentam carregamento de setembro sem exibir dados de outubro sob o título de setembro

#### Scenario: Tela descartada durante consulta

- **WHEN** a Dashboard é descartada antes de uma consulta terminar
- **THEN** a conclusão não atualiza o estado descartado e os recursos de observação criados pela tela são removidos

#### Scenario: Retry localizado

- **WHEN** uma seção financeira falha
- **THEN** a Dashboard não oferece retry localizado nessa seção
- **AND** apresenta somente a ação de recuperação global, que recarrega as três seções no mês vigente

## ADDED Requirements

### Requirement: Conteúdo único do erro financeiro

A Dashboard SHALL usar `ErrorScreen` com o título “Não foi possível carregar sua Dashboard.”, descrição “Não conseguimos carregar suas informações agora. Tente novamente.” e ação principal “Tentar novamente”. A ErrorScreen da Dashboard SHALL NOT receber appBar; saudação, avatar e ações do cabeçalho SHALL permanecer ocultos durante erro e recuperação. A substituição de Scaffold SHALL ocorrer no mesmo State, sem navegação ou nova instância da Dashboard.

#### Scenario: Várias seções com erro

- **WHEN** as três consultas financeiras falham
- **THEN** há uma única mensagem com o título e a descrição definidos e um único botão “Tentar novamente” no footer
- **AND** avatar, notificações e Settings não são exibidos durante o erro

### Requirement: Recuperação única e estável da Dashboard

O retry global SHALL recarregar usuário, limite do histórico, métricas, insights e recentes sob coordenação da Dashboard. Novas tentativas SHALL ser bloqueadas enquanto houver consultas da Dashboard em execução ou recuperação ativa, sem enfileirar toques bloqueados. User SHALL poder carregar em paralelo ao limite; as três seções SHALL ser consultadas em paralelo após o limite resolver, usando o mês preservado ou o ajuste civil existente quando um novo limite válido tornar a seleção inválida. A tela de erro SHALL permanecer durante a tentativa, com loading no botão principal. O Scaffold normal SHALL ser restaurado somente quando as três consultas financeiras da tentativa vigente concluírem com sucesso. Falha de usuário ou do limite SHALL NOT impedir a recuperação financeira; a última SHALL manter bloqueado o retorno para meses anteriores. Não SHALL haver retry automático.

#### Scenario: Recuperação bem-sucedida em mês histórico

- **WHEN** a pessoa aciona o retry em setembro de 2026 e o novo limite não invalida esse mês
- **THEN** usuário e limite são recarregados e as três seções consultam setembro de 2026
- **AND** a tela de erro permanece com loading até a recuperação financeira concluir
- **AND** os três sucessos restauram seletor, seções e botão flutuante na mesma instância

#### Scenario: Outra falha durante a recuperação

- **WHEN** uma das três consultas falha na tentativa de recuperação
- **THEN** a tela de erro permanece sem flashes de conteúdo normal ou skeletons de seções
- **AND** ao término do ciclo o botão deixa o loading e permite uma nova tentativa

#### Scenario: Toques repetidos

- **WHEN** a pessoa tenta acionar retry enquanto uma consulta anterior ou recuperação está em andamento
- **THEN** nenhuma consulta concorrente ou tentativa pendente é criada

#### Scenario: Resultado anterior não recupera a tela

- **WHEN** uma seção preserva um resultado de sucesso anterior enquanto a tentativa atual ainda está em andamento
- **THEN** esse resultado não é contado como sucesso da recuperação vigente

#### Scenario: Limite histórico atualizado

- **WHEN** um novo limite válido é posterior ao mês selecionado
- **THEN** a seleção é ajustada conforme a regra civil existente, sem avançar além do mês atual
- **AND** as três seções são consultadas para o mês ajustado

#### Scenario: Falhas auxiliares com recuperação financeira

- **WHEN** usuário ou limite falham mas as três consultas financeiras da tentativa concluem com sucesso
- **THEN** o conteúdo normal é restaurado
- **AND** falha de usuário mostra “Cordato” e falha do limite mantém a seta anterior bloqueada

#### Scenario: Dependências substituídas durante retry

- **WHEN** os commands da Dashboard são substituídos ou a tela é descartada durante recuperação
- **THEN** callbacks e conclusões do ciclo anterior não restauram nem alteram o estado vigente

### Requirement: Fallback do usuário sem retry no cabeçalho

O cabeçalho SHALL mostrar “Cordato” e o avatar placeholder quando a consulta de User retornar Left ou exceção. A saudação SHALL permanecer visível e não SHALL haver ação “Tentar novamente” junto ao nome. Sucesso SHALL preservar nome e semente da API com os fallbacks existentes de avatar; loading SHALL preservar o skeleton. Falha apenas de User ou do limite do histórico SHALL NOT ativar erro financeiro global.

#### Scenario: Falha somente no usuário

- **WHEN** User falha e as consultas financeiras concluem com sucesso
- **THEN** o cabeçalho mostra saudação, “Cordato” e avatar placeholder, sem retry localizado
- **AND** o conteúdo financeiro normal permanece disponível

#### Scenario: Usuário recuperado pelo retry global

- **WHEN** User carrega com sucesso durante o retry financeiro
- **THEN** o nome e avatar retornados substituem o fallback no cabeçalho quando o conteúdo normal for restaurado

#### Scenario: Falha somente no limite

- **WHEN** a consulta do limite do histórico falha e as três seções financeiras têm sucesso
- **THEN** a Dashboard permanece com seu conteúdo normal e a seta anterior bloqueada
