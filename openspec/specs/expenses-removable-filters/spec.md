# expenses-removable-filters Specification

> Os requisitos de filtros permanecem; a implementação usa ExpensesBloc e
> navegação direta pelo contexto, sem callbacks nos argumentos da rota.
> Consulte [a referência vigente](../../README.md).

## Purpose
Definir filtros locais de categoria e período na listagem de despesas, com
pílulas removíveis, recarga consistente e ações acessíveis.

## Requirements
### Requirement: Cabeçalho fixo com filtros em pílulas

`ExpensesScreen` SHALL manter título “Despesas” e descrição “Acompanhe todas as suas despesas.” em todos os estados. SHALL mostrar abaixo da descrição uma pílula removível por filtro ativo, usando `InputChip` do Material adotado pelo app, com rótulo e ícone de fechar à direita. Categoria SHALL preceder período; as pílulas SHALL usar `Wrap`, cores e raios do tema e feedback de pressão do padrão compartilhado. O corpo da pílula SHALL NOT abrir seletor ou navegação.

#### Scenario: Categoria e mês na abertura
- **WHEN** a tela recebe categoria `housing` e intervalo de 2026-10-01 a 2026-10-31
- **THEN** mostra descrição fixa e pílulas “Moradia” e “Outubro de 2026”, nessa ordem, cada uma com ícone de fechar

#### Scenario: Entrada somente mensal
- **WHEN** “Ver tudo” abre a listagem com intervalo mensal e sem categoria
- **THEN** mostra descrição fixa e somente a pílula do mês e ano

#### Scenario: Entrada geral
- **WHEN** a tela não recebe categoria nem período
- **THEN** mostra descrição fixa e não reserva uma linha ou espaçamento adicional para filtros ausentes

#### Scenario: Categoria futura
- **WHEN** a entrada contém uma categoria sem rótulo conhecido pela apresentação
- **THEN** sua pílula preserva o identificador textual em vez de renomeá-la como uma categoria diferente

#### Scenario: Intervalo não mensal suportado pela rota
- **WHEN** o período inicial não representa um mês civil completo
- **THEN** uma única pílula identifica seus dois limites civis em pt-BR e sua remoção elimina ambos

#### Scenario: Tela estreita ou texto ampliado
- **WHEN** as duas pílulas não cabem lado a lado
- **THEN** a segunda quebra para a próxima linha sem overflow, truncamento dos rótulos ou redução indevida do alvo de toque

### Requirement: Filtros ativos pertencem ao estado local da listagem

A tela SHALL inicializar categoria e período ativos a partir dos argumentos existentes, antes da primeira consulta. Consultas, rótulos, vazio e pertencimento de itens SHALL usar os filtros ativos. Um rebuild comum SHALL NOT restaurar filtros removidos. Mudança efetiva das entradas SHALL iniciar a nova lente e invalidar operações anteriores; troca isolada do command de consulta SHALL preservar os filtros locais atuais.

#### Scenario: Rebuild após remoção
- **WHEN** o mês foi removido e a tela reconstrói após loading, refresh ou retorno da edição
- **THEN** o período permanece nulo e a pílula mensal não reaparece

#### Scenario: Troca de command sem troca das entradas
- **WHEN** a tela recebe outra instância do command com os mesmos parâmetros iniciais após remover um filtro
- **THEN** descarta corretamente a instância anterior e consulta com os filtros locais restantes

#### Scenario: Nova entrada efetiva
- **WHEN** a instância recebe categoria ou período inicial de valor diferente
- **THEN** aplica a nova combinação, reinicia a primeira página e impede respostas antigas de alterar o contexto novo

### Requirement: Remoção independente dos filtros

A ação de fechar SHALL remover somente o filtro da pílula acionada. A remoção do período SHALL limpar `from` e `to` juntos e permitir consultar todo o histórico. Remover ambos SHALL produzir consulta geral. A remoção SHALL NOT adicionar filtros alternativos, datas default ou valores vazios para representar ausência.

#### Scenario: Remover categoria mantendo mês
- **WHEN** a pessoa remove “Moradia” da combinação Moradia + Outubro de 2026
- **THEN** somente a pílula mensal permanece e a primeira consulta usa outubro com `category: null`

#### Scenario: Remover mês mantendo categoria
- **WHEN** a pessoa remove “Outubro de 2026” da combinação Moradia + Outubro de 2026
- **THEN** somente “Moradia” permanece e a consulta usa `housing` com `from: null` e `to: null`, abrangendo o histórico completo dessa categoria

#### Scenario: Remover último filtro de categoria
- **WHEN** a pessoa remove a categoria após já ter removido o mês
- **THEN** nenhuma pílula permanece e a consulta inicial não envia filtros de categoria ou período

#### Scenario: Remover último filtro mensal
- **WHEN** a pessoa remove o mês após já ter removido a categoria
- **THEN** nenhuma pílula permanece e a consulta inicial abrange todas as categorias em todo o histórico

### Requirement: Troca de lente reinicia consulta e rolagem

Ao remover um filtro disponível, a tela SHALL limpar os itens e a continuação anteriores, reiniciar feedback e estado de retry e voltar ao início da rolagem com o mesmo controller. SHALL consultar a primeira página de 20 itens com `pageLink: null`, manter filtros restantes visíveis e apresentar o skeleton inicial com anúncio “Carregando despesas”. SHALL NOT exibir dados da lente anterior sob a nova combinação.

#### Scenario: Remoção após várias páginas
- **WHEN** a pessoa está rolando resultados paginados e remove um filtro
- **THEN** a lista volta ao início, os resultados/cursor anteriores são descartados e somente páginas da nova consulta podem ser acumuladas

#### Scenario: Cursor contém o filtro removido
- **WHEN** a continuação anterior inclui `filter[category]` ou limites do período removido
- **THEN** a primeira consulta nova não usa essa continuação e não herda seus filtros

#### Scenario: Carregamento da nova lente
- **WHEN** a primeira página após remoção está rodando
- **THEN** o cabeçalho permanece fixo, os filtros restantes permanecem visíveis e o conteúdo mostra oito placeholders sem anunciar textos fictícios

### Requirement: Remoções são bloqueadas durante operações incompatíveis

Callbacks de remoção SHALL ficar desabilitados durante consulta inicial, paginação, refresh, retry, edição e confirmação ou execução de exclusão. Handlers SHALL verificar as mesmas condições e ignorar ações repetidas ou incompatíveis, sem enfileirar remoções para execução posterior.

#### Scenario: Toques rápidos nas duas pílulas
- **WHEN** a primeira remoção inicia uma consulta e a pessoa tenta remover o outro filtro imediatamente
- **THEN** apenas a primeira transição executa e a outra pílula fica desabilitada até a consulta terminar

#### Scenario: Confirmação de exclusão aberta
- **WHEN** existe uma exclusão pendente de confirmação
- **THEN** nenhuma remoção de filtro pode alterar os itens ou o contexto da operação

#### Scenario: Nova remoção após erro
- **WHEN** a consulta de uma nova lente falha e não há operação em andamento
- **THEN** a pílula restante volta a permitir remoção, iniciando outra primeira página quando acionada

### Requirement: Erros preservam a nova lente e distinguem troca de refresh

Falha na primeira página de uma troca de lente SHALL manter os filtros novos, lista vazia e continuação nula, com erro e “Tentar novamente”. Retry SHALL consultar a primeira página dessa lente sem restaurar filtros removidos. Refresh e paginação sem troca de lente SHALL preservar os itens já carregados em caso de erro e repetir a operação correspondente. Vazio SHALL refletir apenas os filtros ativos.

#### Scenario: Falha após remover mês
- **WHEN** a consulta do histórico de Moradia falha depois de remover o mês
- **THEN** a pílula “Moradia” permanece, o mês não retorna e retry usa `housing` com limites nulos e continuação nula

#### Scenario: Paginação falha no histórico filtrado
- **WHEN** a consulta da próxima página de Moradia sem mês falha
- **THEN** mantém os itens anteriores e repete a mesma continuação com categoria ativa e limites nulos

#### Scenario: Refresh falha sem troca de lente
- **WHEN** um refresh da combinação atualmente ativa falha
- **THEN** preserva os itens existentes dessa combinação e a próxima tentativa permanece na mesma lente

#### Scenario: Vazio após remoção de categoria
- **WHEN** a consulta mensal sem categoria retorna lista vazia
- **THEN** o vazio identifica o período atual sem mencionar a categoria removida

#### Scenario: Vazio sem filtros
- **WHEN** ambos os filtros foram removidos e a consulta geral retorna lista vazia
- **THEN** apresenta mensagem geral sem categoria ou mês e mantém a descrição fixa

### Requirement: Respostas obsoletas não alteram estado atual

A listagem SHALL ignorar resultados, finalizações e callbacks agendados de operações que não pertencem mais ao command e à revisão de consulta ativos. Após descarte SHALL NOT executar `setState`, aplicar itens ou iniciar outras páginas. A proteção SHALL cobrir troca de entradas e dependências, incluindo finalizações que poderiam alterar flags de loading de uma consulta nova.

#### Scenario: Resposta tardia da instância anterior
- **WHEN** o command foi substituído e sua consulta antiga termina depois da consulta nova começar
- **THEN** a resposta e sua finalização não modificam itens, filtros, continuação, erro ou loading do command atual

#### Scenario: Carregamento automático agendado antes da troca
- **WHEN** um callback post-frame de paginação antiga executa após a lente ser reiniciada
- **THEN** ele não solicita a continuação antiga nem inicia consultas pela revisão anterior

#### Scenario: Fechar durante consulta
- **WHEN** a tela é descartada antes da resposta
- **THEN** descarta recursos próprios e não aplica a resposta nem agenda mais páginas

### Requirement: Remoção acessível sem exclusão semântica das pílulas

Cada pílula SHALL expor rótulo e ação de remoção localizada para leitores de tela, com alvo de toque acessível. As pílulas SHALL permanecer fora da exclusão semântica do header textual. O estado desabilitado SHALL impedir a ação de remoção também por acessibilidade. O layout SHALL preservar rótulos e contraste nos temas claro e escuro.

#### Scenario: Remoção de categoria por acessibilidade
- **WHEN** a pessoa aciona “Remover filtro de categoria: Moradia”
- **THEN** executa a mesma transição do ícone de fechar e mantém o período ativo

#### Scenario: Remoção de mês por acessibilidade
- **WHEN** a pessoa aciona “Remover filtro de período: Outubro de 2026”
- **THEN** remove ambos os limites civis e mantém a categoria ativa

#### Scenario: Estado desabilitado acessível
- **WHEN** a consulta está em andamento e uma pílula restante é inspecionada por leitor de tela
- **THEN** seu rótulo continua disponível sem uma ação executável de remoção

### Requirement: Alterar lentes não altera dados ou contexto da Dashboard

Remover filtros SHALL ser uma interação local de consulta: SHALL NOT chamar `onExpensesChanged`, alterar o mês selecionado da Dashboard ou persistir filtros. O retorno após edição/exclusão confirmada SHALL manter o sinal financeiro e a recarga existentes. Reabrir a listagem pela Dashboard SHALL inicializar novamente a combinação enviada nessa abertura.

#### Scenario: Voltar após apenas remover filtros
- **WHEN** a pessoa abriu Moradia em outubro, removeu filtros e voltou sem editar ou excluir despesas
- **THEN** a Dashboard permanece em outubro e não inicia recarga financeira por causa dessas remoções

#### Scenario: Voltar após exclusão no histórico
- **WHEN** a pessoa removeu o mês, confirmou uma exclusão e voltou
- **THEN** o callback financeiro existente sinaliza a alteração e a Dashboard recarrega no seu contexto preservado

#### Scenario: Reabrir pelo mesmo card
- **WHEN** após fechar a listagem a pessoa toca novamente o card Moradia na Dashboard de outubro
- **THEN** a nova abertura inicia com Moradia + Outubro de 2026, sem recuperar o estado removido da abertura anterior
