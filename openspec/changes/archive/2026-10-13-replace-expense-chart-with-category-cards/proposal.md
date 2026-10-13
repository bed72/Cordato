## Why

O gráfico segmentado atual dificulta comparar e identificar as categorias, pois apresenta detalhes de apenas uma seleção por vez. Cards ilustrados permitem ler nome, valor e participação de cada categoria e destacar visualmente os maiores gastos do mês.

## What Changes

- Substituir o gráfico por um carrossel horizontal de duas linhas com duas ou três categorias por página e alturas uniformes por linha entre páginas; grupos de uma categoria ficam ocultos.
- Mostrar somente categorias com gastos positivos, ordenadas por valor decrescente, com destaque relativo para a maior categoria de cada página.
- Apresentar ícone, nome, valor em BRL e percentual mensal em todos os cards; usar ilustração somente no destaque superior em largura total. Os secundários ficam lado a lado abaixo ou em largura total quando resta um secundário.
- Reutilizar o componente de ícone dos itens de despesa, as cores das categorias e os raios e tipografia do aplicativo.
- Usar as ilustrações existentes em `assets/images/categories/` e adaptar loading e previews.
- Compor as linhas com widgets de layout do Flutter e remover o gráfico antigo e sua seleção; preservar margens de 20 pixels e separação de 12 pixels entre páginas como nos insights.

## Capabilities

### New Capabilities

- `expense-category-metrics-cards`: apresentação da distribuição mensal em cards ilustrados, grades adaptativas e carrossel horizontal.

### Modified Capabilities

Nenhuma. O contexto mensal compartilhado da Dashboard permanece conforme o contrato existente.

## Impact

- Apresentação de Metrics e composição da seção na Dashboard, incluindo skeleton e previews.
- `pubspec.yaml`, lockfile e registro dos assets de categorias.
- Extensão de apresentação de categorias de Metrics e seus testes de lógica pura.
- `ARCHITECTURE.md`, para documentar a apresentação que substitui o gráfico.
- Sem alteração de endpoints, contratos de repository, entidades, commands ou persistência.
