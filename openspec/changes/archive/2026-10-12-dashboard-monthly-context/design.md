## Context

A Dashboard atual possui `metricsMonth` em `DashboardScreenStateMixin`, mas somente Metrics recebe esse período. `GetExpensesCommand` recebe paginação e `GetInsightsCommand` não recebe parâmetros. As três seções já são consultadas em paralelo e possuem apresentação própria. A lista de insights usa rolagem horizontal, que permanece independente da navegação mensal por setas.

Os exemplos fornecidos pelo usuário confirmam o contrato do backend: Metrics usa `start_date`/`end_date`; Insights usa `filter[year]`/`filter[month]`; Expenses aceita `filter[from]`/`filter[to]`. As respostas foram examinadas como evidência de contrato, sem chamadas executadas nesta proposta. Nenhum token dos exemplos deve ser incluído nos artefatos, fixtures ou comandos versionados.

A listagem de despesas já pagina em grupos e atualiza entidades após edição. O cadastro atualmente navega para `/dashboard` após sucesso; esse caminho precisa preservar a instância/contexto mensal quando iniciado pela Dashboard. O repositório possui alterações locais do usuário, que devem ser lidas e preservadas na implementação.

## Goals / Non-Goals

**Goals:**

- Compartilhar o mês selecionado entre gráfico, insights, recentes e a listagem aberta por “Ver tudo”.
- Manter estados de seção independentes, consultas paralelas e navegação mensal consistente.
- Preservar as camadas, commands, widgets compartilhados e contratos JSON:API atuais.
- Manter consultas gerais sem filtro para consumidores existentes.
- Garantir preservação do período em navegação, paginação e mutações da listagem.

**Non-Goals:**

- Pager por swipe ou `PageView`, cache de histórico, prefetch, store global ou dependências novas.
- Alterações de backend, filtros visuais de categoria/valor/dia, seleção arbitrária de datas ou meses futuros na Dashboard.
- Persistência de snapshots de insights, cálculo financeiro local ou reconstrução das dicas exibidas no passado.
- Mudança da data padrão do cadastro ou dos gestos de edição/exclusão.

## Decisions

### 1. Estado mensal pertence à Dashboard

Substituir o conceito de `metricsMonth` por um mês selecionado da Dashboard, normalizado ao primeiro dia civil. Calcular o intervalo com `DateTime(year, month)` e `DateTime(year, month + 1, 0)`, respeitando fevereiro e viradas de ano. O limite superior é o mês atual calculado a partir do relógio local. Não introduzir limite inferior de histórico que o produto não definiu.

O seletor exibe o mês da Dashboard independentemente do resultado de uma seção e deve permanecer visível em loading, vazio e erro. Sua composição pertence a Dashboard, usando os botões compartilhados e sem criar abstração global. Nome/avatar/menu e ação de cadastro permanecem gerais.

Alternativa considerada: manter um mês por seção. Rejeitada por permitir divergência de período. `PageView` foi descartado pela decisão explícita de navegação somente por setas.

### 2. Coordenar consultas sem agregar os domínios

A Dashboard continua consumindo seus três commands próprios. Uma troca inicia as consultas em paralelo, capturando o mesmo mês para todos os parâmetros. As setas ficam desabilitadas enquanto qualquer uma das consultas estiver em execução, incluindo abertura, refresh, retorno de navegação e retry de seção. Resultados `Left` e exceções devem finalizar o bloqueio, sem encerrar as demais consultas prematuramente.

O novo período deve ativar loading de cada seção antes que resultados antigos possam ser renderizados sob o novo título. Refresh não altera o mês. Falha mantém o erro ligado ao período consultado, com retry da seção no mês vigente. A seção de recentes precisará oferecer retry para evitar recarregar as demais após uma falha isolada.

Listeners usados para atualizar o estado agregado devem ser removidos no lifecycle. Respostas após descarte ou substituição de dependências não podem atualizar a tela. Usar o padrão de mixin restrito à screen e `CommandBuilder`, sem repository agregado de Dashboard.

Alternativa considerada: bloquear/renderizar toda a Dashboard como uma única operação. Rejeitada porque uma seção com falha não deve ocultar resultados úteis das demais.

### 3. Filtros mínimos nos contratos existentes

Expense adiciona parâmetros opcionais `DateTime? from` e `DateTime? to` a `get` no repository/data source e ao record de `GetExpensesCommand`. Insight adiciona `int? year` e `int? month` a `get` no repository/data source e passa a receber esses campos no command. Todos os consumidores dos records devem ser atualizados, inclusive previews, doubles e testes, com `null` explícito onde a consulta não é filtrada.

Repositories e commands delegam sem inventar defaults de período, converter fusos ou validar regras do backend. O data source serializa apenas os parâmetros não nulos. A Dashboard sempre envia os pares completos. Chamadas incompletas preservam o erro remoto; não preenchem a outra metade automaticamente.

| Seção | Query mensal |
| --- | --- |
| Metrics | `start_date=2026-09-01`, `end_date=2026-09-30`, `group_by=category` |
| Insights | `filter[year]=2026`, `filter[month]=9` |
| Recentes | `filter[from]=2026-09-01`, `filter[to]=2026-09-30`, `page[size]=6` |

Reutilizar o serializer civil existente em Expense e a política HTTP relativa/protegida do core. Os filtros adicionais disponíveis no backend não serão expostos nesta change.

Alternativa considerada: usar ano/mês em Expense ou filtrar despesas no cliente. O intervalo já corresponde ao período de Metrics e evita combinar formatos incompatíveis; filtrar uma página no cliente não encontra corretamente os seis recentes do mês.

### 4. Insights são análises do mês de referência

Preservar título, descrição, tipo, grupo, ordem, períodos e comparação da API. Uma análise de setembro pode abranger julho a setembro. Não filtrar novamente por `period`, nem transformar período nulo em mês fictício. O serviço recalcula os insights para o mês solicitado com os dados disponíveis; não há histórico persistido de cards no aplicativo.

### 5. Listagem recebe um período opcional pela rota

O callback de “Ver tudo” recebe o mês selecionado; a rota envia um argumento tipado com o intervalo civil completo para `/expenses`. Usar um record tipado se ele for suficiente para transportar as duas datas, evitando criar um VO ou camada somente para navegação. `ExpensesScreen` recebe o intervalo opcional por construtor. Ausência preserva a consulta geral. A listagem filtrada identifica o mês e ano visualmente e na semântica.

O estado da tela repassa o intervalo em abertura, paginação, refresh e retry, mantendo páginas de 20 e os agrupamentos existentes. O data source continua extraindo a query do link opaco e acessando apenas `expenses`. Depois de extrair a query, o tamanho solicitado e os filtros explícitos prevalecem. Na consulta por intervalo, remover filtros de ano/mês/dia herdados do link para não produzir a combinação inválida descrita pelo backend. Outros parâmetros de continuação permanecem preservados; o mixin não interpreta o link.

Após edição, uma entidade com data civil fora do intervalo é removida, sem reinserção no grupo. Se permanecer no intervalo, substitui/reposiciona como hoje, preservando paginação e rolagem. Exclusão mantém o filtro e permite continuar carregando quando necessário. Ao retornar à Dashboard, suas três seções são recarregadas no mês preservado.

Alternativa considerada: abrir sempre a listagem geral. Rejeitada pela decisão do usuário de acompanhar o contexto mensal.

### 6. Preservar o contexto ao cadastrar

O formulário continua iniciando com hoje. O fluxo iniciado pela Dashboard deve retornar à mesma Dashboard após sucesso por toque simples, sem recriar seu mês como atual. Ajustar o contrato de navegação/resultado do cadastro para distinguir esse retorno do acesso independente à rota, que continua tendo Dashboard como destino. Preservar o resultado de edição existente e o hold, que limpa o formulário e permanece na tela.

O estado permanece local à Dashboard; não criar persistência global para compensar um retorno que recria a rota. Sucesso, cancelamento e retorno de “Ver tudo” mantêm o mês escolhido.

## Risks / Trade-offs

- Rede lenta bloqueia navegação mensal até a última seção terminar → decisão aceita pelo usuário; manter skeletons e liberar o bloqueio em toda saída de execução.
- API não verificada ao vivo nesta proposta → validar mês atual explícito, histórico, vazio, erros e paginação filtrada durante implementação, com credenciais fora do repositório.
- Links de continuação podem não transportar filtros ou conter conflito → reaplicar intervalo explícito e tamanho sem interpretar a continuação na UI, com testes do data source.
- Retorno atual do cadastro pode recriar a Dashboard → validar preservação do mês no fluxo real com Maestro, incluindo hold e acesso independente.
- Edição pode mover uma despesa para outro mês → excluir do recorte atual e atualizar Dashboard no retorno.
- Alterações locais existentes → integrar a implementação após ler os arquivos atuais, sem reverter trabalho do usuário.

## Migration Plan

1. Evoluir contratos e atualizar todos os consumidores/testes no mesmo conjunto de mudanças, mantendo ausência de filtros.
2. Adaptar coordenação mensal e navegação contextualizada, com previews e documentação atualizados.
3. Executar análise, testes das camadas e validação de fluxos com Maestro e API.

Não há migração de dados ou mudança de backend. Eventual rollback é a reversão das alterações desta implementação preservando trabalhos independentes; os endpoints antigos sem filtros permanecem disponíveis.

## Open Questions

Não há decisão de produto bloqueante. A execução deve confirmar os comportamentos da API citados nos riscos e registrar eventuais divergências antes de considerar as tarefas concluídas.
