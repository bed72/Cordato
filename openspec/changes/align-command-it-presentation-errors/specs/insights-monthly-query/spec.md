## MODIFIED Requirements

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
