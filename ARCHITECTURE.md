# Arquitetura

## Visão Geral

Cordato é um aplicativo Flutter de finanças pessoais e familiares organizado
por feature e por camadas. Cada pessoa é dona dos próprios dados financeiros;
a família é uma lente de leitura compartilhada, nunca uma dona de dinheiro.

O aplicativo integra o fluxo de autenticação e os data sources de User, Expense, Insight e Metrics à API
HTTP JSON:API pelo cliente compartilhado de `coreDependenciesModule` (padrão
`https://app.cordato.cloud/api/`). Não há schema ou backend financeiro ativo
versionado neste repositório. O Kotlin legado é
referência de domínio, não uma dependência de execução. A apresentação permanece
independente de clientes HTTP, storage e plugins.

```text
Screen/Widget -> Command -> contrato de repository (domain)
  -> repository (application) -> data source (infrastructure) -> HTTP/storage
```

Uma screen conhece commands e contratos de repositório, nunca `Dio`,
`FlutterSecureStorage` ou clientes de rede diretamente.
O diagrama descreve o fluxo de execução, não uma cadeia de imports entre
camadas: `domain` não importa `application/repositories` ou `infrastructure`. Os módulos fazem a
composição das implementações. Features exclusivamente visuais não precisam
de repositories, commands ou camadas vazias.

Este documento descreve a implementação atual e identifica explicitamente as
decisões para contextos ainda planejados. Specs OpenSpec e skills locais ainda
contêm descrições históricas de Supabase; não representam a autenticação atual
nem justificam restaurar camadas removidas.

## Firebase E Bootstrap

O bootstrap em `lib/main.dart` prepara `WidgetsFlutterBinding` e aguarda
`FirebaseClient.initialize()` antes de montar o `ModularApp`. O cliente e seu
contrato `IFirebaseClient` ficam em
`core/infrastructure/clients/firebase/firebase_client.dart` e encapsulam
`Firebase.initializeApp` com `DefaultFirebaseOptions.currentPlatform`.
A inicialização usa a instância padrão, sem `name`, exigida pelos plugins
Crashlytics e Messaging. O projeto remoto continua sendo `trocado-d362e`.
Falhas de inicialização são propagadas e impedem o início do app.
O cliente é criado no bootstrap, sem registro de DI enquanto não houver
consumidores nos módulos.

`firebase_core` configura o projeto `trocado-d362e` somente para Android e iOS,
ambos com identificador `com.bed.cordato`. As opções em
`core/infrastructure/clients/firebase/firebase_options.dart`,
`firebase.json`, `android/app/google-services.json` e
`ios/Runner/GoogleService-Info.plist` são geradas pelo FlutterFire CLI.
O Android aplica o plugin Google Services; o iOS inclui o plist nos recursos
do target Runner. Outras plataformas não possuem opções configuradas.
Os clientes de Core, Crashlytics e Messaging ficam juntos em
`core/infrastructure/clients/firebase/`, sem pastas separadas por serviço.

`CrashClient` implementa `ICrashClient`, recebe `FirebaseCrashlytics` por
construtor e delega somente `recordFlutterError` e `recordError` ao SDK.
Não possui `initialize`, configuração de coleta ou lifecycle. Após o
`ModularApp` montar o grafo de dependências, o Builder do bootstrap resolve
`inject<ICrashClient>()` e conecta diretamente `FlutterError.onError` a
`recordFlutterError` e `PlatformDispatcher.instance.onError` a `recordError`.
O bootstrap não acessa o SDK Crashlytics nem define uma política de coleta por
modo de build; vale o comportamento padrão do Firebase.
Erros do framework são não fatais;
erros assíncronos não tratados são fatais e preservam a stack trace original.
Chamadas de registro delegam ao SDK e propagam falhas, independentemente
do modo de build. O Android aplica o plugin Crashlytics, e o Runner executa
`ios/upload_crashlytics_symbols.sh` após Thin Binary somente em Release para
dispositivo, usando os checkouts do Swift Package Manager e FlutterFire CLI.

`MessagingClient` implementa `IMessagingClient`, recebe `FirebaseMessaging`
e o stream `FirebaseMessaging.onMessage` por construtor. Identifica somente
Android e iOS; demais plataformas são recusadas. `requestPermission()` retorna
`true` para autorização plena ou provisória, e `false` para negada ou ainda não
determinada. `getToken()` preserva o token FCM anulável; no iOS consulta APNs
antes e retorna `null` enquanto esse token não estiver disponível. Falhas do SDK
propagam, distinguindo indisponibilidade de ausência de token ou permissão.
Não há polling nem retry automático. `onTokenRefresh` preserva o stream do SDK,
e `onForegroundMessage` converte `RemoteMessage.toMap()`, incluindo `data`,
metadados e `notification` anulável; mensagens somente de dados não são
descartadas. O consumidor deve cancelar suas subscriptions.

`coreDependenciesModule` registra os SDKs da instância padrão e o stream de
mensagens como lazy singletons; `ICrashClient` e `IMessagingClient` usam
`CrashClient.new` e `MessagingClient.new`, com dependências resolvidas pelo
Modular. Nenhuma screen acessa SDKs.
O app não solicita permissão nem consulta/envia tokens ao abrir. Não há
integração com backend de dispositivos, renderização de notificação em primeiro
plano, navegação ao tocar ou handler Dart para mensagens de background.
Notificações em background seguem o comportamento nativo do FCM, sujeito à
permissão do sistema. O Android declara `POST_NOTIFICATIONS`; o iOS declara
Push Notifications, entitlement APNs e modos `fetch`/`remote-notification`,
mantendo o swizzling do SDK habilitado. Para entrega iOS, ainda é necessário
configurar a chave APNs no console Firebase para `com.bed.cordato` e usar um
provisioning profile com Push Notifications; esse estado remoto não foi verificado.

## Produto E Contextos

Os contextos financeiros e seu estado atual são:

- `expense`: cadastro integrado à API por formulário, validators, command,
  repository e data source HTTP, além de consulta paginada no repository e data
  source, consumida pela seção de recentes da Dashboard. Possui entidade de domínio, value object
  monetário, categorias, parâmetros diretos de criação e response DTO. Seleção de valor e
  data usa bottom sheets. `HoldButtonWidget` permite cadastrar e voltar ao
  dashboard com toque simples ou cadastrar e continuar com um novo formulário
  após completar o hold; ambos exibem toast de sucesso.
- `budget`: planejado; não há feature Flutter de orçamento nesta versão.
- `family`: planejado. Será uma organização de membros com leitura combinada autorizada.
- `insight`: consulta somente leitura integrada à API, com entidades imutáveis,
  repository, DTOs, data source HTTP e command. A Dashboard apresenta os
  resultados em cards informativos com rolagem horizontal acima das despesas.
- `metrics`: agregações somente leitura, com entidades de métricas de despesas,
  contrato e implementação de repository, data source HTTP, DTOs de resposta
  e command de consulta. A Dashboard apresenta a distribuição mensal em um
  carrossel de cards ilustrados por categoria.

`ExpenseMetricsEntity`, em `metrics/domain/entities/`, preserva `id`,
`startDate` e `endDate` como datas civis e `totalAmount` como centavos inteiros
de BRL. Zero representa um período sem gastos. Não reutiliza o value object
de Expense, que exige um gasto positivo, nem importa outro contexto financeiro.
Não inclui o tipo fixo ou os links do envelope JSON:API e não faz parsing,
formatação, conversão de fuso ou cálculo de agregações.

`categories` é uma lista anulável de `ExpenseCategoryMetricsEntity`: `null`
representa agrupamento ausente e lista vazia representa um agrupamento sem
itens. A entidade copia a lista para um snapshot não modificável, preservando
a ordem recebida. Cada categoria possui `category` como string, inclusive
valores futuros, `totalAmount` como centavos inteiros e `percentage` como
`double` em escala de 0 a 100, não como fração. Percentuais não são valores
monetários; os valores fornecidos são preservados sem recálculo ou arredondamento.
As entidades são dados imutáveis, sem validação ou normalização de entrada.

`IMetricsRepository.getExpenses({DateTime? startDate, DateTime? endDate,
ExpenseMetricsGroupByEnum? groupBy})` retorna
`Future<GetExpensesRepositoryType>`, com `Either<ErrorsEntity, ExpenseMetricsEntity>`.
`ExpenseMetricsGroupByEnum` oferece somente `category`, o agrupamento conhecido
do contrato atual. `groupBy: null` solicita apenas o total. As datas são
opcionais para permitir o período padrão definido pelo serviço; um período
explícito deve informar ambas. A validação dos parâmetros pertence à API e
será representada por `Left`, sem defaults locais ou nova regra de calendário
no domínio. O contrato não oferece escrita, paginação ou persistência.

`MetricsRepository`, em `metrics/application/repositories/`, implementa
`IMetricsRepository` e recebe `IMetricsRemoteDataSource`. Delega as datas e o
agrupamento sem validação, normalização ou defaults, inclusive quando somente
uma data foi informada. Converte a resposta em `ExpenseMetricsEntity`, preservando
o período retornado pelo serviço, total zero, agrupamento ausente ou vazio,
ordem das categorias e percentuais. Converte `ErrorsResponse` em `ErrorsEntity`
pelo helper compartilhado; exceções inesperadas retornam `ErrorsEntity.unknown()`.
Não acessa HTTP, storage ou outros repositories. Os parâmetros nomeados são
suficientes para esta consulta; não há wrapper em `application/data/`.

`IMetricsRemoteDataSource`, em `metrics/infrastructure/remoto/`, define
`getExpenses` com os mesmos parâmetros opcionais e retorno
`Either<ErrorsResponse, ExpenseMetricsResponse>`. `MetricsRemoteDataSource`,
no mesmo arquivo, recebe `IHttpClient` e executa GET relativo `metrics/expenses`,
marcado como protegido em `HttpPathEnum.expenseMetrics`. Serializa somente os
filtros informados: `start_date` e `end_date` em `yyyy-MM-dd` pelos componentes
civis, sem horário ou conversão de fuso, e `group_by: category`. Sem filtros,
não envia query. Períodos incompletos são enviados à API sem inventar a outra
data; a resposta de validação é preservada. Headers JSON:API e Bearer ficam
nos interceptors compartilhados. URLs absolutas ou subcaminhos não recebem
token; um 401 remove somente o token enviado conforme a política de sessão.
Expense e Metrics reutilizam `formatDateSerializer`, em
`core/infrastructure/serializers/civil_date_serializer.dart`, para serializar
datas civis em `yyyy-MM-dd` pelos componentes originais. A função não aplica
defaults, horário ou conversão de fuso; o default de hoje continua pertencendo
somente ao cadastro no data source de Expense.
O data source reutiliza `response<T>` para converter o recurso em `data`,
preservar erros JSON:API e traduzir respostas malformadas e exceções em erro
genérico. `ExpenseMetricsResponse` e
`ExpenseCategoryMetricsResponse`, em `infrastructure/responses/`, possuem
factories `fromJson` e extensões `toEntity`. O DTO principal recebe um recurso
JSON:API, lê `id` e `attributes` e converte os totais textuais com `int.parse`,
os percentuais textuais com `double.parse` e as datas com `DateTime.parse`.
Não converte valores monetários por `double` nem recalcula os percentuais.
A lista de categorias é copiada e não modificável; ausência ou `null` permanece
`null`. Parsing inválido lança exceção e não produz resposta parcial; o data
source HTTP traduz essas falhas pelo `response<T>` do core.

`ErrorResponse` e `ErrorEntity` no core preservam `source.parameter` no campo
opcional `parameter`, separado de `pointer`. O parser JSON:API e a conversão
para domínio mantêm ambos quando presentes, permitindo identificar filtros
inválidos como `start_date` sem tratá-los como pointers do documento.

`GetExpenseMetricsCommand`, em `metrics/presentation/commands/`, recebe
`IMetricsRepository` e implementa `ICommand`. `execute` recebe o record
`({DateTime? startDate, DateTime? endDate, ExpenseMetricsGroupByEnum? groupBy})`
e delega seus campos a `getExpenses` sem validação, normalização ou defaults.
Os três campos do record são informados explicitamente; `null` preserva a
ausência do filtro. O resultado começa em `null` e preserva o
`Either<ErrorsEntity, ExpenseMetricsEntity>` em `GetExpensesRepositoryType?`,
incluindo totais zero e falhas de validação como resultados. Cada consulta
substitui o resultado anterior, sem cálculo ou acúmulo de métricas. O command
impede execuções concorrentes e permite nova tentativa após falha; exceções
inesperadas permanecem erros observáveis do command. `dispose` descarta
`execute`; cada consumidor deve possuir e descartar sua instância. Não há
tela proprietária em Metrics, portanto o command fica no diretório da feature.

`metricsDependenciesModule` registra `IMetricsRemoteDataSource` e
`IMetricsRepository` como lazy singletons e `GetExpenseMetricsCommand` por
factory, composto por `appModule`. A rota da Dashboard injeta uma instância
própria do command, descartada por `DashboardScreenStateMixin`. O mixin mantém
`selectedMonth`, iniciado no primeiro dia civil do mês atual, e calcula o último
dia com `DateTime(year, month + 1, 0)`. As três seções consultam esse mesmo mês
em paralelo: Metrics com intervalo e `groupBy: category`, Insights com ano/mês
e recentes com intervalo e tamanho seis. Abertura, troca pelas setas, refresh e
retorno à instância existente da Dashboard usam esse contexto; refresh não muda
a seleção. `DashboardMonthSelectorWidget` pertence à Dashboard, permanece visível
em todos os estados e impede avanço além do mês atual, sem swipe mensal.
As setas reutilizam o fundo, raio e tamanho do botão de voltar do core e
mostram o ícone com opacidade reduzida quando desabilitadas.
O retorno é limitado ao mês da primeira despesa; meses vazios intermediários
continuam navegáveis. Sem despesas, ambas as setas ficam desabilitadas no mês atual.
`GetFirstExpenseMonthCommand`, em `dashboard/presentation/screens/dashboard/commands/`,
consulta o histórico geral por `IExpenseRepository.get`, com o tamanho padrão
de página, seguindo `next` como continuação opaca e calculando o menor mês civil
sem acumular despesas. Não pressupõe ordenação nem encerra em uma página vazia
que ainda tenha continuação. Falhas invalidam o limite inteiro e continuações
repetidas retornam erro. O command é registrado por factory no módulo de rotas
da Dashboard e descartado pela tela, interrompendo novas páginas após descarte.
O limite é consultado na abertura, refresh e retorno de cadastro/listagem com alterações confirmadas;
trocas de mês reutilizam o resultado. Durante a consulta, as setas ficam
desabilitadas; falha mantém o retorno bloqueado até uma nova consulta por refresh.
Se a primeira despesa for removida ou mudar de mês, a recarga ajusta uma seleção
anterior ao novo limite antes de consultar as seções, sem avançar além do mês atual.
Essa consulta percorre todo o histórico porque o contrato atual não fornece
metadados do primeiro mês nem ordenação ascendente.
As setas ficam desabilitadas enquanto qualquer command de seção estiver rodando,
inclusive retry. O mixin observa `isRunning` dos três commands, removendo os
listeners antes de substituir ou descartar instâncias. Retornos de navegação
após descarte ou substituição de dependências são ignorados.
Voltar do cadastro ou da listagem sem alterações não dispara consultas nem skeletons.
Os callbacks financeiros da Dashboard retornam `Future<bool>`: `true` somente
quando houve criação, edição ou exclusão bem-sucedida durante a navegação.
O módulo de Dashboard mantém esse sinal local a cada abertura e transporta
`VoidCallback onExpensesChanged` no record de argumentos da rota, junto a
`returnToPrevious` no cadastro ou `from`/`to` na listagem. As rotas continuam
aceitando os records anteriores sem callback. As telas recebem o callback
anulável por construtor; o formulário o chama em cada criação confirmada,
inclusive hold, e em atualização confirmada. A listagem o chama após receber
uma edição bem-sucedida ou confirmar a exclusão na API. O sinal independe do
modo de fechamento da rota, incluindo botão, gesto e voltar do sistema.
Quando o retorno com alterações ocorre durante uma consulta, o mixin adia a recarga das três
seções até todas terminarem, inclusive com erro, mantendo o mês selecionado.
A recarga pendente é invalidada na troca de dependências e não executa após
descarte da tela.

`MetricsSectionWidget`, na Dashboard, fica antes dos insights. Usa
`CommandBuilder` para skeleton, falha com retry, total zero e sucesso. O total
é formatado pelo `IMoneyFormatter`; o mês do seletor vem do estado da Dashboard,
independentemente da resposta da API. A troca de período inicia loading nas três
seções e renova suas chaves pelo mês, sem renderizar resultados antigos sob o
novo título. Cada falha oferece retry somente da seção no mês selecionado.
Total positivo sem categorias mostra uma
mensagem de distribuição indisponível, inclusive quando nenhum total de categoria
é positivo; total zero não produz cards fictícios. Uma única categoria positiva
mantém apenas o total, sem carrossel nem mensagem de distribuição indisponível.

`ExpenseMetricsCategoriesExtension.cardPages`, na apresentação de Metrics,
filtra totais positivos, ordena uma cópia por total decrescente com desempate
pelo índice original e forma grupos consecutivos de duas ou três categorias.
Grupos com apenas uma categoria são ocultados, inclusive a sobra final: quatro
categorias produzem uma página de três; cinco produzem páginas de três e duas.
Não altera
entidades, ordem de domínio, valores ou percentuais recebidos da API.
`ExpenseCategoryMetricsCardWidget` mostra nome completo, valor pelo
`IMoneyFormatter`, badge e percentual pt-BR com uma casa decimal seguido de
“do total”. Cada card anuncia esses dados uma única vez. Com callback disponível,
reutiliza `BounceWidget` e oferece a ação de acessibilidade para consultar despesas
da categoria. O toque abre `/expenses` pelo mesmo callback de “Ver tudo”, com
o intervalo do mês selecionado e a categoria como string da API; arrastar o
carrossel não abre a listagem. Metrics apenas emite a categoria, sem conhecer
Expense ou navegação. Dashboard compõe o destino e preserva o sinal de alterações
e a recarga no retorno. Toques repetidos durante a navegação são ignorados.
Categoria, valor e percentual usam o mesmo espaçamento vertical de 8 pixels.
O primeiro card de cada página tem valor maior e ilustração decorativa por
`ImageWidget`, sem tint, ancorada no canto inferior direito, sem padding textual
e respeitando os cantos do card. A área decorativa de 180 pixels acomoda a imagem
de 220 pixels alinhada pela base. `OverflowBox` permite que a imagem pinte acima
da área reservada, sem `ClipRect` interno; o recorte ocorre no contorno do card.
O card superior usa `compact`, com área decorativa de 60 pixels e imagem de
220 pixels, ou 240 pixels para Moradia, mantendo os dados completos.
A imagem usa deslocamento vertical de 64 pixels no layout compacto e 48 nos
demais, para acompanhar a base mais curta sem avançar sobre os textos.
Somente o card superior possui ilustração e destaque tipográfico, inclusive em
páginas com duas categorias. `illustrated` permite separar a presença da imagem
de `highlighted`, mas não é ativado nos cards inferiores do carrossel.
`BackgroundIconWidget` mantém ícone quadrado arredondado
e fundo a 12%. `ExpenseCategoryMetricsExtension` oferece rótulos, ícones,
cores alinhadas aos itens de Expense sem importá-los e assets de categorias.
O getter `asset` retorna `AssetEnum` do core, que centraliza `source` e `alt`
da logo e das imagens de categorias. O card consome esses campos pelo
`ImageWidget` e usa `AssetEnum.categoryOthers.source` como fallback, sem
montar ou repetir caminhos de arquivos na feature.
`other` usa `others.webp`; categorias futuras mantêm o nome, com ícone/cor
neutros e essa imagem como fallback. Cores, tipografia e raios vêm do tema.

`ExpenseMetricsGridWidget` compõe sempre duas linhas: um card ilustrado em
largura total acima e uma linha inferior sem ilustrações. Com três categorias,
os dois cards inferiores ficam lado a lado em larguras iguais; com duas, o card
inferior ocupa toda a largura, mantendo a altura da linha inferior.
Não há placeholders para completar a última página.
O destaque é relativo à página, sem área proporcional ao gasto.
A altura da grade é calculada pela medição do conteúdo com a
escala de texto vigente, sem piso fixo. O carrossel calcula separadamente a maior
altura superior e a maior altura inferior entre todas as páginas e as aplica
a cada linha. `upperHeight` e `lowerHeight` são repassados à grade; a altura total
é sua soma mais 12 pixels de espaçamento, preservando o alinhamento ao deslizar.
Nomes e valores extensos ou texto ampliado aumentam a altura da linha conforme
a medição na largura real, sem truncamento e sem alterar o formato.
`ExpenseMetricsCarouselWidget` usa
`PageView.builder` com `PageController`, altura uniforme suficiente para todas
as páginas e indicador quando há mais de uma. A paginação nativa encaixa uma
página completa ao finalizar o gesto e constrói os widgets sob demanda.
Seu mixin restrito atualiza o índice por `onPageChanged`, reinicia com
`jumpToPage(0)` na substituição dos dados e descarta o controller. Não há
listener manual de offset nem divisão de pixels para estimar a página.
O carrossel ocupa a largura da tela. Cada grade mede a largura disponível menos
40 pixels, com margens laterais de 20 pixels no encaixe e separação de 12 pixels
entre páginas durante o arraste, como a lista de insights. O `PageController`
usa `viewportFraction` de `(largura - 28) / largura` e cada página recebe 6 pixels
de padding lateral. O mixin recria e descarta o controller quando a largura muda,
preservando o índice atual; o total e os estados de mensagem mantêm suas margens.
A seção renova a identidade pelo resultado; a Dashboard renova a chave pelo
mês. O reinício é imediato, sem animação programática; o encaixe nativo do gesto
permanece ativo, inclusive com redução de animações, para evitar parada entre
páginas. O skeleton reutiliza a
grade de três cards e a mesma altura-base adaptativa, exclui placeholders da semântica e anuncia o loading.
Previews cobrem 1, 2, 3, 4, 5, 6, 7, 8 e 10 categorias, empates, fallback, estados,
temas e texto ampliado.

`InsightEntity`, em `insight/domain/entities/`, possui `id`, `title`, `type`,
`group`, `description` e `period` anulável. Insights de onboarding como
`insufficient_history` podem trazer `period: null`, preservado sem datas fictícias.
Esses itens são apresentados como cards com título e descrição da API.
`type` e `group` são strings que preservam
os valores da API, inclusive tipos novos; ícones e cores pertencem à futura
apresentação. A entidade não inclui o envelope JSON:API nem realiza parsing.
`InsightPeriodEntity` possui `from` e `to` como datas civis em `DateTime`, sem
normalização ou conversão de fuso, e `comparison` opcional como
`InsightDateRangeEntity`, que contém somente `from` e `to`.
`IInsightRepository.get({int? year, int? month})` retorna `Future<GetRepositoryType>`, com
`Either<ErrorsEntity, List<InsightEntity>>`. Lista vazia representa sucesso;
o contrato não oferece escrita, paginação, ordenação local ou persistência.
Insights são análises derivadas fornecidas pelo serviço, sem cálculo financeiro
no domínio do aplicativo e sem dependência de outros contextos financeiros.

`InsightRepository`, em `insight/application/repositories/`, implementa
`IInsightRepository` e recebe `IInsightRemoteDataSource`. Delega ano e mês ao
data source sem defaults, validação ou normalização e converte todos os
`InsightResponse` em entidades, preservando
ordem, conteúdo, tipos desconhecidos e datas sem normalização ou conversão de
fuso. Lista vazia permanece sucesso. Converte `ErrorsResponse` em
`ErrorsEntity` com os metadados originais; exceções inesperadas retornam
`ErrorsEntity.unknown()`. Não acessa HTTP, storage ou outros repositories.
`IInsightRemoteDataSource`, em `infrastructure/remoto/`, define `get({int? year, int? month})` com
`Either<ErrorsResponse, List<InsightResponse>>`. `InsightResponse`,
`InsightPeriodResponse` e `InsightDateRangeResponse`, em
`infrastructure/responses/`, são DTOs imutáveis com factories `fromJson` e
extensões `toEntity()`. O parsing usa casts e `DateTime.parse`, preservando
datas civis, período nulo e comparação ausente ou nula. Períodos não nulos
continuam exigindo datas válidas; parsing inválido não gera resultado parcial.
`InsightResponse.fromJson` recebe
um recurso da lista `data`, lendo o tipo de análise de `attributes.type`,
não de `data.type`.
`InsightRemoteDataSource` executa GET relativo `insights`, protegido por
`HttpPathEnum.insights`, com o HTTP do core e `response<T>`. Envia somente os
filtros não nulos `filter[year]` e `filter[month]`; sem ambos, não envia query.
Filtros incompletos são enviados sem completar o par, preservando erros remotos
com `source.parameter` e `source.pointer`. O mês é referência da análise, sem
recortar períodos de vários meses ou substituir períodos nulos. Lista vazia é
sucesso; parsing inválido em qualquer item invalida a resposta completa.
Erros JSON:API são preservados e exceções usam o erro genérico compartilhado.
Headers e Bearer pertencem aos interceptors; um 401 remove somente o token
enviado seguindo a política de sessão existente.
`insightDependenciesModule`, sem rota própria, registra data source e repository
como lazy singletons pelos contratos e `GetInsightsCommand` por factory.
É composto por `appModule` e consumido pela rota da Dashboard.

`GetInsightsCommand`, em `insight/presentation/commands/`, recebe
`IInsightRepository` e delega os campos do record `({int? year, int? month})`
a `get` sem defaults ou normalização. Ambos os campos devem ser explícitos;
`(year: null, month: null)` preserva a consulta geral. `execute` começa em
`null` e preserva `Either<ErrorsEntity, List<InsightEntity>>` em
`GetRepositoryType?`; lista vazia é sucesso e `Left` é resultado de negócio.
Cada consulta substitui o resultado anterior, sem acumular, ordenar ou limitar
insights. O command impede novas chamadas durante a execução e permite nova
tentativa após falha. Exceções inesperadas são erros observáveis do command.
Implementa `ICommand`, descarta `execute` em `dispose` e deve ser descartado
pelo consumidor. Não há tela proprietária de Insight, portanto o command fica
no diretório de commands da feature.

`InsightsSectionWidget`, na Dashboard, usa `CommandBuilder` para estados
independentes das despesas: skeleton com anúncio “Carregando insights”, erro
discreto com “Tentar novamente”, lista vazia sem seção nem espaçamento e sucesso.
`InsightsListWidget`, na apresentação de Insight, preserva a ordem da API em
`SingleChildScrollView` horizontal e `Row`, com margens de 20 pixels, espaçamento
de 12 e cards com toda a largura disponível descontando as margens laterais
de 20 pixels. `IntrinsicHeight` acompanha o maior
conteúdo, sem altura fixa ou truncamento de textos, inclusive com fonte ampliada.
`InsightCardWidget` compõe `IformationCardWidget` do core e usa
`InsightCardWidgetMixin` para selecionar o visual pelo tipo: tendência com
`primary` para `registered_amount_increase`, repetição para
`category_lead_streak` em turquesa vivo no tema escuro e teal escuro no claro,
e lâmpada com `onSurfaceVariant` para tipos desconhecidos.
O fundo do ícone usa a mesma cor com opacidade de 12%; não há callback, seta,
classificação automática de aumento como erro nem interpretação da descrição.
Os previews cobrem loading, vazio, erro, claro/escuro, tipo desconhecido e texto
ampliado. A UI não calcula análises ou altera conteúdo fornecido pelo serviço.

`ExpenseEntity`, em `expense/domain/entities/expense_entity.dart`, representa uma
despesa cadastrada, com primary constructor `const` e campos imutáveis obrigatórios:
`id` como `String`, `cents` como `AmountValueObject`, `occurredOn` como
`DateTime` para a data civil do gasto, `description` como `String`, `category`
como `ExpenseCategoryEnum`.
A entidade não faz parsing, serialização ou validação de entrada; não recebe o
envelope JSON:API nem referências a orçamento ou família. A data civil deve ser
preservada sem conversões de fuso na futura integração.

`AmountValueObject`, em `expense/domain/value_objects/amount_value_object.dart`,
representa valores positivos em centavos inteiros de BRL. O construtor é privado
e `create({required int cents})` retorna `Either<ErrorsEntity, AmountValueObject>`:
zero e valores negativos retornam erro de domínio com mensagem pt-BR; valores
positivos são preservados sem conversão ou arredondamento. O campo `cents` é
imutável, e igualdade e hash são definidos pelo valor em centavos. Não aceita
`double`, não faz parsing ou formatação e não depende de HTTP. O VO pertence
ao domínio e é usado em `ExpenseEntity`, não nos parâmetros de criação. O data source
envia `cents` como inteiro em centavos no atributo `amount` do payload.
`ExpenseResponse.toEntity()` converte o valor recebido em `AmountValueObject`
antes de construir a entidade.

`ExpenseCategoryEnum`, em `expense/domain/enums/expense_category_enum.dart`, define
18 categorias com `value` correspondente ao contrato da API: `food`, `pets`,
`taxes`, `health`, `travel`, `housing`, `leisure`, `shopping`, `services`,
`transport`, `education`, `financing`, `insurance`, `investments`, `personal_care`,
`subscriptions`, `gifts_and_donations` e `other`. Os membros Dart `personalCare`
e `giftsAndDonations` preservam os valores snake_case da API por esse campo;
`ExpenseResponse` faz parsing por `value`, não pelo nome do membro.
`ExpenseCategoryExtension`, em `expense/presentation/extensions/`, oferece `label`
com rótulos pt-BR, ícones e cores para todas as categorias. Metrics mantém os
mesmos rótulos em sua própria extension de apresentação, sem importar Expense.
A tradução pertence à apresentação;
o domínio não depende de idioma. Parsing e serialização ficam para infrastructure,
sem conversão silenciosa de categorias desconhecidas para `other`.

`IExpenseRepository`, em `expense/domain/repositories/interface_expense_repository.dart`,
define `create({required int cents, required String description, DateTime? occurredOn})`,
retornando `Future<CreateRepositoryType>`, com `Either<ErrorsEntity, ExpenseEntity>`.
Os parâmetros são primitivos, sem wrapper de input: centavos inteiros de BRL e
descrição são obrigatórios; a data civil é opcional. `ExpenseRepository`, em
`expense/application/repositories/expense_repository.dart`, implementa esse contrato e
recebe `IExpenseRemoteDataSource`. Delega os mesmos parâmetros, inclusive a data
anulável sem aplicar default, converte `ErrorsResponse`
em `ErrorsEntity` e usa `ExpenseResponse.toEntity()` para validar e converter o
sucesso, preservando falhas do VO. Exceções inesperadas retornam
`ErrorsEntity.unknown()`. Não acessa HTTP ou storage diretamente e não substitui
os dados devolvidos pelo backend pelos parâmetros enviados.

`IExpenseRemoteDataSource` e `ExpenseRemoteDataSource`, no mesmo arquivo em
`expense/infrastructure/remoto/expense_remote_data_source.dart`, recebem parâmetros
nomeados em `create({required int cents, required String description, DateTime? occurredOn})`.
O retorno `CreateDataSourceType`
é `Either<ErrorsResponse, ExpenseResponse>`. A implementação recebe `IHttpClient`
do core e reutiliza `response<T>` para preservar erros JSON:API e converter
exceções e respostas malformadas em erro genérico. POST `expenses` usa
`HttpPathEnum.expenses.path` e `data.type: expenses`, com `amount: cents`,
`description` sem normalização e `occurred_on` como `yyyy-MM-dd`. A data utiliza
os componentes da data informada sem conversão de fuso; o horário é omitido.
Quando `occurredOn` é omitido ou nulo, o data source usa `DateTime.now()`.
Headers e
Bearer são aplicados pelos interceptors compartilhados, sem leitura de storage
no data source.
`IExpenseRemoteDataSource.update({required String id, int? cents, String? description, DateTime? occurredOn})`
retorna `Future<UpdateDataSourceType>`, com `Either<ErrorsResponse, ExpenseResponse>`.
Executa PATCH relativo `expenses/<id>`, codificando o ID com `Uri.encodeComponent`.
O payload contém `data.type: expenses` e apenas os atributos não nulos
`amount` (centavos inteiros), `description` e `occurred_on`, sem normalização.
A data civil usa `yyyy-MM-dd` pelos componentes informados, sem conversão de fuso
ou horário. Não envia `data.id` ou categoria. Campos omitidos não são substituídos por defaults;
sem atributos informados, envia um mapa vazio e deixa a validação para a API.
Reutiliza `ExpenseResponse` e `response<T>`, preservando os dados retornados e
os erros JSON:API; respostas malformadas e exceções resultam em erro genérico.
Headers e Bearer seguem os interceptors compartilhados.
`IExpenseRepository.update({required String id, int? cents, String? description, DateTime? occurredOn})`
retorna `Future<UpdateRepositoryType>`, com `Either<ErrorsEntity, ExpenseEntity>`.
`ExpenseRepository.update` delega ID e atributos ao data source sem normalização,
validação local de entrada ou substituição de campos nulos por defaults.
Converte todos os erros remotos para `ErrorsEntity` e usa
`ExpenseResponse.toEntity()` para validar os centavos retornados e construir a
entidade, preservando as falhas do VO e todos os dados da resposta da API.
Exceções inesperadas retornam `ErrorsEntity.unknown()`. O repository não acessa
HTTP ou storage. A edição está disponível no repository e no data source;
a tela compartilhada de cadastro e edição usa essa operação.
`IExpenseRemoteDataSource.getById({required String id})` retorna
`Future<GetByIdDataSourceType>`, com `Either<ErrorsResponse, ExpenseResponse>`.
Executa GET relativo `expenses/<id>` com ID codificado, sem corpo, query ou
headers próprios, reutilizando o parsing e tratamento de erro de `response<T>`.
`IExpenseRepository.getById({required String id})` retorna
`Future<GetByIdRepositoryType>`, com `Either<ErrorsEntity, ExpenseEntity>`.
O repository delega o ID sem normalização, preserva a resposta da API, valida os
centavos por `ExpenseResponse.toEntity()` e converte erros e exceções como na
criação e atualização. A autorização permanece na API.
`IExpenseRemoteDataSource.delete({required String id})` retorna
`Future<DeleteDataSourceType>`, com `Either<ErrorsResponse, bool>`. Executa DELETE
relativo `expenses/<id>`, codificando o ID com `Uri.encodeComponent`, sem corpo
ou query. O `SessionInterceptor` reconhece tanto `expenses` quanto
`expenses/<id>` como endpoints relativos protegidos e aplica o Bearer; URLs
absolutas e caminhos com segmentos adicionais continuam sem token. Retorna
`true` em 204 sem corpo e `false` para outros status de sucesso.
`HttpPathEnum` declara somente o caminho e a classificação de autenticação.
O `SessionInterceptor` reconhece o recurso `users/<id>` e os caminhos `expenses`
e `expenses/<id>`; os demais endpoints mantêm o caminho exato.
O interceptor compara segmentos completos; um ID deve ser um
único segmento não vazio e diferente de `.` e `..`.
Reutiliza `response<T>` para preservar erros JSON:API e traduzir exceções ou
erros malformados em erro genérico.
`IExpenseRepository.delete({required String id})` retorna
`Future<DeleteRepositoryType>`, com `Either<ErrorsEntity, bool>`.
`ExpenseRepository.delete` delega o ID sem normalização ao data source, preserva
o booleano de sucesso, converte todos os erros remotos para `ErrorsEntity` e
traduz exceções inesperadas em `ErrorsEntity.unknown()`. A codificação do ID e
o tratamento do status HTTP pertencem ao data source. A exclusão está integrada
à listagem completa em `/expenses`.
`ExpenseResponse`, em `expense/infrastructure/responses/expense_response.dart`,
faz parsing de `id`, `amount` inteiro, `description`, `occurred_on` e `category`.
Usa casts e `DateTime.parse`; categorias desconhecidas falham sem fallback para
`other`. `created_at` e os metadados JSON:API não integram a entidade atual.
`ExpenseResponseToEntity.toEntity()` retorna `Either<ErrorsEntity, ExpenseEntity>`
para preservar a falha de validação do VO quando o valor recebido não é positivo.
`IExpenseRepository.get({int pageSize = 30, String? pageLink, DateTime? from, DateTime? to, String? category})` retorna
`Future<GetRepositoryType>`, com `Either<ErrorsEntity, ExpensePageEntity>`.
O tamanho padrão é 30. O repository substitui valores menores ou iguais a zero
por 30 antes de chamar o data source; valores positivos são preservados.
Os limites civis opcionais `from` e `to` são delegados sem defaults, validação
ou normalização, inclusive quando somente um limite foi informado.
`category` também é delegada sem normalização. O data source envia valores
não nulos em `filter[category]`; o filtro explícito prevalece sobre a categoria
do link de paginação. Sem categoria explícita, preserva a do link, se houver.
`ExpensePageEntity` mantém uma cópia não modificável de `items`
e as continuações opacas anuláveis `next` e `prev`. A ordem da API é preservada,
sem ordenação, filtro de datas futuras ou truncamento local. Lista vazia é sucesso.
O repository converte todos os itens com `ExpenseResponse.toEntity()`;
qualquer falha de validação monetária invalida a página inteira, sem resultado parcial.

`IExpenseRemoteDataSource.get` recebe o tamanho efetivo obrigatório e a
continuação e os limites civis opcionais e retorna
`Either<ErrorsResponse, ExpensePageResponse>`. GET relativo `expenses` usa
`page[size]` em `Requests.query`. Sem `pageLink`, solicita a primeira página.
Os limites não nulos usam `filter[from]` e `filter[to]`, serializados pelo
helper `formatDateSerializer` em `yyyy-MM-dd` pelos componentes civis originais,
sem horário ou conversão de fuso. Sem limites, a consulta continua geral;
limites incompletos não recebem defaults e preservam a validação da API.
Para continuar, o consumidor repassa `next` ou `prev` sem interpretá-los.
O data source extrai os parâmetros da query do link, preservando valores
repetidos e sobrescrevendo `page[size]` com o tamanho solicitado. O
período explícito prevalece: limites não nulos sobrescrevem os do link e,
quando ao menos um limite é informado, `filter[year]`, `filter[month]` e
`filter[day]` herdados são removidos. Demais parâmetros de continuação são
preservados; sem intervalo explícito, os filtros do link permanecem intactos.
A origem e o caminho do link nunca são usados como destino HTTP: a chamada permanece no
endpoint relativo protegido da base configurada, inclusive para links absolutos.
Não presume nomes de cursor ou número de página. Links sem query ou com fragmento
retornam erro sem requisição. `ExpensePageResponse.fromJson` interpreta `data`
como lista, reutiliza `ExpenseResponse` por item e lê `links.next` e `links.prev`
como strings anuláveis. Parsing inválido e exceções usam o erro genérico de
`response<T>`; erros JSON:API são preservados. O DTO também copia sua lista.
O limite de seis despesas previsto para a Dashboard pertence ao consumidor;
o repository não conhece telas nem aplica esse limite globalmente. A seção de
recentes está integrada à Dashboard; a listagem completa usa rolagem infinita em
`ExpensesScreen`, na rota autenticada `/expenses`.

`GetExpensesCommand`, em
`expense/presentation/screens/expenses/commands/get_expenses_command.dart`,
recebe `IExpenseRepository` e delega a `get` os campos do record
`({int pageSize, String? pageLink, DateTime? from, DateTime? to, String? category})`, sem defaults
ou normalização dos limites. Seu `execute` começa em `null` e preserva
`Either<ErrorsEntity, ExpensePageEntity>` em `GetRepositoryType?`; lista vazia é
sucesso e `Left` permanece resultado de negócio. A primeira página usa
`pageSize: 6`, `pageLink: null` e o intervalo civil do mês selecionado na Dashboard.
A listagem geral e consumidores sem recorte continuam informando filtros nulos.
`ExpensesScreen` recebe `category` opcional junto a `period`. A rota aceita
records com `from`, `to`, `category` e callback opcional, preservando os records
anteriores sem categoria. O cabeçalho e o vazio identificam as lentes ativas.
O título “Despesas” e a descrição “Acompanhe todas as suas despesas.” permanecem
fixos. `ExpensesFiltersWidget` exibe categoria antes do período em `InputChip`
com ícone de fechar e ação nativa de remoção, 12 pixels abaixo da descrição.
Um `Wrap` usa espaçamentos de 8 pixels. A validação com texto ampliado e rótulos
longos permanece pendente, registrada na change arquivada. Cores, tipografia e formato de pílula vêm do tema, com
`BounceWidget` para pressão e alvo Material acessível. O corpo não possui ação.
As pílulas ficam fora de exclusões semânticas; a ação de remoção possui descrição
localizada e callbacks nulos durante operações incompatíveis. Sem filtros, não
há pílulas nem espaço adicional. Períodos mensais completos mostram mês e ano;
outros intervalos mostram os limites civis pelo formatter existente.
Previews da tela cobrem categoria + mês, somente mês, somente categoria,
entrada geral, loading, falha e vazio, além de categoria longa em largura
reduzida e texto ampliado nos temas claro/escuro, categoria futura e intervalo
não mensal. Os fakes locais filtram e paginam os dados sem rede ou storage;
esses cenários não substituem a validação dos contratos HTTP e da navegação real.
`ExpensesScreenStateMixin` inicializa `activeCategory` e `activePeriod` pelas
entradas da tela antes da primeira consulta. Rótulos, mensagens, consultas e
pertencimento após edição usam esse estado local. Rebuilds e troca isolada do
command preservam os filtros ativos; mudança efetiva nas entradas reaplica a
combinação inicial e reinicia a primeira página, invalidando operações anteriores.
Se o mesmo command ainda estiver consultando, a reconfiguração aguarda seu
término para consultar a combinação vigente sem execuções concorrentes.
O mixin expõe `removeCategoryFilter`, `removePeriodFilter` e `canRemoveFilters`
para a composição da interface. Cada handler remove somente seu filtro, sem
sinalizar alteração financeira, e reinicia a consulta com páginas de 20 itens,
continuação nula e filtros restantes. Essa troca limpa resultados, cursor e
feedback antes da consulta, preserva o controller e volta ao topo. Loading,
edição e confirmação/execução de exclusão bloqueiam remoções, que não são
enfileiradas. Falha mantém os filtros novos e a lista vazia; retry solicita a
primeira página dessa combinação. Respostas, finalizações e callbacks post-frame
obsoletos são ignorados pela identidade do command e revisão da consulta.
Paginação, refresh e retry reenviam mês e categoria; edição que devolva um item
fora de qualquer lente remove-o da lista, preservando rolagem e continuação.
Continuações repassam `next` ou `prev` sem interpretação. Cada execução substitui o resultado
da consulta anterior, sem acumular itens, definir limite por tela ou avançar
automaticamente. Durante a execução, o estado do `command_it` bloqueia novas
chamadas; após erro permite tentativa novamente. Exceções inesperadas são erros
observáveis do command. Implementa `ICommand` e descarta `execute` em `dispose`.
`expenseDependenciesModule` registra o command por factory (`add`), permitindo
instâncias independentes para Dashboard e a listagem completa. O consumidor
que obtiver uma instância é responsável por descartá-la ao encerrar seu lifecycle.

`expenseDependenciesModule` registra o data source e o repository como lazy
singletons pelos contratos, com o HTTP do core, e é composto por `appModule`.

`UpdateExpenseCommand`, em
`expense/presentation/screens/expense/commands/update_expense_command.dart`,
recebe `IExpenseRepository` e delega os campos do record
`({String id, int? cents, String? description, DateTime? occurredOn})` a `update` sem normalização,
validação ou defaults. Seu `execute` começa em `null` e preserva
`Either<ErrorsEntity, ExpenseEntity>` em `UpdateRepositoryType?`, incluindo os
erros de domínio e seus pointers. Cada execução substitui o resultado anterior;
o estado de execução bloqueia novas chamadas enquanto uma atualização está
pendente e permite nova tentativa após falha. Exceções inesperadas do repository
são erros observáveis do command. Implementa `ICommand` e descarta `execute` em
`dispose`. É registrado por factory em `expenseDependenciesModule`; cada consumidor
deve descartar sua instância. Não atualiza listas nem navega. É consumido pelo
modo de edição de `ExpenseScreen` na rota `/expense`.

`GetExpenseCommand`, em `screens/expense/commands/get_expense_command.dart`, recebe
um ID textual e delega a `IExpenseRepository.getById`, preservando o `Either`
em `GetByIdRepositoryType?`, inicialmente nulo. Bloqueia consultas simultâneas e
permite repetir após falha. Implementa `ICommand` e é registrado por factory em
`expenseDependenciesModule`; `ExpenseScreen` descarta a instância recebida.

`DeleteExpenseCommand`, em
`expense/presentation/screens/expenses/commands/delete_expense_command.dart`,
recebe `IExpenseRepository` e delega o ID sem normalização a `delete`.
Seu `execute` é `Command<String, DeleteRepositoryType?>`, inicialmente nulo,
preservando `Either<ErrorsEntity, bool>`, inclusive `Right(false)` e os erros
de domínio. Cada execução substitui o resultado anterior; o estado de execução
bloqueia novas chamadas enquanto uma exclusão está pendente e permite nova
tentativa após falha. Exceções inesperadas do repository são erros observáveis
do command. Implementa `ICommand` e descarta `execute` em `dispose`.
É registrado por factory em `expenseDependenciesModule`; cada consumidor deve
descartar sua instância. O command não remove itens da listagem nem navega.

`ExpensesScreen`, em `expense/presentation/screens/expenses/`, recebe instâncias
próprias de `GetExpensesCommand` e `DeleteExpenseCommand`, formatters e callback de retorno.
Recebe um `period` opcional do tipo `({DateTime from, DateTime to})`, transportado por
`/expenses`. “Ver tudo” recebe o mês selecionado da Dashboard e a rota calcula
seu intervalo civil completo. Sem argumento, a consulta permanece geral.
A listagem identifica mês e ano no header e na semântica, inclusive em loading,
falha e vazio; abertura, paginação, refresh e retry repassam os mesmos limites.
Usa `ExpensesAppBarWidget`, `HeaderWidget`, `ExpenseItemWidget` e
`ExpensesFeedbackWidget`, com `CommandBuilder` para acompanhar a consulta.
`ExpensesSkeletonWidget`, em `expense/presentation/widgets/`, é compartilhado
com a Dashboard e usa `Skeletonizer` sobre o layout real de `ExpenseItemWidget`.
A listagem mostra oito placeholders quando não há itens e três no rodapé
durante consultas com itens já carregados, preservando a lista visível e a
semântica “Carregando despesas”, sem expor textos fictícios à acessibilidade.
`ExpensesScreenStateMixin` mantém os itens acumulados, a continuação opaca `next`
e os estados locais de loading, vazio e falha. Solicita páginas de 20 itens ao
montar e ao restarem menos de 240 pixels de conteúdo; após uma página, também
verifica se é preciso preencher a área visível. A apresentação mantém ordem
decrescente pela data civil, preservando a ordem recebida entre itens do mesmo dia, e
`next: null` encerra a paginação. Não carrega automaticamente após uma falha.
Requisições simultâneas são bloqueadas. Atualização por gesto substitui os itens
somente após sucesso da primeira página. Falhas preservam os itens e a continuação;
“Tentar novamente” repete a operação que falhou, incluindo atualização.
O mixin descarta o controller e o command e ignora respostas após descarte ou
troca do command. A listagem não acessa repository, HTTP ou storage diretamente.
Uma única `SliverList.builder` apresenta cabeçalhos acessíveis por período:
Hoje, Esta semana (segunda-feira até ontem, somente no mês corrente), Este mês
(dias anteriores à semana corrente) e mês/ano para os outros meses e datas futuras.
Cada item pertence a um único grupo; grupos vazios não geram cabeçalhos.
`ExpensesGroupHeaderWidget` fica fora do conteúdo arrastável. Cada item construído
compara seu rótulo com o do item anterior em tempo constante, inclusive entre páginas,
sem agrupar toda a lista no build nem construir antecipadamente os itens de um mês.
Páginas cronológicas acrescentam itens no fim em tempo linear no tamanho da página;
itens fora de ordem usam busca binária para encontrar a posição de inserção.
Edição com data civil fora do intervalo remove o item da listagem filtrada;
edição dentro do intervalo reposiciona o item entre as despesas já carregadas.
As comparações usam ano, mês e dia com limites inclusivos, sem conversão de fuso.
Após edição, a verificação de paginação pode preencher a área visível, preservando
o controller de rolagem e a continuação. Exclusão do último
item de um grupo remove seu cabeçalho naturalmente. A continuação da API permanece opaca.
`ExpenseDismissibleWidget` envolve cada item da listagem, com chave pelo ID,
gesto para a esquerda, fundo `error`, lixeira `onError` e conteúdo com raio
`cornerRadius300`. O arraste é limitado a 88 pixels lógicos ou 25% da largura,
o que for menor. Soltar após 65% desse deslocamento retorna o item à posição
original com `SpringSimulation`, usando massa 0.5, damping 14 e stiffness 280,
como o retorno de `BounceWidget`. A confirmação abre assim que o spring começa,
em paralelo com o retorno do item;
arrastes curtos ou cancelados apenas retornam à posição original.
O mesmo componente aceita arraste da esquerda para a direita para editar: o item
se desloca para a direita e revela à esquerda um fundo `primaryContainer` com
lápis `onPrimaryContainer`. O limite e o threshold são os mesmos da exclusão;
soltar após o threshold inicia o spring de retorno e abre o editor em paralelo,
sem confirmação ou remoção do item. A direção da ação permanece fixada durante
o retorno para o overshoot do spring não exibir a ação oposta. Não há abertura
por toque simples. A ação de acessibilidade “Editar despesa” abre o mesmo editor.
Sem callback de edição, somente o arraste de exclusão fica disponível.
`ExpenseDismissibleWidgetStateMixin` concentra controller, gesto e lifecycle,
mantendo o item vivo durante o retorno e a confirmação, e descartando o controller.
Abre a confirmação compartilhada
`showConfirmationBottomSheetWidget`, também usada em exclusão da conta e logout.
Cancelar ou dispensar restaura o item sem requisição. A ação de acessibilidade
“Excluir despesa” abre a mesma confirmação. Somente confirmar executa o
`DeleteExpenseCommand`; a remoção ocorre após `Right(true)`, com toast de sucesso.
Erros e `Right(false)` preservam o item e mostram toast. O mixin coordena a
confirmação e a execução, bloqueia exclusões simultâneas e consultas enquanto a
exclusão está pendente, e bloqueia exclusões durante carregamento de páginas.
O item permanece na posição original durante a confirmação e a requisição,
com indicador de progresso durante a exclusão. Após sucesso, a verificação
de paginação pode preencher a área visível. O mixin descarta os dois commands e
ignora resultados obsoletos. As despesas recentes da Dashboard não possuem esse gesto.
`expenseRoutesModule`, em `expense_module.dart`, reúne `/expense` e `/expenses`
sob o path `/` e é composto por `appModule`. “Ver tudo” na Dashboard abre `/expenses`.

`CreateExpenseCommand`, em
`expense/presentation/screens/expense/commands/create_expense_command.dart`,
recebe `IExpenseRepository` e delega os campos do record
`({int cents, String description, DateTime? occurredOn})` a `create`.
Seu `execute` é `Command<({int cents, String description, DateTime? occurredOn}), CreateRepositoryType?>`, com valor
inicial `null`, preservando `Either<ErrorsEntity, ExpenseEntity>` para a
apresentação tratar sucesso e erros. O estado observável acompanha a execução e
impede chamadas adicionais enquanto uma criação está pendente; após erro permite
nova tentativa. Implementa `ICommand` e descarta `execute` em `dispose`. O command
é registrado por factory em `expenseDependenciesModule`, e é recebido por
`ExpenseScreen` e `ExpenseFormWidget` via construtor. A tela descarta a instância.

`ExpenseFormValidator`, em
`expense/presentation/screens/expense/validators/`, compõe
`ExpenseCentsValidation`, `ExpenseDescriptionValidation` e
`ExpenseDateValidation`. Seu `call` recebe `cents`, `description` e `occurredOn`
e retorna um record com `ValidationResult` para cada campo, validando todos em
uma chamada. Valor deve ser positivo em centavos inteiros. A descrição reutiliza
a regra existente: `trim()` e entre 2 e 128 caracteres Unicode. A data deve estar
selecionada no formulário, mesmo que o data source de criação ofereça `now()` como
default. Valores válidos são preservados, exceto pelo trim da descrição. Esses
validators e o agregador estão registrados em `expenseDependenciesModule` e são
consumidos pelo formulário. O validator não cria inputs,
não executa commands e não realiza navegação ou requisições.

`ExpenseScreen`, em `expense/presentation/screens/expense/`, mantém
a composição de `ExpenseAppBarWidget` e `ExpenseFormWidget` e recebe
commands, validator, formatters, ID opcional e callbacks de navegação.
A rota permanece `/expense`: sem argumento abre criação; com argumento `String`
abre edição. O record opcional `({bool returnToPrevious})` abre criação e define
o destino após sucesso por toque simples. A Dashboard envia
`(returnToPrevious: true)` ao empilhar o formulário; o callback fecha a rota
com `context.pop()`, preservando a instância da Dashboard e seu mês selecionado.
Sem argumento ou com `returnToPrevious: false`, o cadastro independente continua
navegando para `/dashboard`. Nenhuma entidade é passada pela rota para preencher o formulário.
`ExpenseScreenStateMixin` executa `GetExpenseCommand` ao abrir com ID e mantém
loading, entidade consultada e erros, ignorando respostas obsoletas. Durante a
consulta, `CommandBuilder` compõe `ExpenseSkeletonWidget` sobre o formulário real
com valores fictícios e interação bloqueada. A semântica anuncia “Carregando
despesa” e exclui os placeholders. Falhas exibem título, detalhes e “Tentar
novamente”; nenhum formulário editável vazio é apresentado. Sucesso preenche
descrição, centavos e data civil da API. A tela descarta seus commands de criação,
consulta e atualização. Os commands mantêm os nomes das operações; componentes,
mixins e validator usam o nome Expense, compartilhado pelos dois modos.
`ExpenseFormWidgetStateMixin`, em `screens/expense/mixins/`,
restrito a `State<ExpenseFormWidget>`,
possui o controller de descrição, centavos,
data civil inicial de hoje, erros por campo e handlers. Cria e descarta o
controller, registra e remove o listener do command, inclusive quando a instância
recebida muda. `selectAmount` e `selectDate` abrem `CentsCalculatorWidget` e
`ExpenseDatePickerWidget` por `showBottomSheetWidget`; cancelar preserva a entrada.
Seleções confirmadas atualizam somente o campo correspondente e limpam seu erro.
O submit valida todos os campos e, somente com resultados válidos, monta
o record de parâmetros com a descrição normalizada pelo validator e executa o
command. O estado local não contém valores monetários em `double` ou acesso a
repository, rede ou storage.
`CommandBuilder` controla o loading: campos e botão ficam desabilitados durante
o cadastro, e os handlers também impedem execução duplicada e abertura simultânea
de pickers. Erros com pointers de `amount`, `description` e `occurred_on` são
agrupados nos respectivos campos; demais erros e exceções recebem toast. O
formulário preserva os dados para uma nova tentativa.
O envio usa `HoldButtonWidget`: `onTap` cadastra e, somente em `Right`, exibe o
toast de sucesso e chama `onExpenseCreated`, cujo destino é injetado pela rota:
retorno à Dashboard existente quando iniciado por ela ou navegação para
`/dashboard` no acesso independente. Cancelamento fecha o formulário sem
cadastro; ao retornar à Dashboard existente, as três seções são recarregadas no
mês preservado. A data inicial continua sendo hoje, mesmo em um mês histórico.
`onHoldComplete` usa a mesma validação e command, mas após
sucesso exibe o toast, limpa descrição, valor e erros, redefine a data para hoje
e permanece na tela. A escolha pertence ao estado local de apresentação e não
altera os parâmetros de criação ou o command. Falhas em qualquer modo preservam o
formulário; cancelar o hold antes de completá-lo não cadastra. Voltar não executa
cadastro.

Na edição, o header mostra “Editar gasto” e “Atualize as informações do seu
gasto.”. A data é preenchida e pode ser alterada pelo mesmo picker do cadastro.
O botão `ElevatedButtonWidget` mostra “Atualizar” e habilita
somente com alteração válida de centavos, descrição ou data. Comparações de descrição
consideram o trim e as de data comparam somente ano, mês e dia;
o envio usa `UpdateExpenseCommand` com o ID solicitado e
somente os atributos alterados, mantendo os demais nulos. Não há hold na edição.
`CommandBuilder` acompanha o command ativo e bloqueia os campos e o envio durante
a operação. Falhas preservam a entrada e usam pointers ou toast. Sucesso mostra
“Gasto atualizado” e devolve a entidade por `context.pop`, pelo callback da rota.
Arrastar um item de `ExpensesScreen` para a direita abre `/expense` com o ID. Ao retornar com
sucesso, a listagem substitui somente o item correspondente, reposicionando-o
quando a data civil muda e preservando a posição quando somente valor ou descrição mudam.
Mantém rolagem e continuações da paginação. Cancelar não altera a lista. O mixin bloqueia
edição duplicada, consultas e exclusões enquanto o editor está aberto.
Ao retornar da listagem completa com alterações confirmadas, Dashboard consulta novamente suas despesas
recentes, refletindo as edições e exclusões realizadas. O callback de “Ver tudo”
em `DashboardScreen` é `Future<bool> Function(DateTime month)?`, assíncrono para
transportar o mês selecionado e aguardar o retorno da navegação. No retorno,
as três seções são recarregadas no mês preservado somente quando o resultado é `true`.
O catálogo de previews de Expense inclui cadastro, edição e skeleton do formulário,
com commands descartados por `PreviewResourceWidget` e repository fake sem rede.

`user` é o bounded context dos dados do usuário. `UserEntity`, em
`domain/entities/user_entity.dart`, é imutável e possui
`id`, `name`, `email` e `status` como `String` e `avatar` como `String?`, sem datas.
O identificador preserva a representação textual da API;
`status` preserva o valor informado, pois o contrato disponível não define todos
os estados possíveis. O envelope JSON:API (`data`, `type` e `links`) não faz
parte da entidade. `IUserRepository`, em
`domain/repositories/interface_user_repository.dart`, define `getById()`,
`delete()` e `update({String? name, String? avatar})`. As três operações obtêm o ID
persistido pelo data source local. Os typedefs `GetByIdRepositoryType`
e `UpdateRepositoryType` representam `Either<ErrorsEntity, UserEntity>`;
`DeleteRepositoryType` representa `Either<ErrorsEntity, bool>`. `update` permite
atualizar `name` e `avatar`, opcionais; campos nulos são omitidos do payload.
Em cada operação, `UserRepository` lê o ID pelo data source local e chama
o método correspondente de `IUserRemoteDataSource` com esse ID explícito.
ID ausente, vazio ou composto apenas de espaços retorna o erro de domínio
“Usuário não identificado”, sem chamada remota. O ID não é normalizado nem
substituído; a autorização continua sendo validada pela API através do token.
Falhas de leitura local retornam `ErrorsEntity.unknown()` e erros remotos são
preservados. A edição de nome consome essa operação por `UpdateUserCommand`.
`IUserRemoteDataSource` e `UserRemoteDataSource`, em
`infrastructure/remoto/user_remote_data_source.dart`, usam `IHttpClient` do core
para GET, PATCH e DELETE de `users/<id>`. GET e PATCH retornam
`Either<ErrorsResponse, UserResponse>`; DELETE retorna
`Either<ErrorsResponse, bool>`, com `true` em 204 e `false` para outros status
de sucesso. PATCH envia `data.type: users`, `data.id` e
somente os atributos informados (`name` e `avatar`) em `data.attributes`. Erros JSON:API são preservados;
respostas malformadas e exceções inesperadas recebem erro genérico.
`UserResponse.fromJson` extrai os campos do modelo com casts Dart,
e `UserResponseToEntity.toEntity()` os converte para `UserEntity`. As datas
e os metadados JSON:API não são incorporados ao modelo atual. O id devolvido
pela API é preservado, sem substituição pelo id solicitado. `UserRepository`, em
`application/repositories/user_repository.dart`, implementa `IUserRepository` e recebe
`IUserRemoteDataSource` e `IUserLocalDataSource`. Delega os parâmetros, converte `ErrorsResponse` em
`ErrorsEntity` e `UserResponse` em `UserEntity`, preserva o booleano da exclusão
e traduz exceções inesperadas em `ErrorsEntity.unknown()`. `userDependenciesModule`,
em `user_module.dart`, registra o repository e os dois data sources como lazy
singletons pelos contratos e é composto por `appModule`, sem `path`.
`userRoutesModule` registra `/user`, acessível por “Dados pessoais” em Settings.
`UserScreen` lista nome e e-mail em `MenuCardWidget`, reutiliza a app bar de
Settings e exibe `DangerButtonWidget` com “Excluir conta” no rodapé. Nome abre
`/user/edit`, passando o nome exibido como argumento; e-mail fica desativado,
sem chevron. `UserCommand`, em `presentation/screens/user/commands/`, consulta `IUserRepository.getById()`
e preserva `Either<ErrorsEntity, UserEntity>`. A tela recebe esse command por
construtor e usa `CommandBuilder` para consultar a API ao montar, renderizar
loading com `UserSkeletonWidget`, nome e e-mail reais e erros com botão “Tentar
novamente”. O skeleton reutiliza o layout de avatar e menu com placeholders
visuais e `Skeletonizer`, que bloqueia interação durante o carregamento.
`UserScreenStateMixin`, restrito a `State<UserScreen>`, inicia a consulta,
encapsula recarregamento, edição de nome e descrição dos erros; a screen mantém
a composição visual. O nome identifica o avatar na semântica; o desenho usa a semente.
`userDependenciesModule` registra `UserCommand` por factory, fornecendo instâncias
independentes para User e Dashboard. Os mixins dessas telas descartam suas instâncias
de `UserCommand`, inclusive quando substituídas.
“Excluir conta” abre a bottom sheet de confirmação
com título “Deseja apagar sua conta?”, aviso de ação irreversível e botões
“Voltar” e “Confirmar”, seguindo o layout do logout. O handler fica em
`UserScreenStateMixin`; somente a confirmação executa `DeleteUserCommand`,
em `presentation/screens/user/commands/`, que delega a `IUserRepository.delete()`
e preserva `Either<ErrorsEntity, bool>`. A tela recebe o command por construtor,
registrado como lazy singleton em `userRoutesModule`, com descarte pelo módulo.
`CommandBuilder` mostra loading e desabilita o botão durante a exclusão; o handler
também impede execução duplicada. O mixin registra e remove o listener de
resultados e exibe toast para erros da API, exceções e `Right(false)`, permitindo
nova tentativa. Em `Right(true)`, o repository já aguardou a limpeza do storage;
a observação da sessão por `AppWidget` redireciona de `/user` para `/welcome`,
sem navegação adicional na tela.
Logout e exclusão reutilizam `showConfirmationBottomSheetWidget` do core,
que recebe `title`, `subtitle` e `onConfirm`, com `confirmLabel` opcional
(“Confirmar” por padrão e “Sair” no logout). Título e subtítulo usam o scaffold
compartilhado; `ConfirmationBottomSheetWidget` compõe os botões. O callback só
é chamado após fechar a sheet com confirmação e enquanto o contexto
proprietário estiver montado; cancelar ou dispensar não executa a ação.
Acima da lista, `UserAvatarWidget` mostra um avatar quadrado centralizado com
cantos arredondados (`cornerRadius300`) e botão “Gerar outro avatar” com ícone de
refresh. `GeneratedUserAvatarWidget`, em `user/presentation/widgets/`, encapsula
`AnimatedBoringAvatar` de `flutter_boring_avatars` com estilo `marble`, transição
de 300 ms e paleta fixa dos tokens do tema claro, compartilhada nos dois temas.
Perfil e Dashboard usam a mesma semente, com fallback `cordato-user-<id>` quando
`avatar` estiver ausente ou nulo. Alterar o nome não altera o desenho.
`UserScreenStateMixin` gera sementes aleatórias locais de 32 caracteres hexadecimais
e mantém a escolha temporária. Cada regeneração reinicia um `Timer` de dois
segundos; somente após esse intervalo sem nova regeneração a última seed é
enviada automaticamente. Não há botão “Salvar avatar”. O timer é cancelado no
descarte da tela, na troca dos commands e ao confirmar exclusão da conta,
impedindo envios pendentes fora desse lifecycle. Sair antes do prazo descarta
a escolha ainda não enviada. `UpdateAvatarCommand`, em
`screens/user/commands/`, recebe `String`, delega a `update(avatar: ...)`, preserva
`Either` e é registrado por factory em `userRoutesModule`, com descarte pela tela.
`CommandBuilder` preserva o formulário durante o envio, desabilitando geração
e edição de nome. Sucesso usa o usuário retornado e
exibe toast; falhas preservam a escolha e exibem erro, sem retries automáticos.
Gerar outra imagem inicia um novo prazo e uma nova tentativa. A tela só confirma sucesso se a resposta
contiver a semente enviada, evitando anunciar persistência quando a API ignora
o atributo. O backend aceita `avatar` em PATCH e o retorna em GET
e PATCH; a implementação Flutter não provisiona esse campo no servidor.
Previews de User em `presentation/previews/screens/` usam repository fake sem
rede para experimentar geração, debounce de dois segundos, salvamento automático
e erro, nos temas claro e escuro.
`EditUserScreen` centraliza título “Nome”, descrição “Atualize o seu nome de
exibição.” e campo na área acima do botão “Atualizar”, com rolagem e adaptação
ao teclado, seguindo o layout da autenticação. Recebe nome inicial,
`UpdateUserCommand` e callbacks de navegação por construtor.
`EditUserScreenStateMixin` mantém a entrada e o erro do campo, registra e remove
o listener do command e trata o resultado. A tela usa `CommandBuilder` para
loading e desabilita campo e envio durante a requisição. O botão só habilita
para nome não vazio após `trim()` e diferente do inicial; o nome é enviado sem
espaços nas extremidades. Erros com pointer `/data/attributes/name` aparecem no
campo e os demais por toast. Sucesso exibe toast e retorna o `UserEntity` pela
navegação; `UserScreen` executa novamente `UserCommand` para consultar nome,
e-mail e avatar atualizados. Reabrir `/user` também realiza uma nova consulta.
`UpdateUserCommand`, em `edit_user/commands/`, delega a `update`,
preserva `Either` e implementa `ICommand`; `userRoutesModule` o registra como lazy
singleton, com descarte pelo módulo. O contexto não realiza autenticação ou leitura
de sessão. `IUserLocalDataSource` e `UserLocalDataSource` ficam no mesmo arquivo,
`infrastructure/local/user_local_data_source.dart`; a implementação recebe
`IStorageClient` e delega `clear()` para limpar todo o storage seguro.
Também oferece `getId()`, que lê `StorageKeyEnum.userId` e preserva o resultado
anulável do storage. Authentication grava esse ID no sign-in; User o lê pelo
storage do core, sem dependência entre as duas features e sem ler o token.
`UserRepository.delete` lê o ID persistido, aguarda a exclusão remota e, somente em `Right(true)`
(status 204), aguarda a limpeza local antes de retornar sucesso. `Left` e
`Right(false)` não acionam a limpeza. Uma falha local retorna
`ErrorsEntity.unknown()`, mesmo que a exclusão remota já tenha sido confirmada.
O data source remoto acessa somente HTTP; o local propaga falhas ao repository.

`dashboard` é uma feature de apresentação e composição, com nome e semente do
avatar consultados por `UserCommand` e até seis despesas consultadas por
`GetExpensesCommand`. O botão flutuante da Dashboard usa `FloatingActionButton`
com `BounceWidget` e abre diretamente o cadastro em `/expense`, sem menu
expansível. Ao retornar, a Dashboard recarrega despesas, insights e métricas.
`settings` é uma feature
de apresentação que consome o logout de Authentication. `authentication`
encapsula sign-in, sign-up, reenvio e
confirmação de e-mail via API JSON:API; não recria o contexto `identity` nem
gera sessão ao cadastrar ou confirmar o e-mail. `chat` permanece fora de escopo.
`session` encapsula exclusivamente leitura e observação da presença do token;
a entrada e os redirecionamentos globais pertencem à composição do app.
`root` é a feature de apresentação dessa composição global, sem domínio de
negócio ou módulo próprio; `main.dart` e `app_module.dart` conectam seus widgets.

Invariantes do produto:

- valores monetários são representados em centavos inteiros e somente em BRL;
- gastos não referenciam orçamentos; o pertencimento é derivado pela data;
- orçamentos vivos do mesmo dono não podem sobrepor dias;
- participar de uma família nunca concede escrita nos dados financeiros de outro membro;
- sair ou encerrar uma família preserva os dados individuais;
- visões de família e insights são recalculados, não persistidos como dados-fonte.

Contextos proprietários não dependem de lentes. Quando implementados, `family`
e `insight` só poderão ler contextos financeiros por contratos próprios, com
adapters concretos na borda de infrastructure. Essas são decisões para as
features futuras, não funcionalidades ou autorização já implementadas no app.
O teste `test/architecture/bounded_context_dependencies_test.dart` verifica
parte dessas direções de import e do isolamento entre camadas, com as lacunas
descritas em [Testes E Verificação](#testes-e-verificação).

## Estrutura E Camadas

```text
lib/
  main.dart
  app_module.dart
  features/
    root/
      presentation/
        widgets/app_widget.dart
        mixins/app_widget_state_mixin.dart
        screens/app/
          app_screen.dart
          mixins/app_screen_state_mixin.dart
    core/
    session/
      application/
        repositories/session_repository.dart
    authentication/
      application/
        repositories/authentication_repository.dart
    user/
      user_module.dart
      domain/
        entities/user_entity.dart
        repositories/interface_user_repository.dart
      application/
        repositories/user_repository.dart
      infrastructure/
        local/user_local_data_source.dart
        remoto/user_remote_data_source.dart
        responses/user_response.dart
    welcome/
    dashboard/
    expense/
      application/
        repositories/expense_repository.dart
      presentation/
        screens/expense/
          expense_screen.dart
          commands/create_expense_command.dart
          commands/update_expense_command.dart
          commands/get_expense_command.dart
          mixins/expense_form_widget_state_mixin.dart
          mixins/expense_screen_state_mixin.dart
          validators/
        screens/expenses/
          expenses_screen.dart
          commands/get_expenses_command.dart
          mixins/expenses_screen_state_mixin.dart
          widgets/
        widgets/expense_item_widget.dart
        widgets/expenses_skeleton_widget.dart
    settings/
```

Cada feature pode conter `domain`, `application`, `infrastructure` e `presentation`.
`application/repositories/` contém as implementações dos contratos do domínio em
Authentication, User, Session e Expense. `application/data/` contém tipos Dart
puros de entrada quando necessários; não contém data sources ou DTOs HTTP.
Expense usa parâmetros nomeados de criação e não possui um wrapper de input.
Os testes espelham esses caminhos em `test/features/<feature>/application/`.
Crie somente os diretórios que tiverem implementações reais.

| Localização | Responsabilidade |
|---|---|
| `domain/entities`, `domain/value_objects`, `domain/enums` | Modelos e regras independentes de Flutter e SDKs |
| `domain/repositories` | Contratos consumidos pelos commands |
| `application/data` | Inputs Dart puros e imutáveis, sem parsing HTTP |
| `application/repositories` | Coordenação dos data sources e conversão de resultados para domínio |
| `infrastructure/local`, `infrastructure/remoto` | Interfaces e implementações de data source, com acesso a storage ou HTTP |
| `infrastructure/responses` | Parsing de respostas e conversão de DTOs |
| `presentation/commands`, `presentation/screens`, `presentation/widgets` | Operações observáveis, estado de UI e composição visual |
| `<feature>_module.dart` | Composição de dependências e rotas reais da feature |

`core` contém capacidades compartilhadas, como tema, formatação monetária,
widgets, animações, imagens e storage; não deve receber regras de uma
feature.

`SwitcherAnimation` e `SwitcherSizeAnimation`, em
`core/presentation/animations/animation.dart`, identificam cada transição por
`ObjectKey(animation)`. Isso mantém únicas as chaves das transições simultâneas
no `AnimatedSwitcher`, inclusive ao alternar rapidamente entre conteúdo e
carregamento dos botões. As chaves dos filhos continuam identificando o estado
visual; a transição compartilhada preserva sua duração de 300 milissegundos.

`HeaderWidget`, em `core/presentation/widgets/header_widget.dart`, concentra o
cabeçalho de tela com `title` e `description` obrigatórios, semântica de heading,
tipografia e cores do tema e espaçamento de 6 pixels. Sign-in, sign-up, reenvio
de e-mail, gasto, Settings, dados pessoais e edição de nome o compõem diretamente,
sem wrappers dedicados por feature para essa mesma estrutura.

Cards informativos compartilhados ficam em `core/presentation/widgets/cards/`:

- `IformationCardContentWidget`: ícone decorativo à esquerda por
  `BackgroundIconWidget`, título e descrição com cores e tipografia do tema.
  Recebe ícone e suas duas cores explicitamente, sem interpretar tipos ou
  categorias de features. Os textos podem crescer sem truncamento; o consumidor
  deve fornecer uma largura limitada.
- `IformationCardWidget`: compõe esse conteúdo em um `Card` de superfície,
  com raio `cornerRadius100`, padding de 12 pixels e semântica informativa.
  Não recebe callback nem elemento à direita e não possui animação de toque.

`SettingsInvitePartnerWidget` reutiliza somente o conteúdo compartilhado,
mantendo sua própria composição de card, seta, callback, `BounceWidget` e
semântica de botão. Os cards informativos e o convite possuem previews próprios;
a Dashboard usa o card informativo por `InsightCardWidget` sem adicionar interação.

Menus compartilhados ficam em `core/presentation/widgets/menu/`:

- `MenuSectionWidget`: título em caixa alta com semântica de heading e conteúdo
  livre em `child`; o espaçamento padrão é 8 pixels.
- `MenuCardWidget`: contorno e cantos arredondados do tema, fundo transparente
  por padrão, padding horizontal de 16 pixels por item e divisórias somente
  entre itens. Aceita widgets livres, padding, cor de fundo e divisórias opcionais.
- `MenuItemWidget`: label, ícone ou `leading` customizado, valor textual opcional,
  `trailing` livre e chevron configurável. Reutiliza `BounceWidget` quando há
  callback e mantém semântica de botão, valor e estado habilitado. Altura,
  espaçamento e opacidade desativada são configuráveis; os padrões preservam
  Settings (56 pixels, 16 pixels e sem alteração de opacidade).

Settings e User compõem esses componentes diretamente. O badge PREMIUM continua
pertencendo a Settings e é passado como `trailing`, sem acoplar o core à feature.
User mantém itens de 64 pixels, valores à direita e e-mail desativado sem chevron.

Direções de dependência aprovadas:

- `presentation` consome contratos de `domain`; não importa repositories de
  `application/repositories`, data sources ou clients de `infrastructure`;
- `application/repositories` implementa contratos de `domain` e consome interfaces de data source e
  DTOs de `infrastructure`, sem acessar SDKs diretamente;
- `domain` é independente de frameworks, implementações de `application/repositories`,
  `infrastructure` e `presentation`; os contratos de Expense recebem parâmetros
  primitivos diretamente;
- `authentication` e `session` não importam uma à outra: comunicam-se pela
  escrita e observação de `StorageKeyEnum.opaqueToken` no storage do core;
- Settings recebe `LogoutCommand` de Authentication como dependência de
  apresentação; o command conhece somente `IAuthenticationRepository`;
- Dashboard recebe uma instância de `UserCommand` de User como dependência de
  apresentação, sem acessar repository, HTTP ou storage diretamente;
- Dashboard recebe uma instância própria de `GetExpensesCommand` de Expense e
  reutiliza `ExpenseItemWidget`, sem acessar repository ou data source diretamente;
- `root` compõe a apresentação global e consome `SessionCommand`, sem assumir
  a escrita do token ou as operações de autenticação;
- `expense` e `budget` não importam contextos financeiros irmãos; `family`
  poderá ler ambos e `insight` poderá ler os três por contratos próprios com
  adapters de infrastructure. Contextos proprietários não dependem das lentes.

Responsabilidades e implementações atuais:

- `domain` define entidades, failures e contratos sem Flutter ou SDKs.
- `application/repositories` implementa contratos de repository do domínio e converte resultados
  dos data sources em `Either`. Na autenticação, importa as interfaces de data
  source e response DTOs definidos em `infrastructure`.
- `infrastructure` define data sources que acessam HTTP, storage ou plugins;
  a apresentação não importa essas implementações.
- `core/infrastructure/clients/http` oferece `IHttpClient`/`HttpClient`,
  `Requests` e `Responses` (`Either<HttpResponse, HttpResponse>`). Cada
  `HttpResponse` contém status HTTP e corpo em mapa; falhas de transporte
  retornam `Left` com status `0` e erro genérico. O `coreDependenciesModule`
  registra o Dio com `BASE_URL` e os interceptors compartilhados.
- A função genérica `response<T>`, em
  `core/infrastructure/clients/http/responses/responses.dart`, é compartilhada
  pelos data sources remotos de Authentication, User e Expense. Recebe `execute`, que
  retorna `Future<Responses>`, e `from`, que converte o `HttpResponse` de sucesso
  em `T` com acesso a corpo e status. Retorna `Either<ErrorsResponse, T>`,
  preservando erros JSON:API e traduzindo exceções de execução, parsing ou
  conversão em erro genérico. O tratamento de status de confirmação de e-mail
  continua específico de Authentication.
- `IStorageClient.watch(key: ...)` adapta `FlutterSecureStorage.registerListener`
  para uma stream por chave; cancela o registro em `unregisterListener` quando
  a subscription termina. Escrita emite o novo valor, remoção e limpeza emitem
  `null`. A stream não emite o valor inicial; use `read` para obtê-lo. O plugin
  notifica alterações feitas por suas instâncias no mesmo isolate, não mudanças
  externas no storage nativo.
- `AuthenticationRemoteDataSource` em `infrastructure/remoto/` monta as
  requisições JSON:API e usa `IHttpClient` do core diretamente, sem client de
  autenticação intermediário. Sign-in, sign-up e reenvio usam endpoints
  relativos à base `/api/`; a confirmação envia a URL assinada original no GET.
  `SignInResponse.fromJson` e `SignUpResponse.fromJson` em
  `infrastructure/responses/` extraem os campos do mapa usando casts Dart e
  `DateTime.parse`, sem dependência de parser externo. O data source converte
  os erros JSON:API em `ErrorsResponse`; lista de erros vazia, corpo inválido
  ou exceção inesperada resultam em erro genérico. Na confirmação, converte o
  status HTTP em `int?`, usando `null` para falhas de transporte.
- `AuthenticationLocalDataSource` em `infrastructure/local/` grava o token
  e o ID do usuário usando `IStorageClient`, sem expor o plugin ao repository.
  `saveToken(token)` escreve em `StorageKeyEnum.opaqueToken`
  (`@trocado.opaque_token`); `saveUserId(userId)` escreve em `StorageKeyEnum.userId`
  (`@trocado.user_id`). `clear()` delega a `IStorageClient.clear()`, que executa
  `FlutterSecureStorage.deleteAll()` no logout.
  No sign-in, `SignInResponse.userId` vem de
  `data.relationships.user.data.id`; `data.id` identifica o token de acesso.
- `session` é o contexto de leitura da presença do token: `SessionLocalDataSource`
  lê `StorageKeyEnum.opaqueToken` e observa alterações via `IStorageClient`;
  `SessionRepository` expõe `loadSession()` para a leitura inicial e o getter
  `sessionChanges` para alterações posteriores, por contrato próprio.
  `SessionCommand` combina a leitura com a stream, ignorando um resultado inicial
  obsoleto quando uma mudança chega durante a leitura. Ele começa em `null`,
  publica `true` ou `false` e cancela a inscrição no `dispose`. `authentication`
  continua responsável por gravar o token; nenhum dos dois contextos importa
  a implementação do outro.
- `core/domain/entities/errors_entity.dart` representa uma lista de erros com
  título, detalhe, status e apontamento de campo sem depender do cliente HTTP.
  A extensão `ErrorsResponse.toEntity()` no core infrastructure converte a lista
  completa, com erro genérico quando a resposta não contém itens.
- `AuthenticationRepository.signIn` converte `SignInResponse` em `SessionEntity`
  com `toEntity()` e aguarda as gravações de token e ID pelo data source local
  com `Future.wait` antes de retornar sucesso. Falhas de gravação retornam erro
  genérico; erros da API não solicitam nenhuma gravação. As duas escritas não
  são uma transação e não há rollback de uma escrita já concluída quando a
  outra falha. `signUp` retorna sucesso após o cadastro. Sign-in,
  sign-up e reenvio retornam `Either<ErrorsEntity, R>`: os erros JSON:API são
  preservados no `Left` e falhas inesperadas usam um erro genérico.
  `SignInCommand` e `SignUpCommand` entregam esse `Either` como resultado ao
  `command_it`, para a apresentação decidir como exibir os erros.
  As duas rotas retornam o envelope JSON:API `errors` com itens contendo
  `title`, `detail`, `status` e, para erros de campo, `source.pointer`.
  A apresentação usa `status` e `source.pointer` para mostrar erros de e-mail
  e senha nos respectivos campos (422, além do 409 de e-mail no cadastro);
  os demais erros são apresentados em toast, incluindo múltiplos itens.
  `resendEmail` envia o e-mail cadastrado para
  `authentication/email-verification/resend` com tipo `email-verifications`;
  a resposta 202 sem corpo é sucesso. O data source e repository preservam
  erros JSON:API em `Either<ErrorsEntity, bool>`.
- `IAuthenticationRepository.logout()` retorna `Either<ErrorsEntity, bool>`.
  O repository aguarda a revogação remota e, somente após sucesso, aguarda
  `IAuthenticationLocalDataSource.clear()` antes de retornar `Right(true)`.
  `Right(false)` remoto é preservado sem limpeza local.
  Erros remotos são convertidos de `ErrorsResponse` para `ErrorsEntity`, sem
  solicitar limpeza local; exceções remotas ou de persistência retornam
  `Left(ErrorsEntity.unknown())`. O interceptor mantém sua regra existente de
  remoção do token enviado após 401 de endpoint protegido.
- `presentation` contém screens, widgets, validators, estado local e commands.
- A confirmação de e-mail por link tem rota própria `/authentication/confirm-email`:
  `CallbackScreen` exibe o estado de espera e inicia automaticamente uma
  confirmação por link recebido. Se a URL estiver ausente, a screen apresenta
  link inválido sem executar o command. `CallbackCommand` recebe uma
  `String` não nula e chama `IAuthenticationRepository.confirmEmail`, que
  rejeita uma string vazia e encaminha as demais URLs ao
  `IAuthenticationRemoteDataSource` sem validar host, caminho ou assinatura.
  A requisição não envia Bearer e usa as opções padrão do cliente HTTP.
  O resultado 204, 403 ou falha de
  conexão aparece em toast e a tela reconstrói a pilha como Welcome → Sign In;
  Voltar no sign-in retorna a Welcome mesmo após um deep link com o app fechado.
  A API não cria sessão nesse fluxo.

O fluxo da autenticação é:

```text
Screen/widget -> Command -> IAuthenticationRepository -> AuthenticationRepository
  -> IAuthenticationRemoteDataSource -> AuthenticationRemoteDataSource
     -> IHttpClient (core) -> API
  -> IAuthenticationLocalDataSource -> AuthenticationLocalDataSource
     -> IStorageClient (core) [após sign-in bem-sucedido]
```

Commands usam `command_it` e implementam `ICommand` quando precisam de descarte.
Em Expense, cada fluxo reúne seus commands, mixins e validators sob a tela
proprietária em `presentation/screens/`. `GetExpensesCommand` pertence a
`screens/expenses/commands/`, mesmo sendo consumido também pela Dashboard;
o compartilhamento mantém o registro por factory em `expenseDependenciesModule`.
Commands específicos de uma tela ficam em `presentation/screens/<tela>/commands/`,
junto da screen, com testes no caminho espelhado. O command do fluxo principal
usa o nome-base da tela (`CallbackScreen` → `CallbackCommand`); operações
específicas usam o nome da ação. `SessionCommand` permanece em
`session/presentation/commands/` por observar a sessão independentemente
de uma tela. `LogoutCommand` pertence a
`authentication/presentation/commands/`, pois a feature não tem uma tela
proprietária do logout; Settings o recebe por construtor. `ResendEmailScreen`
e `ResendEmailCommand` vivem em `screens/resend_email/`, preservando a rota
`/authentication/confirm`. Renomeações de tela e command atualizam arquivo, tipo, imports,
registro no módulo, testes e documentação sem mudar a rota por consequência.
O sign-in entrega `Either` à apresentação para tratar os erros da API; commands
de outras features podem expor falhas como erros observáveis. Estado
efêmero pertence à screen ou widget. Quando lifecycle, controllers e handlers
prejudicarem a leitura, use um mixin específico em `presentation/mixins/` ou
no diretório da própria tela, restrito ao `State` correspondente e responsável
por seu `dispose`.

Estado efêmero usa `StatefulWidget` e `setState`; operações assíncronas usam
`command_it`. Não há Bloc, Provider, Riverpod ou store global no app.
`listen_it` está declarado, mas sem uso direto. Listeners e recursos de UI
pertencem ao lifecycle do widget; commands registrados como dependências
descartáveis implementam `ICommand`.

Para `StatelessWidget`, lógica de apresentação sem estado pode ser extraída
para `<Widget>Mixin on StatelessWidget`, em `presentation/mixins/` da feature.
O widget mantém a composição visual e o mixin concentra cálculos e decisões
visuais, sem estado mutável, lifecycle, operações assíncronas ou acesso a
repositories e SDKs. Regras de negócio permanecem no domínio. O padrão é
específico ao widget proprietário; `UserNameWidgetMixin` isola a inicial do
nome e a saudação de `UserNameWidget`.

## Padrão Dart De Construção

O baseline do projeto usa Dart 3.13 ou superior e primary constructors como
padrão para declarações elegíveis em todas as camadas. A sintaxe é uma decisão
estrutural do código e não altera a direção das dependências: presentation
continua dependendo de contratos do domínio, e SDKs continuam restritos à borda
de infrastructure.

Use primary constructor quando houver um único caminho generativo principal e
os parâmetros declararem estado, derivarem campos ou forem encaminhados para
`super`. Isso inclui widgets que recebem somente `super.key`, enums com payload,
failures, entidades com construção controlada, estados imutáveis, repositories,
data sources, clients e commands cuja inicialização permaneça clara.

Campos imutáveis induzidos usam tipo explícito e `final`. Parâmetros transitórios,
como um repository usado apenas para criar um `Command`, mantêm o tipo explícito
sem `final` ou `var`. Preserve `const`, nomes e visibilidade de construtores,
parâmetros, defaults, nulabilidade, `required`, super parameters, factories,
redirects e tear-offs `Type.new`.

Construtores tradicionais permanecem somente quando primary syntax não remove
boilerplate ou torna construção e lifecycle menos claros. Os casos esperados são
construtores vazios sem estado, múltiplos caminhos generativos, bodies com ordem
de inicialização relevante e redirects que centralizam lifecycle. Interfaces,
mixins comuns, extensões, classes `State` e mocks não recebem construtor explícito
apenas por uniformidade.

Daqui para frente, tipos novos elegíveis devem nascer com primary constructor.
Uma exceção nova precisa ser justificável na revisão pelo comportamento de
construção, não por preferência de estilo. Conversões permanecem estritamente
sintáticas e não podem alterar contratos, responsabilidades, regras de domínio
ou acesso entre camadas. A matriz operacional e os exemplos canônicos estão em
[`AGENTS.md`](AGENTS.md#primary-constructors).

### Comentários No Código

Não adicione comentários de linha, bloco ou documentação ao código, incluindo
`//`, `/* ... */`, `///` e `/** ... */`. A intenção deve ser expressa por nomes,
tipos, organização e testes. Explicações, decisões e contratos ficam em Markdown.
Comentários existentes fora do escopo da mudança devem ser preservados; a regra
não solicita uma remoção indiscriminada do legado.

## Inicialização, Módulos E Rotas

`main.dart` inicializa Flutter e Modular com `/` como rota inicial para
uma abertura normal. `AppWidget` instala temas, localização `pt_BR`, router e
provider de toast; observa `SessionCommand` para navegar ao dashboard após o
sign-in e voltar à welcome após a remoção do token em uma rota protegida.
O command é recebido pelo construtor de `AppWidget` e resolvido por DI em um
`Builder` dentro de `ModularApp`, em `main.dart`.
`AppWidgetStateMixin`, em `lib/features/root/presentation/mixins/`, concentra
o lifecycle do listener e os redirecionamentos de sessão, restrito a `State<AppWidget>`;
o State mantém apenas a composição visual. As consultas à rota e a navegação
global usam `navigatorKey.currentContext`, abaixo do router; o contexto do
próprio `AppWidget` fica acima de `MaterialApp.router` e não oferece o estado
de rota do Modular.
`AppScreen`, em `lib/features/root/presentation/screens/app/`, mostra a logo
enquanto lê o token e navega para dashboard ou welcome; erro de leitura também leva à
welcome. `AppScreenStateMixin` concentra a leitura, o listener e a decisão
única de rota, recebendo a navegação por callbacks. `session` não possui tela
nem módulo de rotas. Não há rota `/splash`.

Os listeners de sessão de `AppScreenStateMixin` e `AppWidgetStateMixin` agendam
a navegação após o frame e solicitam `ensureVisualUpdate()`. Assim, uma leitura
assíncrona concluída com o scheduler ocioso não deixa o redirecionamento esperando
um frame que nenhuma mudança visual solicitou.

No primeiro frame, `AppWidget` encaminha uma abertura inicial em Dashboard,
Settings, User, edição de User, cadastro ou listagem de despesas para `/`,
para passar pela leitura local da sessão.
Links diretos para `/authentication/confirm-email` continuam públicos e não
são desviados para a entrada. Após sign-in, a observação global navega ao
dashboard quando a rota ativa é Welcome ou Sign In; após perda do token,
navega para Welcome somente se a rota ativa estiver classificada como autenticada.
O logout em Settings limpa o storage seguro pela arquitetura de Authentication
e deixa essa mesma observação global navegar para welcome. Não há validação da sessão
no backend na abertura, refresh automático ou guard do Modular. Presença do
token é um sinal local para navegação, não prova de validade ou autorização.

`RouteEnum` centraliza os caminhos e a classificação das rotas pelo parâmetro
`authenticated`, que é `false` por padrão. Dashboard, Settings, User, edição de User,
cadastro de Expense e listagem de Expenses usam
`authenticated: true`. O método estático `authenticatedPaths()` devolve seus
caminhos; `AppWidget` consulta esse conjunto nos redirecionamentos de sessão.
Essa classificação de UI é distinta de `HttpPathEnum.authenticated`, que
controla o envio do token em requisições HTTP.

`app_module.dart` compõe os módulos existentes:

```text
appModule
  dependências root (sem path):
    coreDependenciesModule
    userDependenciesModule
    sessionDependenciesModule
    expenseDependenciesModule
    authenticationDependenciesModule
  rotas:
    welcomeRoutesModule
    expenseRoutesModule
    settingsRoutesModule
    userRoutesModule
    dashboardRoutesModule
    authenticationRoutesModule
    / -> AppScreen
```

`IDateFormatter` e `DateFormatter`, em `core/presentation/formatters/`, centralizam
a formatação de datas em `pt_BR`, recebendo `DateTime` e preservando seus componentes
civis sem conversão de fuso. A implementação recebe um callback `now` opcional,
com `DateTime.now` como padrão, para ano atual e rótulos relativos testáveis.
`formatShortDate` usa `dd/MM/yyyy`; `formatLongDate` usa dia com dois dígitos e
mês abreviado capitalizado sem ponto, incluindo o ano quando diferente do atual.
`formatMonth` retorna o mês por extenso capitalizado. `formatShortPeriod` usa
datas numéricas completas; `formatPeriod` usa o formato textual com ano opcional
em cada ponta. Ambos colapsam intervalos do mesmo dia civil em uma data.
`relativeGroupHeader` retorna Hoje, Esta semana ou Este mês para datas até hoje no
mês corrente, aplicando os grupos nessa precedência. A semana começa na segunda-feira
e não inclui dias de outro mês. Outros meses e datas futuras usam mês e ano
(como Setembro de 2026). Comparações usam componentes civis em UTC, sem depender
da duração de um dia local.
O formatter não faz parsing/serialização da API nem cálculos de expiração.
`DateFieldWidget` recebe o contrato e usa `formatShortPeriod`, substituindo a antiga
`DateTimeRangeExtension` e preservando o formato numérico do formulário.

Registros importantes:

- `coreDependenciesModule`: registra `IMoneyFormatter`, `IDateFormatter`, `IStorageClient` com
  `FlutterSecureStorage`, `IHttpClient` e o Dio compartilhado. A factory instala
  `HeadersInterceptor`, `SessionInterceptor` e, apenas em debug, o logger.
- `userDependenciesModule`: registra `IUserRemoteDataSource`, `IUserLocalDataSource`
  e `IUserRepository` como lazy singletons, usando o HTTP e o storage do core;
  também registra `UserCommand` por factory para Dashboard e dados pessoais.
- `userRoutesModule`: registra `/user` e `/user/edit`, compõe consulta, edição
  e exclusão com commands e callbacks de navegação e registra `DeleteUserCommand`
  e `UpdateUserCommand` como lazy singletons, com descarte pelo módulo, além de
  `UpdateAvatarCommand` por factory, descartado pela tela.
- `sessionDependenciesModule`: registra `ISessionLocalDataSource`, `ISessionRepository` e
  `SessionCommand` como dependências do app inteiro (módulo sem `path`), para
  continuar observando mudanças depois que `AppScreen` sair da pilha.
- `authenticationDependenciesModule`: registra os data sources remoto e
  local, `IAuthenticationRepository`, validators e os commands `SignInCommand`,
  `SignUpCommand`, `ResendEmailCommand` e `CallbackCommand` como dependências
  root-owned, disponíveis também em Settings sem ativar uma rota de Authentication.
- `authenticationRoutesModule`: registra as quatro rotas públicas de autenticação.
  A rota de sign-in usa `SignInScreen` e `FormSignInWidget`: o mixin do
  formulário valida e-mail e senha (6 a 12 caracteres, com maiúscula e número).
  A screen apresenta erros do command sem navegar após o sucesso; o repository
  solicita ao data source local a gravação de token e ID em storage seguro.
  Após o sucesso do sign-up, a
  rota é substituída por `ResendEmailScreen`, que recebe o e-mail
  cadastrado para exibi-lo em um campo desabilitado e permitir o reenvio do link.
- `dashboardRoutesModule`: injeta `UserCommand` na tela inicial, que consulta
  o usuário ao montar. O AppBar recebe o command e `UserNameWidget` usa
  `CommandBuilder` para mostrar nome e avatar gerado a partir da API, skeleton durante a consulta
  e “Tentar novamente” em caso de erro. Nomes longos usam ellipsis. A saudação
  continua baseada na hora local. Dashboard e User recebem instâncias distintas
  do command. Ao retornar de User ou Settings, a Dashboard consulta novamente
  User para atualizar nome e avatar. Os callbacks dessas navegações retornam
  `Future<void>`; o mixin ignora retornos após descarte ou troca de command e
  aguarda consultas em andamento por listener antes da recarga pendente.
  O avatar reutiliza `BounceWidget` e abre `/user` ao tocar, com navegação
  injetada por callback e sem acesso ao router no widget.
  Também injeta instâncias por factory de `GetExpensesCommand` e
  `GetInsightsCommand`, além do
  `IMoneyFormatter` e o `IDateFormatter` do core. `DashboardScreenStateMixin` consulta a primeira
  página com `pageSize: 6` e os insights em paralelo ao montar, recarrega ambos
  após o retorno do formulário e da listagem completa com alterações confirmadas e
  descarta os commands de despesas, insights e User ao sair. A ação de gasto recebe um callback assíncrono para aguardar
  o retorno da rota; após navegação que removeu a Dashboard, o handler não consulta
  novamente a instância descartada. A nova Dashboard carrega ao montar.
  O corpo usa `ListView` com rolagem sempre habilitada, padding inferior para o FAB
  e `RefreshIndicator` para recarregar a primeira página e os insights em paralelo,
  inclusive com lista vazia. Falhas são independentes; `InsightsSectionWidget`
  aparece antes de `ExpensesSectionWidget`.
  `ExpensesSectionWidget` usa `CommandBuilder` para skeleton de seis itens,
  erro localizado com título, descrição e retry, vazio com “Sem despesas neste mês” e sucesso.
  Exibe no máximo seis itens, preservando a ordem e as datas da API. Valores usam
  `IMoneyFormatter.formatCents` e datas usam `IDateFormatter.formatLongDate`, como
  `07 de Out`, incluindo o ano quando diferente do atual, em `pt_BR` e sem conversão
  de fuso. Não acumula páginas nem carrega continuações. Erros de execução da
  atualização permanecem visíveis pelo builder, sem toast adicional.
  `ExpenseItemWidget`, em `expense/presentation/widgets/`, recebe descrição,
  categoria e textos formatados de valor e data, sem estado ou acesso a rede.
  Reutiliza `BackgroundIconWidget` e os rótulos, ícones e cores semânticas de
  `ExpenseCategoryExtension`. Descrição e textos longos usam ellipsis.
  O callback opcional `onSeeAllExpensesPressed` fica preparado para a listagem
  completa: “Ver tudo” aparece somente com itens e callback disponível. A rota
  fornece esse callback para abrir `/expenses`.
  Menu abre `/settings` e a ação de gasto abre `/expense`; orçamento e notificações
  não têm integração.
- `expenseDependenciesModule`: registra `IExpenseRemoteDataSource` e
  `IExpenseRepository` como lazy singletons, sem `path`, e os commands de criação,
  atualização, consulta por ID, listagem e exclusão por factory para estados
  independentes por consumidor. Também registra os validators do formulário.
- `expenseRoutesModule`: compõe `ExpenseScreen` com
  commands, `ExpenseFormValidator`, `IMoneyFormatter` e `IDateFormatter` do core;
  recebe o ID opcional por argumento de `/expense`. Após cadastro confirmado por
  toque simples, o callback injetado navega para `/dashboard`. O hold permanece
  na tela com o formulário limpo para o próximo cadastro.
  Também compõe `ExpensesScreen` em `/expenses`, com uma instância própria de
   `GetExpensesCommand`, os formatters do core e callbacks de retorno e edição.
- `welcomeRoutesModule`: tela e navegação de entrada.
- `settingsRoutesModule`: registra localmente o `LogoutCommand` definido em
  `authentication/presentation/commands/`, injetado na tela e
  dependente somente de `IAuthenticationRepository`. “Sair” abre
  `showConfirmationBottomSheetWidget`; cancelar ou dispensar não executa o command.
  Confirmar fecha a modal pelo `Navigator` e executa o command. O estado do
  `command_it` mostra loading, bloqueia novas execuções e entrega erros em toast.
  Settings não navega no sucesso nem acessa adapters de Authentication.
  “Dados pessoais” abre `/user`. Os demais itens sem destino têm callbacks
  sem integração.

Rotas registradas:

```text
/                         # AppScreen, composição do app
/welcome
/authentication/sign-in
/authentication/sign-up
/authentication/confirm
/authentication/confirm-email
/dashboard
/settings
/user
/user/edit
/expense
/expenses
```

`/dashboard` é uma tela de apresentação, sem shell de navegação autenticada.
Dashboard abre Settings e Expense como rotas próprias; a ação de orçamento ainda
não tem destino. Welcome abre `/authentication/sign-in`, e o sucesso do sign-in
grava token e ID e conduz ao dashboard pela observação da sessão. Os links abaixo
dos formulários substituem sign-in por sign-up e vice-versa, mantendo
`/welcome` na pilha. O cadastro bem-sucedido substitui
sign-up por `/authentication/confirm`, que exibe o e-mail em um campo
desabilitado e permite reenviar o link com feedback da API. Um cooldown local
de 60 segundos começa ao abrir a tela e reinicia após cada reenvio aceito; o
tempo restante aparece no `ResendEmailCooldownLabelWidget`. O
link de confirmação abre `/authentication/confirm-email` com
`verification_url` como parâmetro na `CallbackScreen`; a rota aceita exatamente
um valor desse parâmetro, tratando ausência ou múltiplos valores como URL ausente.

Os módulos financeiros, dashboard e welcome registram suas rotas dentro de seu
escopo de composição. A navegação usa extensões de `BuildContext` do Modular 7,
como `context.pushNamed`, `context.navigate`, `context.replace` e `context.pop`;
não use `Modular.to`.

## API HTTP E Persistência

`coreDependenciesModule` configura `Dio` com `BASE_URL` (padrão
`https://app.cordato.cloud/api/`) e `HeadersInterceptor`, que usa o media type
`application/vnd.api+json`. `HttpClient` decodifica corpos JSON em mapas e
retorna `Either<HttpResponse, HttpResponse>`: corpos válidos com 2xx no `Right`, demais status
no `Left`, com o status e o corpo preservados; falhas de transporte usam
status `0` e corpo de erro genérico. Respostas bem-sucedidas sem corpo usam
mapa vazio. Um corpo não vazio que não seja mapa retorna `Left` genérico,
preservando o status recebido. O data source remoto traduz os corpos da autenticação em respostas
tipadas e erros JSON:API, e o repository expõe
`Either<ErrorsEntity, SessionEntity>` no sign-in e `Either<ErrorsEntity, bool>`
no sign-up e no reenvio.

`DioFactory` garante uma barra final na base antes de configurar o cliente,
preservando o prefixo `/api/` ao concatenar endpoints relativos. Bases informadas
como `/api` e `/api/` produzem os mesmos destinos e o mesmo reconhecimento de
endpoints protegidos pelo `SessionInterceptor`, inclusive na remoção do token
após 401.

O link da API usa o `APP_URL` de produção `https://app.cordato.cloud` para a
página de entrada e a URL assinada da API em `verification_url`. Esse servidor
precisa servir uma página web e os arquivos de associação
`/.well-known/assetlinks.json` e `/.well-known/apple-app-site-association`.
Android e iOS usam o deep linking nativo do Flutter/Modular, incluindo
inicialização e entrega com o app já aberto.

`HttpPathEnum` identifica os endpoints relativos à base e marca os protegidos.
Os data sources constroem `Requests(path: ...)` com o caminho do enum;
para User, interpolam `'${HttpPathEnum.user.path}/${Uri.encodeComponent(id)}'`.
`Requests` possui somente os campos `path` (String), `body`, `query` e `headers`;
não carrega classificação de endpoint ou opções de logging/redirecionamento.
Todos os parâmetros são nomeados; `path` é obrigatório. `copyWith` preserva
campos não informados. Os data sources montam os caminhos diretamente, sem
factory `forPath`, e deixam a autenticação para o interceptor. O catálogo usa
o campo booleano `authenticated`, obrigatório em cada entrada.
`expenses` está marcado como protegido no catálogo e é usado pelo data source
remoto de criação de Expense. O `SessionInterceptor` só lê
`StorageKeyEnum.opaqueToken` para um caminho relativo de endpoint marcado
com `authenticated: true` no enum cuja origem e caminho
coincidam com o endpoint da base e então envia
`Authorization: Bearer <token>`. O token é opaco; `Bearer` é o esquema HTTP.
`HttpPathEnum.user.path` contém `users`; o interceptor permite
exatamente um segmento de id não vazio após esse caminho, preservando a comparação
da origem, do prefixo da base e dos demais segmentos. GET, PATCH e DELETE de
User usam o mesmo token armazenado e a mesma remoção após 401; o data source
não define headers de autenticação nem acessa storage.
Sign-in, sign-up e reenvio são públicos. O backend controla a validade do
token; não há refresh implementado no app. `expiresAt` do login é apenas um
retrato inicial e não bloqueia chamadas no app. Se uma requisição protegida
que enviou esse token
receber 401, o interceptor remove somente `StorageKeyEnum.opaqueToken` do
storage, preservando a resposta 401; não remove um token novo gravado depois
do envio da requisição. A exclusão notifica `SessionCommand`, e `AppWidget`
redireciona para welcome se o usuário estiver numa rota protegida.
Essa remoção por 401 preserva `StorageKeyEnum.userId` e outras chaves; somente
o logout aceito solicita a limpeza completa do storage.

Endpoints usados pelos data sources atuais:

| Operação | Método e caminho relativo | `authenticated` | Resultado do data source |
|---|---|---|---|
| Sign-in | POST `authentication/sign-in` | `false` | `Either<ErrorsResponse, SignInResponse>` |
| Sign-up | POST `authentication/sign-up` | `false` | `Either<ErrorsResponse, SignUpResponse>` |
| Reenvio | POST `authentication/email-verification/resend` | `false` | `Either<ErrorsResponse, bool>` |
| Logout | DELETE `authentication/sign-out` | `true` | `Either<ErrorsResponse, bool>` |
| Consulta de User | GET `users/<id>` | `true` | `Either<ErrorsResponse, UserResponse>` |
| Atualização do nome e avatar | PATCH `users/<id>` | `true` | `Either<ErrorsResponse, UserResponse>` |
| Exclusão de User | DELETE `users/<id>` | `true` | `Either<ErrorsResponse, bool>` |
| Criação de Expense | POST `expenses` | `true` | `Either<ErrorsResponse, ExpenseResponse>` |
| Listagem de Expense | GET `expenses` com `page[size]` e query de continuação | `true` | `Either<ErrorsResponse, ExpensePageResponse>` |
| Métricas de despesas | GET `metrics/expenses` com período e agrupamento opcionais | `true` | `Either<ErrorsResponse, ExpenseMetricsResponse>` |

Confirmação de e-mail usa GET da URL assinada absoluta e retorna `int?` no data
source. No enum, User guarda `users`; o sufixo de ID é interpolado pelo
data source, não armazenado como template no catálogo.

O logout usa `DELETE authentication/sign-out`, sem payload, marcado como
protegido em `HttpPathEnum.logout`. `AuthenticationRemoteDataSource.logout()`
usa `Requests(path: HttpPathEnum.logout.path)` e o
interceptor existente para enviar Bearer; o backend
revoga o token atual e retorna 204 sem corpo, convertido em `Right(true)`.
O data source remoto não manipula storage.

A confirmação de e-mail usa `IHttpClient.get` no Dio compartilhado com a URL
assinada original em `Requests(path: url)`. O interceptor não envia Bearer para
URLs absolutas. O cliente HTTP atual não configura redirecionamentos ou filtros
de logging específicos para esses caminhos; usa as opções padrão do Dio. O data
source remoto entrega o status (`null` quando é `0`) ao repository, que traduz
204 em sucesso, 403 em link inválido e os demais resultados em falha de
conexão, sem verificar host, caminho ou assinatura localmente.

`TalkerDioLogger` é instalado apenas em debug e, nas requisições usuais,
registra headers e payloads de request, response e error (inclusive senha no
sign-in e token na resposta). URLs absolutas, incluindo a confirmação assinada,
também são registradas nessa configuração. Não há logger Dio em release.

O contrato `IAuthenticationRepository.signUp` e o data source remoto recebem
`email` e `password` obrigatórios e `name` e `avatar` opcionais. O repository
delega os parâmetros sem normalização. O POST relativo
`authentication/sign-up` envia `data.type: sign-ups`, nome, e-mail, senha e
`password_confirmation` igual à senha. O data source preserva o nome informado
e usa `Trocado` quando ele é nulo, mantendo o formulário atual de e-mail e senha.
`avatar` transporta uma seed textual e é omitido quando ausente ou nulo;
não é necessário gerar ou enviar avatar no cadastro. Quando informado, é
enviado como `data.attributes.avatar`, sem conversão ou validação local.
`SignUpResponse` preserva `data.id`; a resposta pode incluir a relação `user`,
sem criar sessão ou gravar token/ID no storage. O perfil é consultado
posteriormente por User, preservando `avatar` nulo ou ausente.

O formulário de Expense executa o cadastro pela API através do command e repository.
Dashboard consulta o perfil pelo `UserCommand`, mas não existe feature Flutter de orçamento.
Ao conectar persistência financeira, preserve propriedade
individual e invariantes no serviço responsável, com testes de autorização e
regras de domínio; a UI não é fronteira de autorização.

## Interface E Tema

Código novo de UI importa `package:material_ui/material_ui.dart`. Reutilize os
widgets compartilhados de `core`, especialmente os botões e `BounceWidget`, em
vez de estilizar botões Material diretamente.

O dashboard usa um botão de ação expansível para acessar o formulário de gasto;
não há barra inferior de navegação ou shell autenticado na composição atual.

O teclado `CentsCalculatorWidget`, em
`expense/presentation/screens/expense/widgets/calculator/`, recebe dígitos em reais:
`80` representa `R$ 80,00`. A tecla de vírgula permite informar até dois
dígitos de centavos (`80,5` representa `R$ 80,50`). A entrada permite até sete
dígitos inteiros; `DEL` remove a última entrada e `AC` limpa o valor. O estado
local usa o `IMoneyFormatter` para converter a entrada e mantém o contrato de
receber e devolver centavos inteiros. O formulário de Expense abre esse teclado
em uma bottom sheet ao tocar em Valor ou avançar a partir da descrição.

Use os acessos de tema existentes:

```dart
context.colors
context.typography
context.radius
context.isDark
```

`Themes.light` e `Themes.dark` registram Material 3, Inter e
`CornerRadiusToken`. Widgets não devem introduzir cores, tipografia ou tokens
paralelos quando houver um papel semântico do tema.

O tema acompanha o sistema (`ThemeMode.system`) e a aplicação usa `pt_BR`.
Previews nativos usam `@CordatoPreview`, em
`core/presentation/previews/preview.dart`, com tema real, localização e toast.
O catálogo contém componentes compartilhados do core, Welcome, formulário e
listagem de Expense e seções e tela completa da Dashboard. Os previews mensais
cobrem loading agregado, mês vazio, falha parcial, consultas explícitas,
listagem filtrada ou geral e paginação local de 20 itens. O seletor possui
cenários de fevereiro bissexto e virada de ano. Fakes de catálogo implementam
contratos de domínio sem rede ou storage; comandos pertencentes às screens
são descartados por elas, e recursos externos usam `PreviewResourceWidget`.
Esses cenários são catálogo visual, não evidência de validação da API ou Maestro.
Execute-o com `dart run tool/widget_preview.dart`
e abra a URL impressa no navegador. O launcher inicia o previewer nativo com
`--web-server` e cria um arquivo Dart temporário em `tool/` após o servidor estar
disponível. Isso contorna a condição de corrida observada no Flutter 3.47.6 e
3.47.7, que consulta
os previews antes do fim da análise inicial e mantém o catálogo vazio até uma
mudança de arquivo. O arquivo temporário é removido ao encerrar o launcher, sem
reescrita dos arquivos da aplicação. `PreviewResourceWidget` cuida
do descarte de recursos no catálogo, e `.widget_preview/` não é versionado.
No painel do editor, uma abertura com “No previews detected” também requer
atualização após a análise inicial. Essa falha de descoberta não exige converter
o primary constructor de `CordatoPreview`; a anotação mantém a sintaxe padrão
do projeto.

## Testes E Verificação

Testes unitários cobrem `Either`, autenticação e sessão em application/infrastructure,
entidade, DTO e data source de User, cliente HTTP, interceptors, storage,
`response<T>`, validators de autenticação, formatters, helpers,
commands e limites arquiteturais. Use `mocktail` para doubles. A política atual
não mantém testes Flutter automatizados para widgets, screens, temas, módulos
ou rotas; esses fluxos serão validados com Maestro quando os cenários existirem.
Não há suíte `integration_test` Flutter registrada.

Os arquivos `*_test.dart` contêm cenários e configuração, sem classes de mocks,
fakes ou adapters locais. Os doubles ficam em arquivos públicos próprios sob
`test/support/<feature>/mocks/` e `test/support/<feature>/fakes/`, com reutilização
por contrato e instâncias independentes em cada teste. `HttpClientAdapterFake`,
em `test/support/core/fakes/http_client_adapter_fake.dart`, permite simular
respostas e exceções de Dio pelo callback `respond` e é compartilhado pelos
testes do cliente HTTP. Mocks de HTTP e storage de core também são reutilizados
por Authentication, Session e User. Imports de suporte de teste são relativos;
imports da aplicação continuam usando `package:cordato/`.

Há um flow legado de Welcome/Authentication em `maestro/`, ainda com textos
anteriores ao sign-in atual. A decisão de validar UI e fluxos com Maestro não
significa que todos os cenários já estejam cobertos. Resultados e bloqueios de
validação mensal ficam no registro da change OpenSpec correspondente.
O teste de `RouteEnum` verifica strings, não navegação ou integração do Modular.

O check de dependências de Settings permite os contratos do domínio de
Authentication e o arquivo específico de `LogoutCommand`; os demais imports
de Authentication continuam bloqueados nessa feature.

Os testes de repositories de Authentication, User, Session e Expense ficam em
`test/features/<feature>/application/repositories/`; quando houver inputs puros,
seus testes ficam em `application/data/`. Essa estrutura
espelha a produção, mantendo os doubles compartilhados em `test/support/`.

Os checks de camadas bloqueiam imports de `application/repositories/` pelo
domínio e pela apresentação e imports de apresentação por `application/`.
Tipos puros de `application/data/` continuam acessíveis às camadas consumidoras.

Limitações conhecidas da suíte arquitetural:

- ainda há listas e checks históricos de Supabase e escrita via RPC; a
  integração atual usa HTTP JSON:API, e esses checks não validam esse contrato;
- `_contextFrom` reconhece apenas contextos financeiros, de modo que o teste
  de isolamento entre `authentication` e `session` não inspeciona seus imports;
- as listas de SDKs proibidos não incluem Dio.

O teste de `ResendEmailCommand` permanece no caminho histórico
`test/features/authentication/presentation/screens/resend_email_verification/commands/resend_email_verification_command_test.dart`,
embora importe o command atual em `screens/resend_email/`. Essas pendências
não alteram as direções aprovadas nem devem ser tratadas como novas convenções.

Expense reutiliza os campos de valor e data ainda localizados em
`authentication/presentation/widgets/`; componentes compartilhados novos devem
seguir a localização em core, sem repetir essa dependência legada.

Execute para alterações Flutter:

```bash
flutter pub get
flutter analyze
flutter test
```

Para uma verificação rápida de limites:

```bash
flutter test test/architecture
```

Para executar o app com a API padrão, use `flutter run`. Para apontar a
autenticação a outra API, configure a URL base (incluindo o prefixo `/api/`):

```bash
flutter run --dart-define=BASE_URL=https://api.exemplo.com/api/
```

Para build, assinatura e verificação de release Android, consulte
[`android/README.md`](android/README.md).

## Revisão De Documentação

Uma mudança que adicionar, remover ou mover módulo, rota, contrato, integração
HTTP, comando de validação ou configuração de release deve atualizar
na mesma alteração o documento canônico afetado:

- `ARCHITECTURE.md` para camadas, módulos, rotas e fronteiras.
- `android/README.md` para release Android.
- `README.md` para estado do produto e início rápido.
- `AGENTS.md` para convenções de contribuição e checklist.

Revise esses documentos juntos quando uma mudança estrutural os afetar.
