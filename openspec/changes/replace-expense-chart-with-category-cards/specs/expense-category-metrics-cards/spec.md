## ADDED Requirements

### Requirement: Distribuição mensal em cards de categorias

A seção de Metrics SHALL substituir o gráfico segmentado por cards das categorias com `totalAmount > 0` no mês selecionado na Dashboard. A apresentação SHALL manter o total mensal acima dos cards, formatar valores em centavos pelo `IMoneyFormatter` e preservar o percentual fornecido pela API, sem recalcular agregações ou alterar as entidades recebidas. Os cards SHALL ser informativos, sem navegação para despesas ou seleção de categoria.

#### Scenario: Categorias em uso no mês
- **WHEN** a consulta do mês retorna categorias com totais positivos e zero
- **THEN** somente as categorias com totais positivos aparecem como cards
- **AND** o total mensal permanece o valor fornecido pela API

#### Scenario: Percentual relativo ao mês
- **WHEN** uma categoria aparece em qualquer página do carrossel
- **THEN** seu percentual corresponde ao valor recebido da API para o total mensal
- **AND** não é recalculado em relação às categorias daquela página

### Requirement: Ordenação e destaque relativo

A apresentação SHALL ordenar uma cópia das categorias visíveis por `totalAmount` decrescente, preservando a ordem original entre empates. SHALL dividir essa sequência em grupos consecutivos de até três itens. O primeiro item de cada grupo SHALL receber o destaque visual e a ilustração, independentemente de faixas de percentual. Em grupos de dois, ambos os cards SHALL receber ilustração. A área dos cards SHALL seguir o padrão de composição, sem promessa de proporcionalidade exata aos gastos.

#### Scenario: Ordenação estável sem mutação
- **WHEN** as categorias chegam fora de ordem e duas possuem o mesmo total
- **THEN** os cards aparecem em ordem decrescente de total
- **AND** as categorias empatadas mantêm sua ordem relativa recebida
- **AND** a lista original e seus dados permanecem intactos

#### Scenario: Destaque na segunda página
- **WHEN** existem sete categorias visíveis
- **THEN** as três maiores aparecem na primeira página, as três seguintes na segunda e a última na terceira
- **AND** o primeiro card de cada página recebe o destaque relativo

### Requirement: Grade assimétrica por quantidade de itens

Cada página SHALL usar a composição correspondente à sua quantidade de itens:

- Um: card de destaque na largura toda.
- Dois: cards lado a lado com ilustrações em ambos, ocupando toda a altura da página e mantendo destaque tipográfico somente no primeiro.
- Três: destaque alto à esquerda e dois menores empilhados à direita.

Os cards ilustrados SHALL reservar espaço para sua ilustração. Os cards compactos da página de três SHALL apresentar seus dados sem área decorativa vazia. Todas as páginas SHALL compartilhar a mesma altura, com base mínima de 320 pixels e aumento conforme a maior necessidade de conteúdo entre páginas. O layout SHALL permitir aumento de altura e adaptação em telas estreitas ou texto ampliado para preservar a legibilidade.

#### Scenario: Página com três categorias
- **WHEN** uma página contém três categorias
- **THEN** a primeira ocupa o card alto à esquerda
- **AND** a segunda e a terceira ocupam, nessa ordem, os cards superior e inferior à direita

#### Scenario: Página com duas categorias
- **WHEN** uma página contém duas categorias
- **THEN** ambas ocupam uma coluna pela altura completa da página
- **AND** ambas exibem suas ilustrações no canto inferior direito

#### Scenario: Página com uma categoria
- **WHEN** uma página contém uma categoria
- **THEN** seu card ocupa a largura e altura completas da página, com ilustração no canto inferior direito

#### Scenario: Página incompleta
- **WHEN** a última página contém somente uma ou duas categorias
- **THEN** utiliza o layout de um ou dois itens, respectivamente
- **AND** não apresenta cards fictícios para completar três posições

#### Scenario: Altura uniforme durante navegação
- **WHEN** a pessoa navega de uma página com três categorias para uma página com uma ou duas
- **THEN** a altura da grade permanece igual, suficiente para os dados e ilustrações de todas as páginas
- **AND** texto ampliado pode aumentar essa altura para todas as páginas sem truncar dados

### Requirement: Carrossel horizontal de páginas

Mais de três categorias SHALL ser acessíveis por arraste horizontal entre páginas. A interface SHALL sinalizar discretamente a existência e a posição das páginas quando houver mais de uma. Uma única página SHALL dispensar indicador de paginação. Troca do mês ou substituição dos dados SHALL reiniciar o carrossel na primeira página. A rolagem horizontal SHALL coexistir com a rolagem vertical da Dashboard e respeitar a preferência de redução de animações.

#### Scenario: Acesso às categorias seguintes
- **WHEN** existem quatro categorias e a pessoa arrasta horizontalmente
- **THEN** acessa a segunda página com um card largo da quarta categoria e a mesma altura da primeira página
- **AND** o indicador identifica a página atual

#### Scenario: Troca do período
- **WHEN** a pessoa está em uma página posterior e muda o mês selecionado
- **THEN** o loading do novo mês substitui os dados anteriores
- **AND** o próximo resultado começa na primeira página

### Requirement: Identidade visual e conteúdo dos cards

Todos os cards SHALL exibir o ícone correspondente à categoria, seu nome, valor em BRL, badge de percentual no canto superior direito e o percentual seguido de “do total” abaixo do valor. Percentuais SHALL usar formatação pt-BR com uma casa decimal. O valor SHALL ter destaque tipográfico, maior no card de destaque do que nos secundários.

Os intervalos verticais entre nome e valor e entre valor e percentual SHALL ser iguais, de 8 pixels. Ilustrações SHALL preservar seu topo visível, mantendo o recorte decorativo na base e nos cantos arredondados do card.

O ícone SHALL reutilizar `BackgroundIconWidget`, o mesmo componente dos itens de despesa, em formato quadrado com cantos arredondados, cor da categoria e fundo dessa cor com opacidade de 12%. Cards e badges SHALL usar raios do tema existente. Fundo, borda, texto e detalhes SHALL respeitar os temas claro e escuro, com fundo e borda discretos derivados da cor da categoria e contraste adequado para os dados. A apresentação SHALL usar a tipografia existente e SHALL NOT copiar os círculos de ícone ou a paleta verde uniforme da referência.

#### Scenario: Card de destaque
- **WHEN** o primeiro item de uma página é renderizado
- **THEN** mostra ícone quadrado arredondado, badge, nome, valor em destaque e percentual do total
- **AND** mostra a ilustração ancorada no canto inferior direito, abaixo dos dados e sem sobrepor texto

#### Scenario: Card secundário
- **WHEN** um item que não é o primeiro de uma página com três categorias é renderizado
- **THEN** mostra os mesmos dados em composição compacta e sem ilustração
- **AND** usa a cor e o ícone correspondentes à sua categoria

### Requirement: Ilustrações e categorias desconhecidas

O destaque e ambos os cards de páginas duplas SHALL usar a ilustração existente de sua categoria em `assets/images/categories/`, preservando as cores originais e usando `ImageWidget`. A categoria `other` SHALL mapear para `others.webp`. Categorias desconhecidas SHALL preservar o nome recebido da API, usar ícone e cor neutros e a imagem `others.webp` como fallback quando ilustradas. As ilustrações SHALL ser decorativas para acessibilidade. A lista de assets SHALL ser registrada no Flutter.

#### Scenario: Categoria Outros
- **WHEN** a categoria `other` recebe destaque
- **THEN** seu rótulo é “Outros” e sua ilustração é `assets/images/categories/others.webp`

#### Scenario: Categoria futura
- **WHEN** a API retorna uma categoria desconhecida com gasto positivo
- **THEN** o card preserva seu nome e seus dados financeiros
- **AND** utiliza apresentação neutra e ilustração de fallback quando destacado

### Requirement: Estados da seção e acessibilidade

A seção SHALL preservar loading, falha com retry localizado no mês selecionado e total zero. O skeleton SHALL representar a grade de três cards, com destaque alto à esquerda e dois compactos à direita, usando a mesma altura-base adaptativa, excluindo dados fictícios da semântica e anunciando “Carregando métricas de despesas”. Total zero SHALL mostrar a mensagem de período sem despesas, sem cards fictícios. Total positivo sem categorias visíveis SHALL mostrar a mensagem de distribuição indisponível.

Cada card SHALL anunciar uma única descrição com nome, valor e percentual mensal, evitando anunciar o percentual duplicado do badge e do texto. Nome, valor e percentual SHALL permanecer legíveis com texto ampliado, sem truncamento de informação financeira. Nenhum teste Flutter automatizado de widgets, screens ou tema SHALL ser adicionado; a verificação dessas camadas SHALL usar previews e Maestro.

#### Scenario: Sem gastos
- **WHEN** o total mensal retornado é zero
- **THEN** a seção mostra o total formatado e a mensagem “Nenhuma despesa registrada neste período.”
- **AND** não cria cards nem ilustrações fictícias

#### Scenario: Distribuição indisponível
- **WHEN** o total é positivo e as categorias estão ausentes, vazias ou não contêm totais positivos
- **THEN** a seção mostra o total e “A distribuição por categoria não está disponível.”

#### Scenario: Falha e retry
- **WHEN** a consulta falha e a pessoa aciona “Tentar novamente”
- **THEN** somente a seção de Metrics consulta novamente o mês selecionado
- **AND** apresenta o skeleton de cards durante a consulta

#### Scenario: Leitor de tela e texto ampliado
- **WHEN** a pessoa usa leitor de tela ou amplia o texto
- **THEN** cada card anuncia categoria, valor e percentual uma única vez
- **AND** a composição adapta seu espaço para manter os dados legíveis

### Requirement: Substituição da dependência de gráfico

A implementação SHALL usar `flutter_staggered_grid_view` para compor as grades e SHALL remover `fl_chart`, o gráfico segmentado e seu estado de seleção. A mudança SHALL permanecer na apresentação e composição, preservando a integração HTTP, os contratos de domínio e os commands existentes.

#### Scenario: Dependências e fluxo financeiro preservados
- **WHEN** a substituição está implementada
- **THEN** a distribuição mensal usa a grade de cards e não depende de `fl_chart`
- **AND** a consulta permanece pelo command de Metrics e pelo contexto mensal existente da Dashboard
