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

### 1. Grade de duas linhas com alturas compartilhadas

Compor `ExpenseMetricsGridWidget` com `Column`, `Row` e `Expanded`, sem rolagem própria. O carrossel fornece a rolagem horizontal e a Dashboard mantém a vertical. Todas as páginas possuem duas linhas: destaque ilustrado em largura total acima e secundários sem imagem abaixo.

Para três itens, os secundários dividem igualmente a largura inferior; para dois, o secundário ocupa a largura total, mantendo a altura dos secundários das páginas completas. Grupos de um ficam ocultos. O primeiro sempre recebe destaque tipográfico. Medir o conteúdo na largura real e compartilhar separadamente as maiores alturas superior e inferior entre todas as páginas, sem piso fixo e com espaçamento de 12 pixels entre linhas.

Em largura estreita ou escala de texto alta, aumentar as alturas medidas preservando o formato. Não resolver overflow escondendo nome ou valor com ellipsis ou reduzindo artificialmente a escala de texto.

### 2. Preparação de dados exclusiva da apresentação

Filtrar totais positivos e ordenar uma cópia por total decrescente com desempate pelo índice original. Separar em grupos consecutivos de até três e ocultar grupos de um. Cinco categorias produzem páginas de três e duas; quatro produzem somente uma de três. Essa transformação pertence à extensão de apresentação de Metrics; a entidade mantém sua ordem e conteúdo originais.

O primeiro de cada grupo recebe destaque relativo, inclusive na segunda página. Não aplicar thresholds nem usar percentuais para calcular geometria. O percentual exibido permanece o recebido da API e usa uma casa decimal pt-BR, como na referência.

### 3. Widgets próprios de Metrics, componentes básicos compartilhados

Criar widgets públicos com nomes e arquivos correspondentes para card, grade de página e carrossel em `metrics/presentation/widgets/`. A composição especial de texto, badge e ilustração justifica um card de feature em vez de forçar o layout horizontal de `IformationCardWidget`.

Reutilizar `BackgroundIconWidget`, `ImageWidget`, `IMoneyFormatter`, `context.colors`, `context.typography` e `context.radius`. A extensão existente de Metrics deve fornecer rótulo, ícone, cor e asset. Alinhar suas cores e ícones aos itens de despesa sem importar Expense, preservando o isolamento dos contextos e sem criar camada compartilhada apenas para esse mapeamento.

Badge e card usam raios do tema; ícones permanecem quadrados arredondados. Fundo e borda derivam da cor da categoria; textos usam papéis semânticos do tema. Somente o destaque possui imagem, ancorada pela base no canto inferior direito. A área reservada de 60 pixels permite overflow da arte de 220 pixels, ou 240 para Moradia, com deslocamento de 46 pixels na horizontal e 64 na vertical. O recorte ocorre no contorno do card. `Skeleton.ignore` preserva a ilustração sem shimmer durante loading. `other` aponta para `others.webp`; categoria futura usa rótulo original, tratamento neutro e o mesmo asset de fallback.

### 4. Carrossel, lifecycle e acessibilidade

Usar navegação horizontal com indicador discreto e reinício na troca do mês ou dados. Aplicar as maiores alturas por linha a todas as páginas. A altura total permanece constante ao deslizar, inclusive na página final com dois itens, sem cortar conteúdo nem deslocar as seções seguintes.

Usar `PageView.builder` com `PageController`. O viewport ocupa a largura da tela; a grade mede essa largura menos 40 pixels. `viewportFraction` de `(largura - 28) / largura` e padding lateral de 6 pixels por página garantem margens de 20 pixels no encaixe e separação de 12 pixels durante o arraste, como nos insights. `onPageChanged` fornece o índice; o reinício usa `jumpToPage(0)`. O mixin recria e descarta o controller quando a largura muda, preservando o índice. O encaixe nativo permanece ativo com redução de animações.

Se forem necessários controller, listeners e índice de página, usar widget stateful e mixin restrito ao widget conforme as convenções do projeto, descartando recursos e sem operações financeiras. Não adicionar gerenciamento global de estado. Manter semântica única por card e excluir ícone, badge duplicado e ilustração do anúncio. Respeitar redução de animações.

### 5. Integração e validação

`MetricsSectionWidget` preserva total, CommandBuilder, retry e mensagens. Ausência de categorias positivas produz distribuição indisponível com total positivo; uma única categoria positiva mantém somente o total. Skeleton acompanha as duas linhas de três cards, com placeholders sem semântica financeira e ilustração excluída do shimmer.

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

Nenhuma. O usuário aprovou as regras finais de duas linhas, páginas de duas ou três categorias, alturas compartilhadas por linha, margens iguais às dos insights e ilustração sem skeleton, e confirmou todas as validações como resolvidas em 2026-10-13.
