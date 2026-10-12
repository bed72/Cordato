## Context

A Dashboard consulta Metrics por mês e apresenta o total e `ExpenseMetricsChartWidget`. Esse widget usa `fl_chart`, barra empilhada e um mixin de seleção local. A API já retorna categoria textual, total em centavos e percentual; não é necessário alterar a consulta.

Há 18 ilustrações WebP em `assets/images/categories/`, ainda não registradas no `pubspec.yaml`. Os itens de despesa usam `BackgroundIconWidget` com cantos arredondados, cor da categoria e fundo a 12%. Metrics já possui uma extensão de rótulos e cores, mas suas cores divergem das usadas nos itens de despesa.

## Goals / Non-Goals

**Goals:**
- Substituir o gráfico por cards seguindo a referência visual e a identidade do app.
- Oferecer destaque relativo, ordenação estável e navegação horizontal em grupos de até três, com altura uniforme entre páginas.
- Preservar dados financeiros, estados da seção, contexto mensal e acessibilidade.

**Non-Goals:**
- Alterar API, entities, repositories, filtros, commands ou persistência.
- Calcular percentuais, agregar categorias em “Outros” ou vincular cards à listagem.
- Representar área exata proporcional ao gasto ou incluir logos de serviços mostrados na referência.

## Decisions

### 1. Grade pequena por página com `StaggeredGrid.count`

Adicionar `flutter_staggered_grid_view` na versão estável compatível e utilizar `StaggeredGrid.count` com duas colunas. O componente é indicado para poucos itens e não possui rolagem própria; o carrossel fornece a rolagem horizontal e a Dashboard mantém a vertical. `MasonryGridView` não oferece a composição de destaque ocupando duas alturas de forma tão explícita.

Usar tiles com extensão ajustável para reservar altura conforme largura disponível e tamanho do texto. Para três itens, o primeiro ocupa a coluna esquerda pela altura de dois secundários mais o espaçamento; os demais ficam à direita. Para um, o destaque ocupa as duas colunas; para dois, cada card ocupa uma coluna e ambos mostram suas ilustrações. Não há linha inferior. O primeiro sempre recebe destaque tipográfico, inclusive quando os totais empatam. A altura-base é de 320 pixels, aumentada conforme o conteúdo, e todas as páginas recebem a maior altura necessária entre elas.

Em largura estreita ou escala de texto alta, aumentar a altura e adaptar a composição, podendo apresentar uma coluna quando necessário. Não resolver overflow escondendo nome ou valor com ellipsis ou reduzindo artificialmente a escala de texto.

### 2. Preparação de dados exclusiva da apresentação

Filtrar totais positivos e ordenar uma cópia por total decrescente com desempate pelo índice original. Separar em grupos consecutivos de três. Essa transformação pertence à apresentação de Metrics; a entidade mantém sua ordem e conteúdo originais. Preferir mixin específico de lógica sem estado se necessário para manter o build curto.

O primeiro de cada grupo recebe destaque relativo, inclusive na segunda página. Não aplicar thresholds nem usar percentuais para calcular geometria. O percentual exibido permanece o recebido da API e usa uma casa decimal pt-BR, como na referência.

### 3. Widgets próprios de Metrics, componentes básicos compartilhados

Criar widgets públicos com nomes e arquivos correspondentes para card, grade de página e carrossel em `metrics/presentation/widgets/`. A composição especial de texto, badge e ilustração justifica um card de feature em vez de forçar o layout horizontal de `IformationCardWidget`.

Reutilizar `BackgroundIconWidget`, `ImageWidget`, `IMoneyFormatter`, `context.colors`, `context.typography` e `context.radius`. A extensão existente de Metrics deve fornecer rótulo, ícone, cor e asset. Alinhar suas cores e ícones aos itens de despesa sem importar Expense, preservando o isolamento dos contextos e sem criar camada compartilhada apenas para esse mapeamento.

Badge e card usam raios do tema; ícones permanecem quadrados arredondados. Fundo e borda derivam da cor da categoria com intensidade discreta; textos usam papéis semânticos do tema. Imagens mantêm suas cores, sem tint, e aparecem ancoradas no canto inferior direito no destaque e em ambos os cards de páginas duplas, sem padding do bloco textual. A área decorativa de 180 pixels acomoda a arte de 220 pixels e as margens transparentes dos WebPs, preservando o topo, respeitando os cantos do card e sem sobrepor dados. `other` aponta para `others.webp`; categoria futura usa rótulo original, tratamento neutro e o mesmo asset de fallback.

### 4. Carrossel, lifecycle e acessibilidade

Usar navegação horizontal com páginas identificáveis, indicador discreto quando necessário e posição reiniciada na troca do mês ou dados. Calcular a altura necessária de cada grade com base na largura disponível, conteúdo e escala de texto, e aplicar a maior altura a todas as páginas. Em duas categorias, ambos os cards ocupam a altura completa; em uma, o card largo também ocupa essa altura. A altura permanece constante ao navegar horizontalmente, sem cortar conteúdo nas páginas seguintes.

Usar `PageView.builder` com `PageController`, altura explícita calculada pelo conteúdo e largura completa por página. `onPageChanged` fornece o índice do indicador. O reinício usa `jumpToPage(0)`, sem animação programática; não desativar o encaixe nativo do gesto quando houver redução de animações. Isso evita posições intermediárias permanentes e substitui o cálculo manual de offset do `SingleChildScrollView`.

Se forem necessários controller, listeners e índice de página, usar widget stateful e mixin restrito ao widget conforme as convenções do projeto, descartando recursos e sem operações financeiras. Não adicionar gerenciamento global de estado. Manter semântica única por card e excluir ícone, badge duplicado e ilustração do anúncio. Respeitar redução de animações.

### 5. Integração e validação

`MetricsSectionWidget` troca a composição de gráfico por carrossel, preservando total, CommandBuilder, retry e mensagens. Filtragem sem categorias visíveis deve produzir distribuição indisponível quando o total for positivo. Skeleton deve acompanhar a grade de três cards e a mesma altura-base adaptativa, reutilizando componentes reais com placeholders sem semântica financeira.

Atualizar previews para 1, 2, 3, 4, 5, 6, 7, 8 e 10 categorias, empate, zero, desconhecidas, loading, erro, nomes e valores extensos, temas e texto ampliado. Validar visualmente e com Maestro; testes unitários cobrem apenas lógica pura alterada. Remover dependência, widget e mixin antigos e documentar a nova apresentação em `ARCHITECTURE.md`.

## Risks / Trade-offs

- [Texto longo em meia largura] → Ajustar altura e composição conforme conteúdo e escala de texto; validar valores grandes e categorias com rótulos extensos.
- [Destaque relativo confundido com área proporcional] → Sempre mostrar percentual explícito; documentar que a hierarquia é relativa por página.
- [Ilustrações verdes junto a cores variadas] → Preservar imagens originais e manter fundo discretamente colorido, validando contraste em ambos os temas.
- [Alturas diferentes entre páginas] → Dimensionar o carrossel para não cortar conteúdo e validar páginas incompletas e texto ampliado.
- [Mapeamentos em contextos distintos divergirem] → Verificar ícones e cores contra a extensão de Expense durante implementação, sem dependência entre contextos.

## Migration Plan

Trocar dependências e registrar assets; implementar componentes e integração; remover apresentação antiga; atualizar previews e documentação; executar `flutter pub get`, `flutter analyze`, `flutter test` e verificação Maestro. Não há migração de dados. Reversão consiste em restaurar a composição e dependência anteriores, sem afetar dados financeiros.

## Open Questions

Nenhuma bloqueante. O ajuste final solicitado durante implementação reduz a página para três itens, mantém altura uniforme entre páginas e ilustra os dois cards em páginas duplas. O critério de adaptação para largura/texto deve ser refinado pela validação visual, preservando todos os dados.
