## Context

`ExpensesScreen` já recebe `category` e `period` opcionais, além dos commands e callbacks de navegação. `ExpensesScreenStateMixin` consulta esses campos diretamente em `_loadPage`, `monthLabel`, `filterLabel`, `_isWithinPeriod` e `_applyUpdatedExpense`. O estado acumula páginas de 20 itens, preserva itens em falhas de refresh/paginação e mantém um `ScrollController` próprio.

A Dashboard já abre `/expenses` com seu mês selecionado e, ao tocar um card, acrescenta a categoria. A rota aceita records com e sem categoria e callback. `GetExpensesCommand`, repository e data source já delegam categoria e limites civis; filtros explícitos prevalecem sobre os do link. Sem filtros explícitos, o data source preserva os filtros herdados da continuação.

Atualmente o cabeçalho varia a descrição para informar mês/categoria. O usuário confirmou descrição fixa e remoção independente: remover mês consulta todo o histórico; remover categoria mantém o mês; remover ambos consulta o histórico geral.

Referência visual: `/Users/gabrielramos/Code/Me/Mobile/Flutter/Trocado/lib/src/presentation/ui/expenses/widgets/filter/expenses_filter_choice_chip_widget.dart`. O arquivo usa `ChoiceChip`, cores semânticas e fundo suave. Não será importado nem copiado como dependência.

## Goals / Non-Goals

**Goals:**

- Apresentar as lentes em pílulas removíveis abaixo da descrição fixa.
- Reutilizar a listagem, consulta e navegação atuais.
- Tornar filtros estado local e preservar consistência de resultados, paginação, mensagens e mutações.
- Manter operação acessível, layout responsivo e descarte correto.
- Definir explicitamente falha, loading, retorno de navegação e respostas obsoletas.

**Non-Goals:**

- Adicionar seletor para novos filtros, reativar pílulas removidas, multisseleção, botão “Limpar todos” ou filtros persistidos.
- Alterar Dashboard, carrossel, seleção mensal de origem, formato dos records da rota ou contratos HTTP.
- Criar store global, novo gerenciador de estado, camada de domínio para filtros visuais ou nova dependência.
- Filtrar localmente uma página geral para simular a consulta da API.

## Decisions

### 1. InputChip na feature Expense

Criar `ExpensesFiltersWidget`, público, `final`, com primary constructor `const`, em `expense/presentation/screens/expenses/widgets/expenses_filters_widget.dart`. O widget recebe rótulos opcionais e callbacks anuláveis de remoção. Não mantém estado nem conhece commands, API ou router.

Usar `InputChip` via `material_ui`, com `deleteIcon` de fechar à direita e `onDeleted`. É o componente Material para itens removíveis; `ChoiceChip` exigiria montar uma interação de exclusão adicional. Não usar o corpo da pílula para abrir seletor ou navegar. Reutilizar `BounceWidget` para o feedback de pressão conforme o padrão do projeto, preservando `onDeleted` como ação de remoção e sem tornar o corpo uma segunda ação.

Compor `Wrap` alinhado ao início, com `spacing` e `runSpacing` de 8 pixels. Inserir 12 pixels entre descrição e filtros somente quando houver filtros. Ordem estável: categoria, período. Sem filtros, não renderizar pílulas, placeholder ou espaço vertical adicional. O bloco pertence ao cabeçalho da mesma lista lazy; rola com o conteúdo, sem segundo scroll.

O visual adapta a referência: fundo suave baseado em `primary` com alpha 0.15, texto e ícone semânticos, tipografia de label e formato de pílula pelo raio `cornerRadiusFull` existente. Não reutilizar o widget de percentual dos cards: aquele badge é informativo e não tem alvo de remoção. Preservar alvo de toque Material acessível; evitar compactar o hit target apenas para reproduzir o badge. Validar contraste em claro/escuro e quebra de linha com escala de texto ampliada. Não truncar rótulos de mês, ano ou categoria.

### 2. Fonte única: filtros ativos locais

Adicionar `activeCategory` (`String?`) e `activePeriod` (`({DateTime from, DateTime to})?`) ao mixin, inicializados por `widget.category`/`widget.period` antes da primeira consulta. Esses parâmetros continuam sendo entradas imutáveis, sem alterar o construtor público nem a rota.

Todos os consumidores de filtros passam a usar os membros ativos: construção dos rótulos, consulta, paginação, retry, refresh, vazio e aplicação da entidade retornada da edição. O mês atual do relógio não é usado para reconstruir um filtro removido.

Um rebuild comum não reintroduz filtros. Substituição do command de consulta reinicia a consulta com os filtros locais atuais. Uma mudança real nos valores de entrada da tela reaplica os novos filtros iniciais, reinicia a lente e invalida operações antigas; comparar valores de `category` e `period`, não apenas identidade do widget. A chave já existente da rota continua podendo criar outra instância para outra combinação inicial.

Rótulos conhecidos usam `ExpenseCategoryExtension`; categoria desconhecida preserva a string, sem transformar silenciosamente em “Outros”. Período mensal completo usa o formatter existente para “Outubro de 2026”, incluindo ano. Caso uma entrada suportada informe intervalo não mensal, a mesma pílula identifica os dois limites civis, sem fingir que corresponde ao mês inteiro. A remoção sempre limpa ambos os limites de uma vez.

### 3. Remoção é uma troca de lente, não um refresh comum

O handler valida que o filtro existe e que não há consulta, edição ou exclusão em andamento. A troca então:

1. Remove somente o filtro solicitado.
2. Invalida a revisão anterior da consulta.
3. Limpa `expenses`, `nextPageLink`, `hasLoaded`, `hasFailure` e configura retry para primeira página.
4. Reposiciona o controller para o início, verificando `hasClients` e o lifecycle; a instância do controller é preservada.
5. Consulta `pageSize: 20`, `pageLink: null`, com os filtros ativos restantes.
6. Mantém cabeçalho e pílulas restantes visíveis e mostra skeleton inicial de oito itens, com anúncio “Carregando despesas”.

Não reaproveitar continuação anterior. Essa regra é essencial: o data source preserva filtros presentes em links quando os parâmetros explícitos são nulos. Limpar a continuação garante que remover mês/categoria realmente elimina a lente da primeira requisição e das páginas seguintes.

Não reutilizar a preservação de itens do refresh para essa transição: resultados antigos não podem aparecer sob filtros novos. Depois da primeira página, a paginação segue o comportamento existente, com skeleton de rodapé e continuação opaca.

Tabela de consulta após remover um filtro:

| Estado anterior | Remoção | Próxima primeira página |
| --- | --- | --- |
| Categoria + mês | Categoria | `from`/`to` ativos, `category: null`, `pageLink: null` |
| Categoria + mês | Mês | `category` ativa, `from: null`, `to: null`, `pageLink: null` |
| Apenas categoria | Categoria | Todos os filtros nulos e `pageLink: null` |
| Apenas mês | Mês | Todos os filtros nulos e `pageLink: null` |

Não enviar string vazia, data default, `filter[year]`, `filter[month]` ou `filter[day]` para representar remoção.

### 4. Serialização das interações e invalidação assíncrona

Usar um getter de disponibilidade no mixin para desabilitar os callbacks das pílulas quando houver `isLoading`, command de consulta rodando, `isEditingExpense`, `pendingDeleteId`, `deletingExpenseId` ou command de exclusão rodando. Os handlers verificam as mesmas condições para proteger toques repetidos e ações acessíveis.

Não cancelar a requisição HTTP nem agendar uma segunda remoção durante loading. A pílula restante fica desabilitada até a consulta atual terminar; após erro, fica novamente disponível.

Adicionar um contador local de revisão de consulta se necessário para capturar conjuntamente a identidade do command e a lente. Invalidação cobre mudança das entradas, troca de dependências e descarte. Toda aplicação de resposta, alteração de flags em `finally` e callback post-frame de carregamento automático verifica se ainda pertence à revisão/command ativos e se o estado está montado. Um `finally` antigo não pode desligar o loading de uma consulta nova.

Reutilizar o lifecycle do mixin; não criar subscriptions se os flags e builds existentes bastarem. Se uma subscription for necessária, remover antes de substituir dependências e no descarte.

Se entradas realmente mudarem enquanto o mesmo command ainda executa, invalidar a lente antiga e aguardar essa execução terminar antes de iniciar a primeira página da entrada nova, respeitando o bloqueio de concorrência do `command_it`. Essa recarga de reconfiguração deve executar uma única vez e ser descartada se houver nova substituição ou desmontagem. Isso não enfileira remoções de pílulas: essas continuam bloqueadas durante consultas.

### 5. Falhas e retries

Se a primeira consulta após remoção falhar, manter os filtros novos, lista vazia e continuação nula. Mostrar o erro existente com “Tentar novamente”; não desfazer a remoção nem restaurar dados antigos. Retry repete a primeira página dos filtros atuais. A pessoa também pode remover a outra pílula após a falha.

Refresh sem troca de lente continua preservando itens até sucesso. Falha de página seguinte preserva os itens e o cursor daquela lente; retry repete a página que falhou. Os três caminhos compartilham os filtros ativos, mas apenas troca de lente limpa itens antes de consultar.

O vazio usa as lentes atuais: categoria/período quando presentes e mensagem geral quando ambos ausentes. O texto não pode citar filtros removidos. O título e a descrição do cabeçalho permanecem fixos em loading, erro, vazio e sucesso.

### 6. Navegação, edição e semântica

Remover filtro não chama `onExpensesChanged`, não altera argumentos da Dashboard e não modifica dados financeiros. Voltar após somente remoções mantém a Dashboard no mês original, sem recarga financeira. Edições/exclusões confirmadas continuam chamando o callback e seguem o fluxo de recarga existente.

Ao retornar da edição, validar a despesa pelos filtros ativos, não pelos iniciais. Após remover mês, outra data mensal continua pertencendo à consulta. Após remover categoria, outra categoria continua pertencendo à consulta. Exclusão e reposicionamento preservam paginação, rolagem e agrupamentos dentro da lente ativa.

O `Semantics(excludeSemantics: true)` atual do header não pode envolver as pílulas: limitar a exclusão à parte textual ou reorganizar o bloco. Cada pílula expõe seu rótulo e a ação nativa de exclusão, com descrição localizada como “Remover filtro de categoria: Moradia” ou “Remover filtro de período: Outubro de 2026”. Filtros desabilitados não expõem uma ação executável. Não duplicar anúncios com uma segunda camada de `Semantics` que represente o mesmo botão.

### 7. Verificação sem abstrações extras

Atualizar os previews reais de `ExpensesScreen` para categoria + mês, mês, categoria sem período, ausência de filtros, loading, erro e vazio. Fakes permanecem isolados de rede/storage/plugins e respeitam os parâmetros já existentes.

Validar UI/estado com Maestro, observando também as queries em logs debug de desenvolvimento quando necessário. Usar dados de demonstração com categorias e datas distintas e histórico com mais de 20 itens para provar paginação. Não versionar tokens, credenciais ou URLs assinadas nos flows ou fixtures. Não criar testes Flutter de widgets, telas, temas ou rotas, nem extrair uma nova camada apenas para testabilidade. Manter e executar os testes de command/repository/data source; alterar testes dessas camadas somente se houver alteração real nelas.

## Risks / Trade-offs

- [Cursor antigo reintroduz filtro removido] → iniciar toda troca com `pageLink: null` e continuar somente com links da resposta nova.
- [Dados antigos sob chips novos] → limpar a lista antes da consulta de troca; preservar itens somente em refresh/paginação da mesma lente.
- [Rebuild restaura contexto inicial] → inicializar estado uma vez e reconfigurar somente após mudança real nas entradas.
- [Resposta/finally antigo interfere no loading novo] → verificar revisão, command e montagem em todos os caminhos assíncronos.
- [Header exclui chips da acessibilidade] → manter o bloco de filtros fora da exclusão semântica do texto.
- [Busca ampla percorre todo o histórico] → manter paginação lazy de 20 itens e o trigger existente; não carregar todas as páginas antecipadamente.
- [Estilo de badge reduz alvo de toque] → aparência compacta sem reduzir o alvo Material acessível; validar escala de texto e temas.
- [Validação autenticada indisponível] → registrar o bloqueio e usar previews para verificar aparência; não declarar o fluxo completo validado sem executá-lo.

## Migration Plan

1. Implementar estado ativo e transição de consulta no mixin.
2. Integrar widget de pílulas e descrição fixa à composição existente.
3. Ajustar previews e documentação e executar verificações.
4. Validar cenários Maestro em build atualizado, com sessão e dados de demonstração disponíveis.

Não há migração de dados, storage, backend ou argumentos de rota. Um rollback consiste em reverter os arquivos desta alteração, preservando o fluxo anterior de navegação por categoria.

## Open Questions

Nenhuma decisão de produto pendente: descrição fixa e histórico completo após remoção do mês foram confirmados. A implementação deve conferir os exports de `InputChip` em `material_ui` e validar o estilo no tema real.
