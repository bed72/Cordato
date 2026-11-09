> Delta histórico; listagem agora recarrega em todo retorno e cadastro exige
> resultado confirmado. Consulte [a referência vigente](../../../../README.md).

## MODIFIED Requirements

### Requirement: Mês compartilhado da Dashboard

A Dashboard SHALL iniciar no mês civil atual e usar um único mês selecionado para métricas, insights e despesas recentes. O rótulo mês/ano SHALL permanecer visível em loading, sucesso e vazio. Durante loading, os botões anterior/próximo SHALL ser skeletons estáveis sem callbacks, foco ou ações acessíveis. Durante erro financeiro todo o seletor SHALL ficar oculto. Retry SHALL voltar ao loading normal, mantendo a seleção na mesma instância.

#### Scenario: Abertura mensal
- **WHEN** a Dashboard abre em outubro de 2026
- **THEN** mostra outubro de 2026 e skeletons nos controles durante carregamento
- **AND** consulta User e limite antes das três seções em paralelo: Metrics para 2026-10-01 até 2026-10-31 com categoria, Insights para ano 2026/mês 10 e recentes com tamanho 6

#### Scenario: Mês preservado no erro
- **WHEN** uma seção falha com setembro de 2026 selecionado
- **THEN** oculta o seletor e mantém setembro de 2026 para recuperação

#### Scenario: Controles em carregamento
- **WHEN** um ciclo financeiro ou a consulta relevante de limite está ocupado em conteúdo normal
- **THEN** mantém mês/ano legíveis, anuncia carregamento sem textos fictícios e mostra skeletons sem ações mensais
- **AND** toques ou ações acessíveis não alteram mês nem enfileiram consulta

### Requirement: Coordenação e isolamento do carregamento

A Dashboard SHALL bloquear navegação mensal durante loading e restaurar controles conforme os limites ao terminar. Trocar mês SHALL executar a carga única de cinco leituras sem mostrar dados antigos ou parciais. Conteúdo e vazios das três seções SHALL aparecer juntos após todas concluírem. Qualquer falha financeira SHALL produzir ErrorScreen ao concluir a carga. SHALL NOT haver retries localizados. Fechamento ou substituição SHALL invalidar conclusões antigas, sem cancelamento HTTP.

#### Scenario: Consultas com tempos distintos
- **WHEN** métricas e recentes terminam, mas insights ainda carregam
- **THEN** todas as seções e o cabeçalho continuam em skeleton, sem resultados parciais

#### Scenario: Falha parcial
- **WHEN** insights falham após as outras consultas terem sucesso
- **THEN** mostra apenas ErrorScreen sem cabeçalho, seções, seletor ou FAB
- **AND** oferece somente recuperação global no footer

#### Scenario: Falha antes das outras conclusões
- **WHEN** métricas falham enquanto insights e recentes estão em execução
- **THEN** mantém loading até as outras consultas concluírem
- **AND** publica um único estado de erro sem dados parciais ou feedback duplicado
- **AND** libera retry manual após concluir a carga

#### Scenario: Falhas tipadas e inesperadas
- **WHEN** recentes retornam Left ou uma consulta financeira vigente lança exceção inesperada
- **THEN** aplica a mesma política global sem mensagem técnica nem feedback duplicado por seção

#### Scenario: Novo mês sem dados antigos
- **WHEN** muda de outubro para setembro
- **THEN** as três seções carregam setembro sem mostrar outubro sob o novo título

#### Scenario: Tela fechada durante consulta
- **WHEN** a Dashboard é fechada ou seu Bloc é substituído antes da conclusão
- **THEN** invalida as leituras pertencentes à instância anterior e impede emissões tardias

### Requirement: Atualização e navegação preservam o mês

A Dashboard SHALL preservar o mês selecionado no refresh e no retorno de cadastro/listagem, salvo ajuste civil necessário após nova leitura válida do limite. Somente retorno com alteração confirmada SHALL recarregar dados financeiros. Se um ciclo estiver ocupado, esse retorno SHALL invalidá-lo e iniciar outro imediatamente, relendo limite antes das três seções, sem esperar leituras antigas. Retorno sem alteração SHALL NOT iniciar leitura financeira. O formulário SHALL continuar iniciando com hoje e o hold SHALL manter seu comportamento.

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
- **THEN** invalida esse ciclo e começa outro imediatamente no mês preservado
- **AND** não espera os Futures anteriores nem usa seus resultados como posteriores à alteração

### Requirement: Recuperação única e estável da Dashboard

Retry global SHALL ser uma carga normal de usuário, limite, métricas, insights e recentes. SHALL sair de failure para loading e terminar em ready ou failure, sem fase ou barreira de recuperação. User e limite SHALL carregar em paralelo, seguidos das três seções em paralelo após ajuste civil. Toques bloqueados SHALL NOT interromper a carga ou criar fila. Falhas auxiliares SHALL usar fallbacks; falha de limite SHALL bloquear a seta anterior. SHALL NOT haver retry automático ou cancelamento HTTP.

#### Scenario: Recuperação bem-sucedida em mês histórico
- **WHEN** aciona retry em setembro e o limite não invalida a seleção
- **THEN** consulta User e limite e depois as três seções em setembro
- **AND** mostra o mesmo skeleton da abertura até publicar conteúdo na mesma instância

#### Scenario: Outra falha durante recuperação
- **WHEN** uma seção falha no retry
- **THEN** termina a carga em failure após concluir as seções, sem publicar conteúdo parcial
- **AND** libera outra tentativa manual

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
- **THEN** invalida conclusões e callbacks de navegação antigos
- **AND** nenhuma finalização antiga altera o estado da nova instância
