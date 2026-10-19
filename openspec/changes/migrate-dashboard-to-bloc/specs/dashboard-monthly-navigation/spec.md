## MODIFIED Requirements

### Requirement: Mês compartilhado da Dashboard

A Dashboard SHALL iniciar no mês civil atual e usar um único mês selecionado para métricas, insights e despesas recentes. O rótulo mês/ano SHALL permanecer visível em loading normal, sucesso e vazio. Durante carregamento agregado, os botões anterior/próximo SHALL ser substituídos por skeletons de dimensões estáveis, sem callbacks, foco ou ações acessíveis ativas. Durante erro financeiro global ou recuperação, todo o seletor SHALL ficar oculto e a seleção SHALL permanecer no estado da mesma instância da Dashboard.

#### Scenario: Abertura mensal
- **WHEN** a Dashboard abre em outubro de 2026
- **THEN** mostra outubro de 2026 e skeletons nos controles durante carregamento
- **AND** inicia as três consultas em paralelo: Metrics para 2026-10-01 até 2026-10-31 com categoria, Insights para ano 2026/mês 10 e recentes para o mesmo intervalo com tamanho 6

#### Scenario: Mês preservado no erro
- **WHEN** uma seção falha com setembro de 2026 selecionado
- **THEN** oculta o seletor e mantém setembro de 2026 para recuperação

#### Scenario: Controles em carregamento
- **WHEN** um ciclo financeiro ou a consulta relevante de limite está ocupado em conteúdo normal
- **THEN** mantém mês/ano legíveis, anuncia carregamento sem textos fictícios e mostra skeletons sem ações mensais
- **AND** toques ou ações acessíveis não alteram mês nem enfileiram consulta

### Requirement: Coordenação e isolamento do carregamento

A Dashboard SHALL bloquear a navegação mensal durante carregamento agregado, mostrando skeletons em vez dos botões, e restaurar controles conforme os limites ao terminar. Trocar mês SHALL carregar as três seções sem mostrar dados anteriores sob o novo título. Sem falhas, loading, sucesso e vazio das seções SHALL permanecer independentes. A primeira falha financeira vigente SHALL substituir imediatamente o Scaffold por ErrorScreen e cancelar as outras consultas financeiras do ciclo. SHALL NOT haver retries localizados. Fechamento ou substituição do Bloc SHALL cancelar recursos e invalidar conclusões antigas.

#### Scenario: Consultas com tempos distintos
- **WHEN** métricas e recentes terminam, mas insights ainda carregam
- **THEN** os resultados concluídos aparecem e os controles mensais continuam em skeleton

#### Scenario: Falha parcial
- **WHEN** insights falham após as outras consultas terem sucesso
- **THEN** mostra apenas ErrorScreen sem cabeçalho, seções, seletor ou FAB
- **AND** oferece somente recuperação global no footer

#### Scenario: Falha antes das outras conclusões
- **WHEN** métricas falham enquanto insights e recentes estão em execução
- **THEN** mostra ErrorScreen imediatamente e cancela ambas as requests financeiras restantes
- **AND** não permite que suas conclusões restaurem conteúdo ou produzam erros duplicados
- **AND** libera retry após encerrar logicamente o ciclo e não haver leitura auxiliar vigente bloqueante

#### Scenario: Falhas tipadas e inesperadas
- **WHEN** recentes retornam Left ou uma consulta financeira vigente lança exceção inesperada
- **THEN** aplica a mesma política global sem mensagem técnica nem feedback duplicado por seção

#### Scenario: Novo mês sem dados antigos
- **WHEN** muda de outubro para setembro
- **THEN** as três seções carregam setembro sem mostrar outubro sob o novo título

#### Scenario: Tela fechada durante consulta
- **WHEN** a Dashboard é fechada ou seu Bloc é substituído antes da conclusão
- **THEN** cancela as leituras pertencentes à instância anterior e impede emissões tardias

### Requirement: Atualização e navegação preservam o mês

A Dashboard SHALL preservar o mês selecionado no refresh e no retorno de cadastro/listagem, salvo ajuste civil necessário após nova leitura válida do limite. Somente retorno com alteração confirmada SHALL recarregar dados financeiros. Se um ciclo estiver ocupado, esse retorno SHALL invalidá-lo, cancelar suas leituras e iniciar outro imediatamente, relendo limite antes das três seções. Retorno sem alteração SHALL NOT iniciar leitura financeira. O formulário SHALL continuar iniciando com hoje e o hold SHALL manter seu comportamento.

#### Scenario: Refresh histórico
- **WHEN** atualiza por gesto em setembro de 2026 e o limite permanece válido
- **THEN** relê limite e consulta as três seções para setembro, sem mudar para o mês atual

#### Scenario: Cadastro a partir de mês histórico
- **WHEN** abre cadastro em um mês passado e conclui por toque simples
- **THEN** o formulário usa hoje e retorna à mesma Dashboard com o mês passado preservado quando válido
- **AND** inicia leitura financeira nova

#### Scenario: Hold no cadastro
- **WHEN** cadastra com hold e permanece no formulário
- **THEN** mantém limpeza e permanência atuais sem alterar o contexto mensal da Dashboard
- **AND** o retorno posterior carrega uma única intenção válida de alteração confirmada

#### Scenario: Retorno sem mudanças
- **WHEN** cancela o formulário ou retorna da listagem sem criação, edição ou exclusão confirmada
- **THEN** preserva mês e dados, sem nova leitura financeira

#### Scenario: Alteração confirmada durante carregamento
- **WHEN** retorna com alteração enquanto ainda existe um ciclo financeiro ativo
- **THEN** cancela e invalida esse ciclo e começa outro imediatamente no mês preservado
- **AND** não espera os Futures anteriores nem usa seus resultados como posteriores à alteração

### Requirement: Recuperação única e estável da Dashboard

Retry global SHALL recarregar usuário, limite, métricas, insights e recentes sob coordenação do Bloc. Toques bloqueados SHALL NOT criar nova tentativa nem cancelar a vigente. User SHALL carregar em paralelo ao limite, substituindo leitura antiga se houver; as três seções SHALL carregar em paralelo após o limite resolver e eventual ajuste civil. ErrorScreen SHALL permanecer com loading na ação até o ciclo de recuperação terminar. Somente três sucessos financeiros vigentes SHALL restaurar conteúdo. Falha financeira SHALL cancelar as outras consultas financeiras e manter erro; falhas auxiliares SHALL NOT impedir recuperação financeira, mas falha de limite SHALL bloquear navegação anterior. SHALL NOT haver retry automático. Cancelamento intencional SHALL NOT ser apresentado como falha nova.

#### Scenario: Recuperação bem-sucedida em mês histórico
- **WHEN** aciona retry em setembro e o limite não invalida a seleção
- **THEN** consulta User e limite e depois as três seções em setembro
- **AND** mantém ErrorScreen em loading até concluir o ciclo e restaura conteúdo na mesma instância

#### Scenario: Outra falha durante recuperação
- **WHEN** uma seção falha no retry
- **THEN** cancela as outras consultas financeiras e mantém ErrorScreen sem flashes de conteúdo
- **AND** após encerrar o ciclo e auxiliares bloqueantes libera outra tentativa manual

#### Scenario: Toques repetidos
- **WHEN** tenta retry enquanto o ciclo ou leitura auxiliar vigente impede nova tentativa
- **THEN** não cria tentativa pendente nem interrompe a recuperação aceita

#### Scenario: Resultado de ciclo anterior
- **WHEN** um resultado antigo termina durante recuperação de um ciclo novo
- **THEN** não é contado como sucesso nem altera erro, dados ou loading atuais

#### Scenario: Limite histórico atualizado
- **WHEN** o novo primeiro mês válido é posterior à seleção
- **THEN** ajusta a seleção pela regra civil existente, sem avançar além do mês atual
- **AND** consulta as três seções para o mês ajustado

#### Scenario: Falhas auxiliares com recuperação financeira
- **WHEN** User ou limite falham e as três seções têm sucesso
- **THEN** restaura conteúdo ao encerrar o ciclo com fallback de usuário quando pertinente
- **AND** mantém seta anterior bloqueada se o limite falhou

#### Scenario: Bloc substituído durante recuperação
- **WHEN** a instância é fechada ou substituída durante retry
- **THEN** cancela suas leituras e invalida conclusões e callbacks de navegação antigos
- **AND** nenhuma finalização antiga altera o estado da nova instância
