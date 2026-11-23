# Arquitetura

Estado canônico da versão local em transição para Drift, revisado em **23/11/2026**.
Convenções obrigatórias: [AGENTS.md](AGENTS.md). Execução e limites do produto:
[README.md](README.md). Registros anteriores:
[histórico da transição](docs/history/local-transition.md).

## Decisão canônica

A persistência escolhida passa a ser Drift/SQLite. A entrega atual inclui a
fundação em `lib/features/core/infrastructure/clients/database/` e User/Expense/Metrics
migrados, com testes reais e composição global sobre o mesmo banco.
O `coreModule` registra o client como singleton lazy. Não há dependência de Localstore
no app ou suporte de testes.
Não há importação de dados de Localstore/ToStore ou migração de bancos SQLite
experimentais anteriores. Sem usuários, o schema não publicado foi consolidado
na versão 1 por decisão do usuário.

### Fundação Drift

```text
core/infrastructure/clients/database/
  database_client.dart
  database_client.g.dart
  database_date_codec.dart
  database_operation.dart
  tables/
    profiles_table.dart
    expenses_table.dart
```

`DatabaseClient` é o próprio banco tipado Drift, não um wrapper. Não possui
interface, CRUD genérico ou regras de negócio. O `coreModule` registra
`addLazySingleton<DatabaseClient>(DatabaseClient.new)`, compartilhando a instância
por DI sem abrir storage. UserRepository e ExpenseRepository recebem o client
por construtor; MetricsDao recebe a mesma instância.
Tipos gerados não atravessam contratos de application nem entram em domain/UI.
`runDatabaseOperation`, em `database_operation.dart`, centraliza a tradução de
falhas operacionais SQLite/filesystem e o desembrulho de DriftRemoteException.
Cada repository fornece a factory da sua exceção de aplicação; o core não
depende das exceções das features. Erros inesperados preservam causa e stack.
A função não recebe conexão, não inicia transações e não implementa CRUD,
retry ou reset. Consultas e mapeamento ficam no callback; validações prévias e
publicação nativa permanecem fora dele. As transações pertencem aos repositories.
O futuro owner da conexão deve aguardar operações e chamar `close`; screens não
são donas do banco. O ModularContext atual não expõe callback de descarte nos
registros: a coordenação de fechamento assíncrono pelo root permanece pendente.
Não se presume que dispose do injector feche o banco. Testes de resolução fecham
o client explicitamente, sem abrir storage.

A conexão padrão abre sob demanda `cordato.sqlite` em Application Support e
executa SQLite em isolate separado. Executors podem ser injetados nos testes.
`PRAGMA foreign_keys = ON` roda em cada abertura. Schema atual versão 1 cria
tabelas e índices, sem inicializar perfil, ler Localstore ou apagar arquivos
legados. Evoluções exigem migrações explícitas e testadas, nunca reset automático.
O setup `DatabaseClient.configureConnection` registra cordato_lower, função
determinística com o mesmo lowercase Unicode de String.toLowerCase em Dart.
A conexão padrão registra no isolate; executors nativos injetados precisam do
mesmo setup para consultas que usam a função. O registro da função não altera o schema nem tem
import reverso de DAO de feature pelo core.

| Tabela | Contrato |
| --- | --- |
| `profiles` | ID inteiro `PRIMARY KEY AUTOINCREMENT` gerado pelo banco, nome e seed obrigatórios; índice único sobre constante garante no máximo um perfil, mesmo com IDs diferentes. |
| `expenses` | ID inteiro `PRIMARY KEY AUTOINCREMENT` gerado pelo banco, `profile_id` inteiro obrigatório referenciando `profiles.id` com `ON DELETE CASCADE`, `amount` inteiro positivo em centavos, categoria restrita por CHECK às opções de Expense com default `other`, descrição anulável e `occurred_on` civil `YYYY-MM-DD`, entre anos 0001–9999, default SQL `date('now', 'localtime')`. |

O índice `expenses_profile_date` cobre perfil/data/ID. Categorias permitidas
continuam sendo regra do domínio de Expense. O CHECK SQL da coluna category
reforça a integridade com os mesmos textos, sem import de Expense ou outro enum
no core. O teste arquitetural compara os valores do CHECK real ao CategoryEnum
e insere todas as opções. Novas categorias exigem enum, CHECK e migração alinhados.
IDs são atribuídos pelo SQLite, sem geração na aplicação. AUTOINCREMENT impede
reutilização de IDs de registros confirmados e depois excluídos no mesmo banco,
inclusive após cascade; não reinicie sqlite_sequence. Datas omitidas usam o dia
local do SQLite; datas explícitas não usam o default.
Datas civis não são timestamps nem sofrem conversão de fuso.
`encodeDatabaseDate`, em `database_date_codec.dart`, valida anos 1–9999 e
serializa os componentes civis como `YYYY-MM-DD`, sem converter fuso ou usar
formatação de apresentação. Expense e Metrics compartilham essa função; Metrics
codifica os limites mensais antes de acessar banco/widget.
`CategoryEnum.fromValue` centraliza o parsing estrito de categorias por texto
em Expense e Metrics, sem normalização ou fallback para `other`.

Sem usuários, a definição atual foi consolidada na versão 1, incluindo IDs
inteiros autoincrementais, default de data local e CHECK de categorias.
MigrationStrategy mantém somente criação e habilitação de foreign keys, sem
onUpgrade, reconstrução de tabelas ou manipulação de sqlite_sequence.
Testes/fixtures exclusivos das migrações experimentais foram removidos.
Arquivos experimentais incompatíveis, inclusive versões 2/3 ou versões 1 com
outras definições, precisam ser recriados manualmente. O app não os apaga,
não faz downgrade nem reset automático. Evoluções publicadas continuam exigindo
migrações explícitas e testadas.

O contrato de produto aprovado é ter um perfil ativo antes de operar, inicialmente
com ID novo, nome `Cordato` e seed aleatória. Edições preservam o ID. Apagar os
dados deve remover perfil/dependentes e criar outro perfil padrão, com novos
ID/seed, na mesma transação. A existência do perfil e essa operação não são
responsabilidades implementadas pelo schema: ele permite banco vazio.
Não se introduzem login, `owner`, múltiplos perfis ou identidade autenticada.

O cascade é lógico e transacional dentro do SQLite. Não limpa snapshots do widget
ou tarefas de IA/edição em andamento, nem comprova apagamento físico irrecuperável.
Essas coordenações, views, exclusão na UI e IA são etapas futuras, sem
criptografia ou backup implicitamente prometidos.

Geração: `dart run build_runner build`; versione o arquivo gerado. Preserve o
construtor convencional do client; mudanças exigem validar a geração, não só
a análise Dart. Testes espelham o client em
`test/features/core/infrastructure/clients/database/`, usando SQLite real para
constraints, cascade, rollback e reabertura de arquivo.

### Estado da integração

User/Expense/Metrics usam Drift. Metrics agrega as despesas SQLite por categoria
em uma consulta parametrizada no MetricsDao, sem View ou alteração do schema.
Composição global e suporte de testes não dependem mais de Localstore.

O aplicativo é exclusivamente local. Authentication, Session, Welcome, PocketBase,
backend, worker, áudio, IA, Insight, CSV e infraestrutura de compartilhamento
sem consumidores foram removidos. Documentos históricos não autorizam restaurá-los.
Não há identidade autenticada, `owner` nas despesas ou autorização remota.

```text
Screen/Widget → Bloc → contrato de repository em application
                            ↑
                 repository em infrastructure → DatabaseClient (User/Expense)
                                             → MetricsDao → DatabaseClient
                                            → contrato de client nativo do core
```

O módulo injeta a implementação; o Bloc conhece somente contratos e exceções
de aplicação. Contratos usam `Future<T>`, sem Either, commands ou envelopes do
SDK. Não há camada de data sources, wrapper genérico de CRUD ou store global.

## Site público no mesmo repositório

`site/` contém o site HTML/CSS independente do aplicativo Flutter, com home,
privacidade, termos e suporte. Não é Flutter Web, backend ou consumidor do
Localstore. Os documentos descrevem o app local, sem restaurar autenticação,
exclusão de conta, áudio, IA ou acesso remoto aos registros.

Assets e testes pertencem a `site/`; ferramentas Node são opcionais e não entram
no pubspec, em `lib/`, em `test/` ou nos targets nativos. As convenções estáticas e
testes de UI/acessibilidade do site estão em [`site/AGENTS.md`](site/AGENTS.md) e
[`site/ARQUITECTURE.md`](site/ARQUITECTURE.md), sem alterar a política de testes
sem UI do Flutter.

Os workflows ficam na raiz: `site-test.yml` verifica mudanças do site e
`site-pages.yml` publica manualmente `site/public/`, sem instalar npm ou executar
build. Páginas, FAQ e navegação funcionam sem JavaScript.
Ambos são independentes de `android-release.yml`, de Flutter e dos secrets
de release/Localstore. A hospedagem não exige VPS e não lê dados do app.
DNS, visibilidade e publicação remota não são consequências automáticas desta
organização. Rotas, artefato e limites estão em [`site/README.md`](site/README.md).

## Produto e contextos

| Feature | Responsabilidade atual |
| --- | --- |
| `core` | Capacidades compartilhadas, componentes visuais, formatadores e clients nativos. |
| `user` | Leitura e atualização do perfil SQLite: ID inteiro, nome e seed do avatar. |
| `expense` | Despesas individuais: CRUD, consultas, paginação e sugestões. |
| `metrics` | Projeção mensal somente leitura das despesas SQLite, agregadas por categoria. |
| `dashboard` | Apresentação e composição dos contratos consultados. |
| `root` | Composição visual, entrada e coordenação dos widgets do sistema. |
| `settings` | Navegação para perfil, informações e apoio. |
| `information` | Conteúdo local de Termos, Privacidade e Ajuda. |
| Budget e Family | Planejados, não implementados. |

Dinheiro é representado em centavos inteiros de BRL. Datas de gastos são civis.
Para evoluções futuras, gasto não referencia orçamento: pertencimento é derivado
da data; orçamentos vivos da mesma pessoa não podem se sobrepor. Família é uma
lente autorizada de leitura, sem escrita nos dados de outro membro ou alteração
dos dados individuais ao sair. Esses princípios não representam suporte atual
a múltiplos perfis, família ou orçamento.

## Bootstrap e composição

```text
main
 └─ runApp(ModularApp(module: appModule))
      ├─ coreModule → DatabaseClient lazy + formatadores + IWidgetClient
      ├─ userModule → UserRepository → DatabaseClient
      ├─ expenseModule → ExpenseRepository + SuggestionsDao → DatabaseClient
      └─ metricsModule → MetricsRepository → MetricsDao → DatabaseClient
```

`appModule` e `coreModule` não recebem banco por parâmetro. O core registra
`addLazySingleton<DatabaseClient>(DatabaseClient.new)`. A instância é criada de
forma síncrona; LazyDatabase resolve diretório e abre o arquivo na primeira
operação assíncrona. Resolver DI não abre arquivo nem cria perfil.

`main` monta o app sem preparar storage/perfil; UserRepository cria o perfil na
primeira consulta. A criação de Expense depende desse perfil já existir, mas
não inicializa User nem depende de seu repository. Operações recebem o banco
por construtor; não há wrapper CRUD, data source ou service locator.

Tabelas, setup, geração e fechamento estão na fundação acima. As
dependências resolvidas atuais estão no pubspec/lockfile, sem o fork privado.
O Localstore anterior e seus limites pertencem ao histórico, sem importação
ou exclusão de seus arquivos.

### Escopos Modular

A composição usa a API funcional `createModule` do Modular 7. `coreModule`
registra DatabaseClient lazy, formatadores e `IWidgetClient`. O módulo Expense
registra SuggestionsDao lazy sobre esse banco, sem criar outra conexão.
Metrics registra MetricsDao lazy sobre a mesma instância.
`IWidgetClient` e `WidgetClient` ficam juntos em
`core/infrastructure/clients/widget_client.dart`; os contratos de repository de
Root continuam em `root/application/repositories/`. `IDateFormatter` e
`IMoneyFormatter` ficam nos próprios arquivos `date_formatter.dart` e
`money_formatter.dart`, em `core/presentation/formatters/`.

User, Expense, Metrics e Settings usam um módulo por feature, sem path, com
rotas completas quando existentes. Binds consumidos por outras features ficam
disponíveis antes de visitar rotas irmãs. Módulos com paths exclusivos permanecem
como implementados; não devem ser migrados incidentalmente.

Sem path não significa singleton de Bloc. Factories continuam independentes;
o owner da instância define seu fechamento. Não fragmente módulos em
dependencies/form/list/routes nem use `/` como path de features irmãs:
o Modular indexa escopos pelo path.

## Estrutura e dependências

```text
lib/features/<feature>/
  <feature>_module.dart
  domain/
    entities/
    enums/
    value_objects/
  application/
    exceptions/
    repositories/
  infrastructure/
    repositories/
    responses/
    daos/
  presentation/
    screens/<screen>/
      bloc/
      mixins/
      widgets/
    validators/
    widgets/
    previews/
```

Crie somente diretórios necessários. Features visuais não precisam de repository
ou domínio artificiais.

- **Domain:** tipos e invariantes puros, sem Flutter, Bloc, SDK ou application.
- **Application:** contratos e exceções esperadas, sem implementação, UI ou SDK.
- **Infrastructure:** User/Expense usam DatabaseClient, registros tipados e DAO
  específico; Metrics usa MetricsDao sobre o mesmo banco. Tipos de SDK não atravessam
  os contratos de application. Não crie DAO para cada operação CRUD sem necessidade.
- **Presentation:** Bloc, formulário, renderização, feedback e navegação.
- **Módulos:** composição, podendo importar implementações concretas.
- **Core:** apenas capacidades realmente compartilhadas, não regras deslocadas
  para contornar dependências entre features.

Dashboard compõe contratos de User, Expense e Metrics. Expense não importa
Metrics ou Root: sinaliza mutações pela capacidade nativa compartilhada.
Metrics pode importar o enum puro de categoria de Expense, não sua implementação.
Root compõe Metrics e o client nativo através de seus próprios repositories.

## Persistência

### Perfil User local

UserRepository recebe DatabaseClient e usa a tabela `profiles`:

| Campo | Valor inicial |
| --- | --- |
| `id` | Inteiro autoincremental gerado pelo SQLite; chave interna estável. |
| `name` | `Cordato` |
| `seed` | 16 bytes aleatórios de Random.secure em hexadecimal, independentes do ID. |

`get` consulta e cria o perfil somente quando ausente, dentro de transação.
O índice único e as transações do banco compartilhado evitam perfis duplicados
em leituras concorrentes. UserResponse.fromRecord converte ProfilesTableData em
UserEntity puro com `id`, `name` e `seed` obrigatórios; não há JSON legado.
ID usa int na entidade/response e é obtido por insertReturning, sem ser fornecido
no insert. Seed permanece String aleatória; o app não gera tokens para IDs.
Não há e-mail, autenticação, múltiplos perfis ou migração de dados antigos.

`IUserRepository` expõe `get` e `update({name, seed})`, sem exclusão de conta.
Cada update lê/inicializa o perfil, grava somente campos fornecidos por ID e lê
o perfil final na mesma transação. O ID nunca muda na edição. Updates concorrentes
no mesmo banco compartilhado preservam mudanças em campos distintos. Sem campos,
update apenas consulta, criando defaults somente se ausente.

Não há cache adicional, fila de Futures ou estado pendente. O Future aguarda
escritas e commit; falha reverte inclusive um perfil recém-criado durante update.
Seed não é anulável; texto vazio e espaços são preservados. O conceito visual
continua sendo avatar, mas os dados e contratos usam `seed`.

Falhas SQLite operacionais BUSY, LOCKED, READONLY, IOERR (incluindo códigos
estendidos), FULL e CANTOPEN e falhas de filesystem geram UserException segura.
Erros SQL, constraints, corrupção, parsing e programação propagam sem defaults,
reset ou retry. DriftRemoteException é desembrulhada preservando causa e stack.
A dependência direta sqlite3 fornece os códigos, sem constantes numéricas locais.
A apresentação valida nome com 2–32 code points Unicode após trim; Bloc e
repository não normalizam entradas. User/Edit preservam ownership e factories.

### Despesas locais

ExpenseRepository usa o DatabaseClient compartilhado e a tabela `expenses`:

- ID int autoincremental gerado pelo SQLite.
- `profile_id` int obrigatório, referenciando perfil com ON DELETE CASCADE.
- `amount` inteiro obrigatório, positivo, em centavos.
- `category` textual obrigatória, default `other`.
- `description` textual anulável.
- `occurred_on` textual `YYYY-MM-DD` civil obrigatória.

Schema/índice estão na fundação do core; não há `owner`, TTL ou expulsão por capacidade.
Categorias usam o enum puro `CategoryEnum`, em
`expense/domain/enums/category_enum.dart`; não um enum duplicado no banco.
O repository valida centavos positivos e categorias. Hoje é default do banco quando a data
não é fornecida.

Datas preservam os componentes civis, sem conversão de fuso; anos fora de 1–9999
geram ArgumentError antes de acessar o banco.
Filtros finais incluem todo o dia escolhido. Descrição nula vira texto vazio
na projeção. O repository aplica trim à descrição para preservar o comportamento
anterior do ToStore. Tipos, datas ou categorias inválidos são inesperados.

Criação executa INSERT SELECT FROM profiles RETURNING em uma instrução,
sem SELECT separado. A variante sem data omite occurred_on para acionar o default
SQL; a variante com data vincula a data civil explícita. Não há dependência de UserRepository nem inicialização
duplicada do perfil: ausência gera ExpenseException com profile_not_found, sem
refresh. User deve inicializar antes da criação; o atalho/formulário não ganham
bootstrap nesta etapa. A UI informa falha segura e permite retry manual.

CRUD usa operações Drift. UPDATE RETURNING altera somente campos fornecidos,
retorna o registro atualizado e identifica ID inexistente por retorno vazio,
preservando profile_id e campos omitidos. Concorrência no
mesmo banco compartilhado não perde alterações de campos distintos.
Sem campos, update apenas lê a entidade e não solicita refresh. Exclusão executa
um DELETE atômico e identifica ID inexistente pelas linhas afetadas, sem SELECT
ou transação explícita adicional. Create/update mantêm transação para reverter
falhas no mapeamento do retorno e aguardar commit antes de publicar sucesso.

IDs de ExpenseEntity/ExpenseSuggestionEntity, contratos, eventos, estados e
argumentos de edição são int. Responses convertem registros tipados, sem JSON
legado. A apresentação não recebe profile_id nem tipos gerados do Drift.

Listagem filtra/ordena no SQLite, usa offset/limite mais um
e retorna itens imutáveis com `nextPage` opcional. A ordem padrão é data/ID
decrescentes; ID numérico ascendente desempata outras ordens. Campos de ordenação
são validados por allowlist, sem interpolar SQL recebido. Perfil é filtrado por
subconsulta, utilizando o índice existente por perfil/data/ID. Descrição nula ordena
como texto vazio. Filtros são reenviados pelo Bloc a cada página, e refresh retorna à
primeira. Não há snapshot transacional entre páginas.

Sugestões percorrem o histórico ordenado até 30 correspondências literais
case-insensitive antes de deduplicar descrições. Preservam categoria e valor da
ocorrência mais recente e ignoram descrições vazias/nulas. SuggestionsDao,
em `expense/infrastructure/daos/`, executa uma única consulta com snapshot da
instrução, sem loop ou transação explícita: CTE materializada seleciona as 30
correspondências ordenadas por data/ID; ROW_NUMBER particionado pela descrição
lowercase deduplica somente depois do limite. Matching literal usa instr e
cordato_lower, com parâmetro vinculado e Unicode equivalente ao Dart, não LIKE,
regex ou remoção de acentos. A função roda na conexão SQL; não há transporte
de páginas para filtragem/deduplicação no repository. Busca pode percorrer o histórico
quando faltam correspondências; não há índice de substring ou benchmark prometido.
O plano foi testado usando expenses_profile_date para perfil/ordenação.

O DAO estende DatabaseAccessor, compartilha DatabaseClient e é registrado no
expenseModule, sem interface ou service adicional. Core não importa features.
Repository converte os registros retornados e traduz falhas operacionais;
contratos/entidades/UI não conhecem o DAO. Aceitar sugestão aplica
categoria, inclusive `other`, preservando data e valor manual do formulário.

Após commit, o repository solicita refresh pelo client nativo. Falhas de storage
não refrescam nem retornam sucesso; falha posterior do client não desfaz o commit
nem gera retry automático. SQLite operacional e filesystem viram ExpenseException
segura, com a mesma classificação de User, inclusive através de isolate.
Erros SQL, constraints, corrupção, parsing e programação propagam. O formatter
local conhece profile_not_found, expense_not_found e invalid_amount, sem expor
diagnósticos. Testes reais/interceptor verificam SQL, transações, rollback,
persistência, concorrência e refresh após commit.
Não há exportação CSV ou contrato de compartilhamento.

### Métricas locais

Metrics é projeção somente leitura de `expenses`, sem tabela própria, cache,
triggers, materialização ou escritas em Expense.

`IMetricsRepository.getExpenses` preserva o contrato mensal. Sem datas usa o
mês civil atual; intervalo incompleto, parcial, invertido ou de vários meses
gera MetricsException antes da leitura. Horário e indicação UTC da entrada não
alteram seus componentes civis.

MetricsDao estende DatabaseAccessor e executa uma única consulta parametrizada,
filtrando perfil por subconsulta e os dois limites civis inclusivos do mês.
O limite final inclusivo também suporta dezembro de 9999, sem data sentinela.
SUM(amount), MIN(amount), GROUP BY category e ORDER BY category retornam registros
tipados de infraestrutura num snapshot consistente, sem transação explícita.
O índice expenses_profile_date atende ao filtro. Não há View, tabela nova ou
alteração de schema. Anos fora de 1–9999 geram ArgumentError antes da leitura.
Total e distribuição vêm dos mesmos grupos. Centavos permanecem inteiros;
percentuais são calculados em Metrics sem arredondamento antecipado.
`ExpenseMetricsEntity`, `ExpenseCategoryMetricsEntity` e
`ExpenseCategoryMetricsResponse` usam o campo `total`, não `totalAmount`.
Os grupos são construídos pelo SQL, sem parser JSON; despesas usam `amount`.

`ExpenseCategoryMetricsResponse`, em `infrastructure/responses/`, converte os
grupos; o repository monta o resumo, sem camada `projections/`. Categorias têm
ordem textual determinística. O ID `monthly-yyyy-MM` é estável. Sem agrupamento,
`categories` é null; mês vazio agrupado tem lista vazia imutável.

Categorias desconhecidas, parsing inválido, centavos não positivos e overflow
por categoria ou mensal são inesperados. Overflow de SUM propaga como erro SQLite;
overflow mensal é detectado em Dart. MIN(amount) impede que uma soma positiva
oculte valores não positivos caso constraints tenham sido burladas.
Falhas operacionais SQLite/filesystem seguem a classificação segura de User/Expense,
inclusive causas remotas do Drift; demais falhas preservam causa/stack.
Não há zero fabricado, reset ou retry automático.

Somente a consulta do mês atual captura revisão antes da leitura e aguarda a
publicação nativa, inclusive para zero válido. Consultas históricas não publicam.
Publicação ocorre fora do tratamento de falhas de storage.

Na apresentação, `cardPages` remove categorias não positivas, ordena por
`total` decrescente com desempate estável e monta páginas de até três categorias.
`ExpenseMetricsPagesExtension` fica no mesmo arquivo
`expense_metrics_categories_extension.dart`; a dica aparece somente na última
página com uma categoria, quando há mais de uma página.

## Falhas e apresentação

Repositories convertem falhas esperadas do banco/filesystem em exceções
específicas de aplicação, preservando códigos e ordem em ErrorsEntity.
Não expõem mensagens nativas de storage na UI e não capturam genericamente
erros de programação ou parsing para fingir falha de negócio.

Blocs preservam os erros esperados; inesperados geram fallback seguro e
`addError(error, stackTrace)`. Formatadores puros escolhem mensagens locais em
português por código, campo e operação. Não há fallback para sucesso vazio.

Eventos e estados ficam junto ao Bloc da screen. Concorrência é explícita;
submissões usam a política implementada, e leituras substituíveis podem usar
restartable. Após `await`, o handler respeita `isClosed` e `emit.isDone`.
Fechar Bloc não cancela a operação de storage já iniciada.

Entrada, controllers, foco e erros por campo pertencem ao formulário. Não
espelhe loading/resultado do Bloc em flags locais. Efeitos únicos usam listeners,
nunca build. Lifecycle substancial fica em mixin específico da screen.

### Ownership de Blocs

- User/Edit, Expense/Expenses e Dashboard preservam factories estáveis e ownership
  pelas screens: criar em initState, fechar em dispose, substituir apenas quando
  a factory mudar.
- ExpenseSuggestionsBloc pertence exclusivamente ao `provide` da rota, com
  `scope.addBloc`; formulário/screen recebem a instância e não a fecham.
- AppWidget possui WidgetLaunchBloc e WidgetSyncBloc por factories
  estáveis, sem singleton ou SessionBloc.
- Settings, Information e Metrics não possuem Bloc próprio. Dashboard e Root
  consultam o repository de Metrics.
- Para estados de página novos ou explicitamente migrados, prefira `provide`
  com a extension `BlocScopedExtension`; migre todos os consumidores juntos.

## Entrada, navegação e rotas

`main` inicia em `/dashboard`. `/` é fallback visual com política pura apontando
à Dashboard. As rotas atualmente registradas são:

```text
/
/dashboard
/user
/user/edit
/expense
/expenses
/settings
/settings/support
/information/terms
/information/privacy
/information/help
```

Não há proteção por sessão, constantes de autenticação ou API `authenticated`
em RouteEnum. Welcome foi removida, incluindo composição, arquivos, constante
de rota e referências nos testes.

Navegação nova usa extensões de BuildContext no widget/mixin responsável.
Argumentos levam dados, não callbacks. Preserve callbacks legados fora do escopo
até migrar seus consumidores explicitamente.

ExpensesScreen abre edição com retorno `ExpenseEntity?`. Dashboard e Metrics
recarregam ao retornar da listagem mesmo sem mutação. O botão manual da Dashboard
abre Expense com retorno tipado e `returnToPrevious`; solicita
DashboardExpensesChanged somente após despesa confirmada, contexto montado e
mesma instância viva do DashboardBloc. Cancelamento não solicita atualização.

## Widgets nativos e Root

Blocs, eventos, estados e repositories usam nomes `WidgetLaunch*`/`WidgetSync*`
e arquivos `widget_*`, sem prefixo `Home`/`home_`. Navegação usa
`WidgetExpenseNavigation` e o serializer usa `isWidgetExpenseLaunch`.
O plugin `home_widget` e o parâmetro de URI `homeWidget=true` não mudam.

WidgetLaunchBloc usa `IWidgetLaunchRepository` para lançamento inicial
e observação. Infrastructure filtra URIs antes de expor sinais. AppWidget não
recebe clients ou streams nativos; seu mixin coordena navegação e lifecycle.

O intent fica pendente até o Navigator estar disponível. A navegação usa os
RouteStates reais de `popUntil`, preserva criação existente e distingue edição
por ID. Não há SessionRoutePolicy, HomeWidgetLaunchPolicy ou redirect deferral.

WidgetSyncStartedEvent mantém uma observação via `emit.onEach`, separada dos
refreshes restartable, e solicita atualização inicial. Cada refresh aguarda
`IWidgetSyncRepository.enable` e depois consulta Metrics sem filtros.
`setMonthly(active: true)` é apenas a API de habilitação do
client, não identidade. Não há timer, retry automático ou publicação fictícia.

O client preserva revisões e serialização para impedir publicações obsoletas.
Snapshot nativo contém somente mês e centavos na chave JSON `monthly_summary`.
Mês incompatível mostra “Abra para atualizar”. Widget não consulta HTTP nem cria
despesa em background. A virada do mês depende de timeline iOS e agendamento/eventos
Android, sujeitos ao sistema.

Android usa RemoteViews; iOS usa WidgetKit/SwiftUI, App Group
`group.com.bed.cordato` nos dois targets e famílias pequena/média.
Formatação monetária nativa não converte centavos em double. Layouts, contratos
e implementações nativas não mudam incidentalmente com a persistência.

## Settings, Information e interface compartilhada

SettingsScreen é StatelessWidget e navega por BuildContext. O módulo único sem
path oferece Perfil local, Informações e Apoio; não há logout, Bloc, provide,
seção Dados ou exportação.

Pix é apoio voluntário por QR Code estático/copiar código. Não há processamento,
confirmação ou consulta bancária pelo aplicativo.

Information é somente apresentação, sem repository, Bloc ou WebView. Termos e
Privacidade 2.1 de 21/11/2026 e Ajuda descrevem perfil/dados locais, sem cadastro,
backend, e-mails transacionais ou IA. Distinguem snapshot do widget, arquivos
exportados anteriormente, cópias do sistema e comunicações ao suporte. Não
prometem criptografia adicional, recuperação ou conformidade jurídica validada.

UI usa `material_ui`, componentes e tokens do core. Ícones passam pelo IconWidget;
botões reutilizam bounce compartilhado.
ImageWidget recebe somente assets locais, sem estratégia de rede ou loading remoto.
Presentes e doações preserva sua categoria e usa a imagem existente de Outros.
Recuos externos são 16 pixels além das
áreas seguras e teclado. Cabeçalhos recolhíveis de Expense/Information usam
slivers e respeitam movimento reduzido. Preserve rolagem, fonte ampliada,
ErrorScreen e semântica de imagens decorativas/skeletons.
ErrorScreen fica em `core/presentation/screens/error_screen.dart`, sem subpasta
`error/`.
Previews são manuais, com tema/localização reais e owner explícito dos recursos.

## Testes e verificação

Não há testes de UI, goldens, integração visual ou flows Maestro. Cobertura é
unitária de domínio, contratos, repositories, Blocs, validação, formatação,
arquitetura, DI/rotas e políticas nativas.

User/Expense/Metrics usam SQLite real em memória e arquivos temporários, inclusive
executors em isolate. Interceptors específicos em suporte das features permitem
falhas e Futures pendentes sem simular o banco ou os repositories concretos.
Clients são fechados antes da limpeza; testes verificam persistência, transações,
rollback, concorrência e refresh após commit. Isso não comprova durabilidade
auditada após falha de energia.

MetricsQueryInterceptor em `test/support/metrics/fakes/` controla falhas e leituras
pendentes, registrando SQL/parâmetros sem simular o DAO ou repository.
Blocs mockam contratos.
Composição global não mocka módulos inteiros e pode simular o canal nativo sem UI.

Testes aguardam operações e cancelam observações antes de limpar arquivos.
Registros de infraestrutura são tipados, sem parsing JSON legado.

`test/app_module_test.dart` verifica composição real, ownership, catálogo local,
Expense → Metrics → Root e Dashboard com SQLite em memória, sem montar UI.
`test/features/core/core_module_test.dart` verifica formatadores, client
nativo e registro lazy do DatabaseClient, sem abrir banco.

Use Completer/sinais observáveis para concorrência e `fake_async` para tempo.
Doubles públicos ficam em arquivos próprios de suporte. Cancele observações,
conclua Futures controlados e descarte recursos.

### Organização e espelhamento dos testes

O padrão é `lib/features/<feature>/<caminho>/<arquivo>.dart` →
`test/features/<feature>/<caminho>/<arquivo>_test.dart`. O nome do teste deve
identificar o arquivo ou tipo efetivamente testado. Suítes separadas por
responsabilidade não representam implementações adicionais e devem deixar
claro o alvo comum.

Mocks e adapters compartilhados ficam em `test/support/<feature>/`, com nome
do tipo e arquivo coerentes, sem doubles públicos dentro de `*_test.dart`.
Root e WidgetClient já usam nomes `widget_*` também nos testes e mocks.
`test/architecture/` cobre regras transversais, `test/tool/` cobre ferramentas
e `test/app_module_test.dart` cobre composição global; não precisam de um
arquivo correspondente em `lib/features/`. Políticas nativas seguem as pastas
JUnit/XCTest documentadas em AGENTS.md.

Desalinhamentos de nomes/pastas e suítes separadas por responsabilidade:

| Teste (relativo a `test/features/`) | Implementação/alinhamento |
| --- | --- |
| `dashboard/presentation/screens/dashboard/bloc/dashboard_bloc_test.dart` | `lib/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart`; a pasta extra `dashboard/` não existe na produção. |
| `dashboard/presentation/screens/dashboard/bloc/dashboard_state_test.dart` | `lib/features/dashboard/presentation/screens/bloc/dashboard_state.dart`; mesmo desvio de pasta. |
| `core/presentation/enums/app_route_test.dart` | Testa `route_enum.dart`; nome legado. |
| `core/presentation/widgets/toast/toast_icons_test.dart` | Testa ícones definidos em `toast.dart`; nome especializado, não um arquivo `toast_icons.dart`. |
| `expense/domain/enums/expense_category_enum_test.dart` | Nome legado; a implementação atual é `domain/enums/category_enum.dart`, com CategoryEnum. |
| `expense/presentation/screens/expenses/bloc/expenses_reregistration_test.dart` | Suíte de recadastro do `ExpensesBloc`, separada por responsabilidade. |
| `metrics/presentation/extensions/expense_metrics_pages_extension_test.dart` | Testa `ExpenseMetricsPagesExtension`, declarada em `expense_metrics_categories_extension.dart`. |
| `metrics/infrastructure/repositories/metrics_repository_persistence_test.dart` | Suíte de persistência de `metrics_repository.dart`, separada por responsabilidade. |
| `user/user_local_module_test.dart` | Suíte de persistência pela composição de `user_module.dart`, separada por responsabilidade. |

O DAO atual é `suggestions_dao.dart`, espelhado por `suggestions_dao_test.dart`.
Essa conferência não mede cobertura nem declara todas as implementações testadas.
Nomes/pastas ainda não foram integralmente alinhados; atualizar documentação
não autoriza mover ou consolidar testes sem uma tarefa de código.

### Execução

Verificações, nesta ordem:

```bash
flutter pub get
flutter analyze
flutter test --reporter failures-only
```

Testes nativos: `dart run tool/test_home_widget_native.dart`, opcionalmente
`android` ou `ios`, sem instâncias concorrentes de `dart run`.
Não substituem build nativo ou inspeção manual.

Verificação da consolidação do schema v1 em 23/11/2026:
`flutter pub get` e `dart run build_runner build` concluídos,
`flutter analyze` sem problemas e `flutter test --reporter failures-only` com
947 testes passando. Geração Drift validada para o schema 1. A suíte cobre
criação/reabertura, CHECK/enum, foreign keys e sequências, além de DAO, repository, isolate,
falhas/revisões e composição real Expense → Metrics → Root/Dashboard.
Não houve build ou homologação Android/iOS nesta entrega.
Registros anteriores de geração, migração e localtime ficam no
[histórico Drift](docs/history/drift-transition.md); resultados nativos antigos,
no [histórico local anterior](docs/history/local-transition.md).

## Limites e pendências

- Não há backup/restauração, migração remota, criptografia auditada ou garantia
  de recuperação.
- O perfil é criado sob demanda por User, não pelo client/Expense. Inicialização
  antes de criação por atalho e fechamento assíncrono pelo root estão pendentes.
- Exclusão/recriação de perfil, invalidação de operações e limpeza do snapshot
  não estão implementadas. Views e IA offline continuam futuras.
- Constantes e associações de autenticação, ferramenta de app links, declarações
  de microfone e `BASE_URL` do workflow foram removidos. Android não declara rede
  no manifest principal; debug/profile preservam a configuração de desenvolvimento.
- O workflow Android ainda exige `LOCALSTORE_READ_TOKEN`, embora as dependências
  atuais não usem o fork privado; revisão do YAML é tarefa separada.
- O espelhamento de nomes/pastas dos testes tem as exceções e pendências
  registradas acima.
- Builds atuais, assinatura, comportamento em dispositivo, widget, declarações
  de loja, publicação web e revisão jurídica não foram validados nesta revisão.

Essas pendências não autorizam restaurar fluxos removidos, enfraquecer testes ou
ampliar tarefas futuras para mudanças de comportamento sem autorização.
