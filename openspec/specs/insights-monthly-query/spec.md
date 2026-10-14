# insights-monthly-query Specification

## Purpose
Definir a consulta de insights por ano e mês, preservando as análises retornadas
pela API e os metadados de falhas.
## Requirements
### Requirement: Consulta opcional por ano e mês

Os contratos de repository, data source e command de Insight SHALL aceitar ano e mês opcionais e delegá-los sem defaults ou normalização. O data source SHALL executar GET relativo protegido `insights` e serializar os valores não nulos como `filter[year]` e `filter[month]`. Ausência dos dois filtros SHALL preservar a consulta geral existente.

#### Scenario: Consulta de setembro
- **WHEN** o command recebe ano 2026 e mês 9
- **THEN** os parâmetros são delegados ao repository e data source e a requisição contém `filter[year]=2026` e `filter[month]=9`

#### Scenario: Consulta sem filtros
- **WHEN** ano e mês são nulos
- **THEN** a requisição não envia esses filtros e o resultado mantém o contrato atual

### Requirement: Preservação das análises retornadas

Insight SHALL preservar ordem, título, descrição, tipo, grupo, período anulável e comparação da API. O mês solicitado SHALL ser tratado como referência da análise, sem filtrar cards novamente pelas datas de seu período ou reconstruir análises no aplicativo.

#### Scenario: Análise de vários meses
- **WHEN** a consulta de setembro retorna um insight de liderança de categoria de julho a setembro
- **THEN** o card é exibido com seu texto e período originais, sem corte ou exclusão por incluir julho e agosto

#### Scenario: Onboarding sem período
- **WHEN** a API retorna um insight com `period: null`
- **THEN** o aplicativo preserva o período nulo e exibe o título e a descrição sem inventar datas

### Requirement: Falhas preservam metadados e resultado

Os contratos de repository e data source de consultas filtradas SHALL preservar o padrão `Either`, incluindo erros JSON:API com `source.parameter` ou `source.pointer`, e tradução de parsing inválido e exceções conforme os contratos existentes. GetInsightsCommand SHALL adaptar Right para lista de InsightEntity no canal de dados e Left para CommandFailureException no canal nativo de erro, conservando a mesma ErrorsEntity e todos os metadados. Um filtro ausente SHALL NOT ser completado automaticamente pelo cliente. A adaptação SHALL NOT modificar conteúdo, ordem ou período dos insights nem transformar exceções inesperadas em falhas esperadas artificiais.

#### Scenario: Apenas ano informado
- **WHEN** somente ano é informado e a API retorna 422 com `source.parameter` igual a `filter[month]`
- **THEN** o repository preserva Left com o erro sem inserir um mês padrão
- **AND** o command publica a exceção tipada que conserva esse parameter e qualquer pointer original

#### Scenario: Lista vazia
- **WHEN** a API retorna `data: []` para o mês consultado
- **THEN** o command retorna sucesso com lista vazia diretamente em results.data
- **AND** esse resultado não é interpretado como falha financeira ou estado inicial

#### Scenario: Parsing inválido em um card
- **WHEN** um recurso da lista mensal não pode ser convertido
- **THEN** o repository retorna erro sem lista parcial
- **AND** o command adapta esse erro para seu canal nativo sem publicar itens válidos parciais

#### Scenario: Exceção inesperada do repository
- **WHEN** o repository lança uma exceção em vez de retornar Either
- **THEN** o CommandIt expõe a exceção original conforme sua política nativa
- **AND** a apresentação utiliza o fallback existente sem perder a distinção de CommandFailureException

