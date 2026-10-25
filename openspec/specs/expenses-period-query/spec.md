# expenses-period-query Specification

> Implementação atual: contratos Future/exceções, HTTP e Bloc. Navegação ocorre
> no widget/mixin via BuildContext; argumentos contêm somente dados. Consulte
> [a referência vigente](../../README.md), não os mecanismos legados desta spec.

## Purpose
Definir consultas de despesas por intervalo civil e preservar esse recorte na
listagem, paginação, edição e exclusão.
## Requirements
### Requirement: Consulta opcional por intervalo civil

Os contratos de repository, data source e command de Expense SHALL aceitar `from` e `to` opcionais junto à paginação, delegando o intervalo sem defaults ou normalização. O data source SHALL serializar os valores não nulos como `filter[from]` e `filter[to]` em `yyyy-MM-dd` pelos componentes civis, sem conversão de fuso, em GET relativo protegido `expenses`. Ausência de intervalo SHALL preservar a consulta geral.

#### Scenario: Seis recentes de setembro
- **WHEN** a consulta recebe 2026-09-01, 2026-09-30, tamanho 6 e continuação nula
- **THEN** a requisição envia os dois filtros e `page[size]=6`, e os itens mantêm a ordem da API sem filtragem local de uma página geral

#### Scenario: Consulta geral
- **WHEN** ambos os limites são nulos
- **THEN** a consulta inicial não envia filtros de intervalo e preserva as regras existentes de paginação e tamanho efetivo

#### Scenario: Delegação de limite incompleto
- **WHEN** somente um limite é informado ao repository
- **THEN** ele é delegado sem fabricar o limite ausente e qualquer erro remoto é preservado

### Requirement: Paginação preserva o intervalo explícito

A listagem SHALL repassar o intervalo atualmente ativo em todas as consultas sem interpretar a continuação. O data source SHALL extrair a query do link opaco, manter o endpoint relativo, fazer o tamanho solicitado e os limites explícitos prevalecerem sobre os do link e remover filtros de ano, mês ou dia herdados quando um intervalo explícito estiver ativo. Outros parâmetros de continuação SHALL ser preservados. Remover o período na apresentação SHALL iniciar uma primeira página com limites e continuação nulos; páginas seguintes SHALL usar somente continuações da nova lente, sem reintroduzir o intervalo removido.

#### Scenario: Link sem filtros
- **WHEN** a próxima página oferece um link com continuação, mas sem intervalo
- **THEN** a requisição mantém a continuação e reaplica o intervalo selecionado e `page[size]=20`

#### Scenario: Link com período conflitante
- **WHEN** o link contém limites diferentes ou filtros de ano, mês ou dia e a tela consulta setembro por intervalo explícito
- **THEN** a requisição usa os limites de setembro, remove a combinação conflitante e mantém os demais parâmetros de continuação

#### Scenario: Destino absoluto da continuação
- **WHEN** o link de próxima página contém uma URL absoluta
- **THEN** somente sua query é utilizada na requisição ao endpoint relativo `expenses`, seguindo a política existente de paginação

#### Scenario: Continuação após remover mês
- **WHEN** a pessoa remove setembro e a primeira página do histórico oferece continuação
- **THEN** as páginas seguintes usam essa nova continuação com limites explícitos nulos, preservando eventual categoria ativa e sem reaproveitar o cursor de setembro

### Requirement: Listagem contextualizada pela Dashboard

“Ver tudo” SHALL abrir `/expenses` com o intervalo do mês selecionado como filtro inicial. A listagem SHALL identificar esse período por mês e ano em pílula removível e semântica, mantendo título “Despesas” e descrição fixa “Acompanhe todas as suas despesas.”. SHALL manter páginas de 20 itens, ordenação, agrupamentos e os filtros atualmente ativos em abertura, refresh, retry e paginação. A rota sem período SHALL continuar mostrando a listagem geral, respeitando eventual categoria recebida. Remover a pílula de período SHALL ampliar a consulta para todo o histórico e manter os outros filtros ativos.

#### Scenario: Ver tudo em setembro
- **WHEN** a pessoa abre “Ver tudo” na Dashboard de setembro de 2026
- **THEN** a listagem mostra a descrição fixa e a pílula de setembro de 2026 e consulta somente o intervalo de 2026-09-01 a 2026-09-30

#### Scenario: Refresh e retry filtrados
- **WHEN** a pessoa atualiza a listagem filtrada ou repete uma consulta que falhou
- **THEN** a operação mantém o intervalo ativo e repete a operação correspondente, preservando itens carregados em caso de falha de refresh ou paginação sem troca de lente

#### Scenario: Entrada sem contexto mensal
- **WHEN** `/expenses` é aberta sem argumento de período
- **THEN** a listagem consulta despesas sem adicionar um recorte mensal

#### Scenario: Remoção de contexto mensal
- **WHEN** a pessoa remove a pílula de setembro
- **THEN** o período ativo fica nulo, a listagem consulta a primeira página do histórico e refresh/retry/paginação posteriores não restauram setembro

### Requirement: Mutações respeitam o recorte

A listagem filtrada SHALL manter os comportamentos existentes de edição e exclusão, usando os filtros atualmente ativos em vez dos parâmetros iniciais da navegação. Edição com data civil fora do intervalo ativo ou categoria fora da categoria ativa SHALL remover o item do recorte; edição que pertence à lente ativa SHALL atualizar ou reposicionar o item. Ausência de período ou categoria SHALL retirar somente a restrição correspondente. As operações SHALL preservar rolagem e paginação e remover cabeçalhos que fiquem sem itens.

#### Scenario: Edição muda o mês
- **WHEN** uma despesa de setembro é atualizada para outubro enquanto setembro permanece ativo
- **THEN** o item é removido da lista de setembro sem reinserção, preservando paginação e rolagem

#### Scenario: Edição permanece no mês
- **WHEN** a data é alterada para outro dia dentro de setembro enquanto esse período permanece ativo
- **THEN** o item é reposicionado conforme a data civil, mantendo os agrupamentos existentes

#### Scenario: Exclusão do último item de um grupo
- **WHEN** o último item de um grupo é excluído na listagem filtrada
- **THEN** seu cabeçalho desaparece e eventuais consultas seguintes continuam usando os filtros ativos

#### Scenario: Edição muda o mês após remover período
- **WHEN** a pessoa remove setembro e uma despesa é atualizada para outubro sem deixar de pertencer à categoria ativa
- **THEN** o item permanece na consulta do histórico e é reposicionado, sem aplicar o intervalo inicial removido

#### Scenario: Categoria retornada muda após remover filtro
- **WHEN** a categoria já foi removida e uma edição retorna uma despesa de outra categoria dentro do período ativo
- **THEN** o item permanece na listagem, sem aplicar a categoria inicial removida

#### Scenario: Categoria retornada deixa a lente ativa
- **WHEN** uma edição retorna categoria diferente da que permanece ativa
- **THEN** o item é removido do recorte e a continuação preserva os filtros ativos

### Requirement: Conversão e erros permanecem consistentes

Consultas filtradas SHALL preservar validação dos centavos de todos os itens, continuadores `next`/`prev` anuláveis e metadados de erros JSON:API, sem resultados parciais. Os filtros SHALL NOT alterar a representação monetária por centavos inteiros.

#### Scenario: Erro de filtro por pointer
- **WHEN** a API retorna 422 com `source.pointer` igual a `/filter/from`
- **THEN** o repository e command preservam o erro com o pointer original

#### Scenario: Centavos inválidos na página
- **WHEN** um item da página filtrada possui centavos inválidos
- **THEN** a consulta retorna erro sem aproveitar parcialmente os demais itens
