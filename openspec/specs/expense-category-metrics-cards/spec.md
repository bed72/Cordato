# Expense Category Metrics Cards

> Consulte [a precedência atual](../../README.md). Cards com período civil
> navegam diretamente pelo BuildContext; callbacks de composição visual não são
> transportados nos argumentos da rota.

## Purpose

Definir a apresentação da distribuição mensal de despesas da Dashboard em cards informativos de categorias, com destaque ilustrado, grade de duas linhas e carrossel horizontal, preservando os dados financeiros da API e a acessibilidade.
## Requirements
### Requirement: Distribuição mensal em cards de categorias

A seção de Metrics SHALL substituir o gráfico segmentado por cards das categorias com `totalAmount > 0` no mês selecionado na Dashboard. A apresentação SHALL manter o total mensal acima dos cards, formatar valores em centavos pelo `IMoneyFormatter` e preservar o percentual fornecido pela API, sem recalcular agregações ou alterar as entidades recebidas. Cards com período civil SHALL abrir a listagem filtrada por período e categoria; sem período SHALL permanecer informativos e sem navegação.

#### Scenario: Retorno da listagem por categoria
- **WHEN** a pessoa abre despesas por um card com período e retorna à mesma composição montada
- **THEN** os argumentos da rota contêm somente período e categoria, sem callbacks
- **AND** Metrics notifica seu consumidor local para recarregar, mesmo sem alterações na listagem

#### Scenario: Categorias em uso no mês
- **WHEN** a consulta do mês retorna categorias com totais positivos e zero
- **THEN** somente as categorias com totais positivos aparecem como cards
- **AND** o total mensal permanece o valor fornecido pela API

#### Scenario: Percentual relativo ao mês
- **WHEN** uma categoria aparece em qualquer página do carrossel
- **THEN** seu percentual corresponde ao valor recebido da API para o total mensal
- **AND** não é recalculado em relação às categorias daquela página

### Requirement: Ordenação e destaque relativo

A apresentação SHALL ordenar uma cópia das categorias positivas por `totalAmount` decrescente, preservando a ordem original entre empates. SHALL dividir essa sequência em grupos consecutivos de até três itens e ocultar grupos de um, inclusive a sobra final. O primeiro item de cada grupo apresentado SHALL receber o destaque visual e a ilustração, independentemente de faixas de percentual. Os demais cards SHALL permanecer sem ilustração. A área dos cards SHALL seguir o padrão de composição, sem promessa de proporcionalidade exata aos gastos.

#### Scenario: Ordenação estável sem mutação
- **WHEN** as categorias chegam fora de ordem e duas possuem o mesmo total
- **THEN** os cards aparecem em ordem decrescente de total
- **AND** as categorias empatadas mantêm sua ordem relativa recebida
- **AND** a lista original e seus dados permanecem intactos

#### Scenario: Destaque na segunda página
- **WHEN** existem sete categorias visíveis
- **THEN** as três maiores aparecem na primeira página e as três seguintes na segunda
- **AND** a sobra de uma categoria não produz uma terceira página
- **AND** o primeiro card de cada página recebe o destaque relativo

### Requirement: Grade assimétrica por quantidade de itens

Cada página SHALL usar a composição correspondente à sua quantidade de itens:

- Um: não apresentar a página.
- Dois: destaque ilustrado em largura total acima e card secundário sem ilustração em largura total abaixo.
- Três: destaque ilustrado em largura total acima e dois secundários sem ilustração lado a lado abaixo.

O destaque SHALL reservar 60 pixels para sua ilustração, sem reduzir o tamanho da arte. Os cards secundários SHALL apresentar seus dados sem área decorativa vazia. Todas as páginas SHALL compartilhar alturas por linha: a maior altura necessária entre os destaques e, separadamente, a maior entre os secundários, medidos em suas larguras reais com a escala de texto vigente. A altura total SHALL ser a soma dessas duas alturas e 12 pixels de espaçamento, sem piso fixo. Texto ampliado SHALL aumentar as alturas compartilhadas sem truncar dados nem alterar o formato de duas linhas.

#### Scenario: Página com três categorias
- **WHEN** uma página contém três categorias
- **THEN** a primeira ocupa toda a largura na linha superior
- **AND** a segunda e a terceira ocupam, nessa ordem, os cards esquerdo e direito da linha inferior

#### Scenario: Largura alinhada à Dashboard
- **WHEN** a grade é exibida em uma ou mais páginas
- **THEN** os cards possuem margens laterais de 20 pixels quando a página encaixa
- **AND** há separação de 12 pixels entre páginas durante o arraste, como nos insights
- **AND** os limites esquerdo e direito ficam alinhados aos demais widgets da Dashboard

#### Scenario: Página com duas categorias
- **WHEN** uma página contém duas categorias
- **THEN** ambas ocupam toda a largura, uma acima da outra
- **AND** somente a superior exibe ilustração, e a inferior mantém a altura dos secundários das demais páginas

#### Scenario: Página com uma categoria
- **WHEN** uma página contém uma categoria
- **THEN** essa página não é apresentada
- **AND** se só existe uma categoria positiva, apenas o total permanece visível

#### Scenario: Página incompleta
- **WHEN** a última página contém somente uma ou duas categorias
- **THEN** oculta a sobra de um ou apresenta o layout de dois itens, respectivamente
- **AND** não apresenta cards fictícios para completar três posições

#### Scenario: Altura uniforme durante navegação
- **WHEN** a pessoa navega de uma página com três categorias para uma página com duas
- **THEN** a altura da grade permanece igual, suficiente para os dados e ilustrações de todas as páginas
- **AND** texto ampliado pode aumentar essa altura para todas as páginas sem truncar dados

#### Scenario: Encaixe ao finalizar o arraste
- **WHEN** a pessoa termina um arraste horizontal, inclusive com redução de animações habilitada
- **THEN** a paginação encaixa uma página completa na largura disponível
- **AND** a página atual fica alinhada às margens, permitindo uma pequena prévia da página vizinha como nos insights
- **AND** o indicador acompanha o índice informado pela paginação nativa

### Requirement: Carrossel horizontal de páginas

Grupos apresentados após os três primeiros itens SHALL ser acessíveis por arraste horizontal entre páginas usando `PageView` com encaixe nativo. A interface SHALL sinalizar discretamente a existência e a posição das páginas quando houver mais de uma. Uma única página SHALL dispensar indicador de paginação. Troca do mês ou substituição dos dados SHALL reiniciar o carrossel na primeira página. A rolagem horizontal SHALL coexistir com a rolagem vertical da Dashboard e respeitar a preferência de redução de animações.

#### Scenario: Acesso às categorias seguintes
- **WHEN** existem cinco categorias e a pessoa arrasta horizontalmente
- **THEN** acessa a segunda página com a quarta e quinta categorias empilhadas e a mesma altura total da primeira página
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

Somente o destaque de cada página SHALL usar a ilustração existente de sua categoria em `assets/images/categories/`, preservando as cores originais e usando `ImageWidget`. A arte SHALL medir 220 pixels, ou 240 para Moradia, alinhada pela base com recorte somente no contorno do card. A categoria `other` SHALL mapear para `others.webp`. Categorias desconhecidas SHALL preservar o nome recebido da API, usar ícone e cor neutros e a imagem `others.webp` como fallback quando ilustradas. As ilustrações SHALL ser decorativas para acessibilidade. A lista de assets SHALL ser registrada no Flutter.

#### Scenario: Categoria Outros
- **WHEN** a categoria `other` recebe destaque
- **THEN** seu rótulo é “Outros” e sua ilustração é `assets/images/categories/others.webp`

#### Scenario: Categoria futura
- **WHEN** a API retorna uma categoria desconhecida com gasto positivo
- **THEN** o card preserva seu nome e seus dados financeiros
- **AND** utiliza apresentação neutra e ilustração de fallback quando destacado

### Requirement: Estados da seção e acessibilidade

A seção SHALL preservar loading e total zero. Na Dashboard, falha de Metrics SHALL acionar a tela de erro financeiro global em vez de apresentar falha ou retry localizado da seção. A ação global SHALL recarregar as três seções no contexto mensal preservado, mantendo a tela de erro durante a recuperação. O skeleton SHALL representar a grade de três cards, com destaque em largura total acima e dois compactos lado a lado abaixo, usando altura medida pelo conteúdo, excluindo dados fictícios da semântica e anunciando “Carregando métricas de despesas”. A ilustração SHALL permanecer visível sem efeito de skeleton por `Skeleton.ignore`. Total zero SHALL mostrar a mensagem de período sem despesas, sem cards fictícios. Total positivo sem categorias positivas SHALL mostrar a mensagem de distribuição indisponível. Uma única categoria positiva SHALL manter somente o total, sem carrossel ou mensagem de distribuição indisponível.

Cada card SHALL anunciar uma única descrição com nome, valor e percentual mensal, evitando anunciar o percentual duplicado do badge e do texto. Nome, valor e percentual SHALL permanecer legíveis com texto ampliado, sem truncamento de informação financeira. Nenhum teste Flutter automatizado de widgets, screens ou tema SHALL ser adicionado; a verificação dessas camadas SHALL usar previews e Maestro.

#### Scenario: Sem gastos
- **WHEN** o total mensal retornado é zero
- **THEN** a seção mostra o total formatado e a mensagem “Nenhuma despesa registrada neste período.”
- **AND** não cria cards nem ilustrações fictícias

#### Scenario: Distribuição indisponível
- **WHEN** o total é positivo e as categorias estão ausentes, vazias ou não contêm totais positivos
- **THEN** a seção mostra o total e “A distribuição por categoria não está disponível.”

#### Scenario: Falha e retry
- **WHEN** Metrics falha e a pessoa aciona “Tentar novamente” na tela de erro global
- **THEN** a Dashboard coordena a recarga de Metrics, Insights e despesas recentes no mês efetivo da recuperação
- **AND** a tela de erro continua visível com loading no botão em vez do skeleton localizado de Metrics

#### Scenario: Leitor de tela e texto ampliado
- **WHEN** a pessoa usa leitor de tela ou amplia o texto
- **THEN** cada card anuncia categoria, valor e percentual uma única vez
- **AND** a composição adapta seu espaço para manter os dados legíveis

### Requirement: Substituição da dependência de gráfico

A implementação SHALL compor as duas linhas com `Column`, `Row` e `Expanded` e SHALL remover o gráfico segmentado e seu estado de seleção, sem dependência de `fl_chart` na apresentação. A mudança SHALL permanecer na apresentação e composição, preservando a integração HTTP, os tipos de domínio, os contratos de aplicação e a coordenação por Bloc, sem reintroduzir commands.

#### Scenario: Dependências e fluxo financeiro preservados
- **WHEN** a substituição está implementada
- **THEN** a distribuição mensal usa a grade de cards e não depende de `fl_chart`
- **AND** a consulta permanece pelo command de Metrics e pelo contexto mensal existente da Dashboard
