## 1. Dependências e apresentação das categorias

- [x] 1.1 Adicionar `flutter_staggered_grid_view`, registrar `assets/images/categories/` e preparar a remoção de `fl_chart` no pubspec e lockfile.
- [x] 1.2 Atualizar a extensão de Metrics com ícones e cores correspondentes aos itens de despesa, assets por categoria, mapeamento `other` para `others.webp` e fallback neutro para categorias futuras.
- [x] 1.3 Implementar a preparação de apresentação: filtrar totais positivos, ordenar cópia com desempate estável e formar grupos de até três sem alterar as entidades.
- [x] 1.4 Atualizar ou adicionar testes de lógica pura para rótulos, ícones, assets, fallback, filtragem, ordenação estável e agrupamento, conforme os arquivos efetivamente alterados.

## 2. Cards e grade assimétrica

- [x] 2.1 Criar card público de Metrics com `BackgroundIconWidget`, cores das categorias, raios e tipografia existentes, valor em BRL e percentual pt-BR com uma casa decimal.
- [x] 2.2 Implementar badge no canto superior direito, texto percentual abaixo do valor e semântica única para evitar anúncios duplicados.
- [x] 2.3 Implementar ilustração decorativa com `ImageWidget` no destaque e em ambos os cards de páginas duplas, no canto inferior direito, sem tint e sem sobreposição dos dados.
- [x] 2.4 Criar grade com `StaggeredGrid.count` para um card largo, dois lado a lado ilustrados e três com destaque à esquerda, com altura uniforme entre todas as páginas.
- [x] 2.5 Adaptar altura e composição para nomes longos, valores grandes, largura estreita e texto ampliado sem truncar dados financeiros.

## 3. Carrossel e integração

- [x] 3.1 Criar carrossel horizontal para as grades com indicador discreto em múltiplas páginas e acesso a todas as categorias.
- [x] 3.2 Reiniciar a posição quando mês ou dados mudarem, respeitar redução de animações e descartar controllers/listeners quando utilizados.
- [x] 3.3 Integrar o carrossel em `MetricsSectionWidget`, preservando total mensal, retry localizado, mensagens de vazio e distribuição indisponível inclusive após filtragem.
- [x] 3.4 Atualizar skeleton para a composição de três cards e a mesma altura-base adaptativa, com placeholders excluídos da semântica e anúncio de loading existente.
- [x] 3.5 Remover o widget, o mixin e os imports do gráfico antigo e finalizar a remoção de `fl_chart`.

## 4. Documentação e validação

- [x] 4.1 Atualizar previews para 1, 2, 3, 4, 5, 6, 7, 8 e 10 categorias, empates, categorias futuras, estados da seção, claro/escuro e texto ampliado.
- [x] 4.2 Atualizar `ARCHITECTURE.md` para refletir cards, ordenação de apresentação, destaque relativo e carrossel.
- [x] 4.3 Executar `flutter pub get`, `flutter analyze` e `flutter test`, registrando qualquer falha e sua relação com a mudança.
- [ ] 4.4 Validar com Maestro composição, dados, scroll horizontal e vertical, indicador e reinício após troca de mês, sem criar testes Flutter de widgets/screens/tema.
- [ ] 4.5 Validar visualmente imagens, cores das categorias, raios, legibilidade e adaptação nos previews claro/escuro e texto ampliado.

## Registro de verificação

- `flutter pub get`: concluído; `fl_chart` removido do lockfile.
- `flutter analyze`: execução final sem erros ou warnings (`No issues found`), incluindo as correções presentes nos fluxos Dashboard e User.
- `flutter test`: execução final com 630 testes passando, incluindo limites de paginação, preparação das páginas e mapeamento de rótulos, ícones e assets.
- O erro de altura infinita foi reproduzido e corrigido fixando `axisDirection: AxisDirection.down` na grade, evitando herdar a orientação da rolagem horizontal.
- Houve inspeção dos previews claro/escuro, texto ampliado, valores extensos, estados vazio/indisponível e da navegação horizontal no navegador antes dos últimos ajustes. O simulador também expôs a terceira página real da Dashboard. A validação completa de 4.4 e a revisão visual final de 4.5 permanecem pendentes: o driver iOS retornou `Device became unreachable during deviceInfo`, e o navegador perdeu seu alvo CDP (`No CDP page target available`).
- Os ajustes finais incluem três cards por página, altura-base de 320 pixels ampliada pela maior necessidade entre todas as páginas, ambas as imagens em páginas duplas e skeleton de três itens. O recorte interno usa o raio do tema descontando a espessura da borda. A arte de 220 pixels ocupa uma área decorativa de 180 pixels no canto inferior direito, sem corte superior; os intervalos entre categoria, valor e percentual são de 8 pixels.
- Removido o padding extra de 8 pixels à direita das páginas. A medição e a renderização da grade usam a largura integral disponível da seção.
- Substituída a rolagem adaptada por `PageView.builder` e `PageController`, com encaixe nativo, indicador por `onPageChanged` e reinício imediato por `jumpToPage(0)`. O encaixe permanece ativo com redução de animações; a altura uniforme e a largura completa são preservadas.
