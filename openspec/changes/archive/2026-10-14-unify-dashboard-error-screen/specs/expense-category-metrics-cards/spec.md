## MODIFIED Requirements

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
