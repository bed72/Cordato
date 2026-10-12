## ADDED Requirements

### Requirement: Mês compartilhado da Dashboard

A Dashboard SHALL iniciar no mês civil atual e usar um único mês selecionado para gráfico, insights e despesas recentes. O seletor SHALL permanecer visível e representar o mês selecionado em todos os estados das seções.

#### Scenario: Abertura mensal
- **WHEN** a Dashboard é aberta em outubro de 2026
- **THEN** o seletor exibe outubro de 2026 e as três consultas são iniciadas em paralelo para esse mês
- **AND** Metrics recebe 2026-10-01 e 2026-10-31 com agrupamento por categoria, Insights recebe ano 2026 e mês 10 e Expenses recebe o intervalo com tamanho 6

### Requirement: Navegação mensal somente por setas

A Dashboard SHALL permitir mudar o mês somente pelas setas anterior/próximo, sem swipe mensal. A navegação SHALL impedir meses posteriores ao mês civil atual e calcular corretamente viradas de ano e o último dia de cada mês.

#### Scenario: Limite do mês atual
- **WHEN** o mês selecionado é o mês atual e nenhuma consulta está em execução
- **THEN** a seta de próximo mês fica desabilitada e a de mês anterior fica habilitada

#### Scenario: Virada de ano
- **WHEN** a pessoa volta um mês a partir de janeiro de 2026
- **THEN** as três seções consultam dezembro de 2025, com intervalo de 2025-12-01 a 2025-12-31

#### Scenario: Fevereiro bissexto
- **WHEN** a pessoa seleciona fevereiro de 2024
- **THEN** o intervalo civil consultado vai de 2024-02-01 a 2024-02-29

#### Scenario: Gesto horizontal nos insights
- **WHEN** a pessoa desliza horizontalmente os cards de insights
- **THEN** a lista de cards rola sem mudar o mês da Dashboard

### Requirement: Coordenação e isolamento do carregamento

A Dashboard SHALL desabilitar ambas as setas enquanto qualquer consulta de seção estiver em execução e liberá-las conforme o limite mensal após todas terminarem, inclusive após falhas. Trocar o mês SHALL carregar as três seções sem mostrar resultados do mês anterior sob o novo título. Estados de sucesso, vazio e falha SHALL permanecer independentes, e cada seção com erro SHALL oferecer retry no mês selecionado.

#### Scenario: Consultas com tempos distintos
- **WHEN** gráfico e despesas terminam, mas insights ainda carregam
- **THEN** os resultados concluídos aparecem e as duas setas permanecem desabilitadas até a conclusão de insights

#### Scenario: Falha parcial
- **WHEN** insights falham e as outras duas consultas terminam com sucesso
- **THEN** gráfico e despesas são exibidos, insights mostram erro com retry e as setas são liberadas conforme o limite mensal

#### Scenario: Nova seleção sem dados antigos
- **WHEN** a pessoa muda de outubro para setembro
- **THEN** as três seções apresentam carregamento de setembro sem exibir dados de outubro sob o título de setembro

#### Scenario: Retry localizado
- **WHEN** a pessoa tenta novamente uma seção que falhou
- **THEN** somente essa seção é consultada para o mês selecionado e as setas ficam bloqueadas durante sua execução

#### Scenario: Tela descartada durante consulta
- **WHEN** a Dashboard é descartada antes de uma consulta terminar
- **THEN** a conclusão não atualiza o estado descartado e os recursos de observação criados pela tela são removidos

### Requirement: Atualização e navegação preservam o mês

A Dashboard SHALL preservar o mês selecionado em refresh e retorno do cadastro ou da listagem. O retorno SHALL recarregar as três seções nesse mês. O cadastro SHALL continuar iniciando com a data civil de hoje.

#### Scenario: Refresh histórico
- **WHEN** a pessoa atualiza por gesto a Dashboard em setembro de 2026
- **THEN** as três consultas usam setembro de 2026 e a seleção não muda para o mês atual

#### Scenario: Cadastro a partir de mês histórico
- **WHEN** a pessoa abre o cadastro pela Dashboard em um mês passado e conclui por toque simples
- **THEN** o formulário inicia com hoje e retorna à Dashboard com o mês passado preservado e as três seções recarregadas

#### Scenario: Hold no cadastro
- **WHEN** a pessoa cadastra com hold a partir da Dashboard
- **THEN** o formulário mantém o comportamento de limpar após sucesso e permanecer aberto, sem alterar o contexto mensal da Dashboard

#### Scenario: Retorno sem cadastro
- **WHEN** a pessoa cancela o formulário ou retorna de “Ver tudo”
- **THEN** a Dashboard preserva o mês selecionado e recarrega suas três seções

### Requirement: Estados vazios mensais

A Dashboard SHALL representar ausência de dados sem fabricar valores, despesas ou insights. Insights vazios SHALL manter a seção oculta; recentes vazios SHALL indicar ausência de despesas naquele mês; gráfico com total zero SHALL apresentar o estado vazio existente.

#### Scenario: Mês sem dados
- **WHEN** as consultas retornam total zero, despesas vazias e insights vazios
- **THEN** o seletor permanece visível, o gráfico não cria segmentos fictícios, recentes indicam vazio e a seção de insights fica oculta
