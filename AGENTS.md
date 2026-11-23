# AGENTS.md

## Fonte de verdade e escopo atual

Estas regras orientam alterações no aplicativo Flutter Cordato e em seus testes.
A arquitetura canônica está em [ARCHITECTURE.md](ARCHITECTURE.md); execução,
estado do produto e pendências estão em [README.md](README.md).
Resultados anteriores estão no [histórico local](docs/history/local-transition.md)
e no [registro Drift](docs/history/drift-transition.md).

O aplicativo usa persistência exclusivamente local. `tostore` é o nome histórico
da branch de transição, não o banco vigente. Commit e push exigem solicitação
explícita; uma autorização passada não se estende a tarefas futuras.
Authentication, Session, Welcome, PocketBase, backend, worker, áudio, IA e Insight foram
removidos pelo usuário. CSV e compartilhamento sem consumidores também foram
removidos. Não restaure código, dependências, testes ou doubles desses fluxos
para satisfazer specs históricas ou sanar referências legadas.

O destino aprovado da persistência é Drift/SQLite, com a
fundação em `lib/features/core/infrastructure/clients/database/` e User/Expense/Metrics
migrados. O `coreModule` registra `DatabaseClient` como singleton lazy;
MetricsDao e SuggestionsDao usam a mesma instância. Composição global e suporte
de testes não importam Localstore; não restaure a dependência removida.
Não há identidade autenticada, `owner`,
sessão, backend, exportação ou backup/restauração pelo aplicativo.
Budget e Family são planejados. Não crie `identity` para reproduzir o backend
legado; `chat` está fora do escopo. Kotlin legado é referência de domínio,
não de estrutura Flutter.

Specs arquivadas e registros de execução são históricos. Em conflitos prevalecem
estas regras e ARCHITECTURE.md; consulte [openspec/README.md](openspec/README.md).
Não restaure Supabase/RPC, CommandIt, Either, data sources ou ownership antigo.
Pendências documentadas não autorizam mudanças incidentais de comportamento.

## Site público

`site/` contém o site HTML/CSS estático, independente de Flutter e sem backend.
Não há framework, JavaScript de runtime ou build para publicar. Siga também
[`site/AGENTS.md`](site/AGENTS.md) e [`site/ARQUITECTURE.md`](site/ARQUITECTURE.md)
ao alterá-lo. As regras de camadas, widgets e proibição de testes de UI deste
arquivo se referem ao app Flutter; HTML e E2E/acessibilidade do site
seguem os contratos próprios, sem introduzir testes visuais em `test/`.

Dependências npm são somente ferramentas opcionais de teste; lockfile, assets e
artefatos ficam dentro de `site/`. Publique apenas `site/public/`, sem build.
Não misture pubspec, DI ou targets nativos com o site. Preserve os arquivos
importados do site; código novo continua sem comentários explicativos.
Os workflows `site-test.yml` e `site-pages.yml` ficam em `.github/workflows/`;
mudanças neles exigem actionlint. Não altere o release Android incidentalmente.
Não publique, mude DNS ou visibilidade do repositório sem autorização explícita.
Os textos do site e de Information devem permanecer coerentes com o app local.

## Antes de alterar

- Leia a feature afetada, os componentes compartilhados usados e seus testes.
- Confira `git status` e preserve alterações existentes, inclusive fora do escopo.
- Faça a menor alteração que satisfaça a tarefa; não reformate áreas não relacionadas.
- Não faça commit, push, reset ou exclusões destrutivas sem solicitação explícita.
- Atualize contratos, consumidores, bindings e testes na mesma mudança.
- Registre bloqueios reais de análise, compilação e testes, sem ocultá-los.
- Não adicione comentários de linha, bloco ou documentação ao código. Explicações
  ficam em Markdown; preserve comentários existentes fora do escopo.
- Não amplie uma tarefa localizada para migrar outras features ou ownerships.

## DatabaseClient e transição para Drift

`DatabaseClient` estende o banco gerado pelo Drift; não é wrapper, CRUD genérico,
data source ou service locator. Não crie `IDatabaseClient`. Tabelas ficam em
`core/infrastructure/clients/database/tables/`; registros e companions gerados
ficam restritos à infraestrutura. Domain/application/presentation não importam
Drift. UserRepository e ExpenseRepository recebem a instância por construtor;
MetricsDao recebe a mesma instância compartilhada.

Schema atual versão 1: `profiles` tem `id`, `name`, `seed`; índice único sobre
constante permite no máximo um perfil. `expenses` possui `profile_id` obrigatório
com `ON DELETE CASCADE`. IDs das duas tabelas são inteiros gerados pelo SQLite com
`INTEGER PRIMARY KEY AUTOINCREMENT`; `profile_id` também é inteiro. Não gere
IDs no app nem reinicie sqlite_sequence. Despesas têm centavos inteiros positivos, categoria padrão
`other`, descrição anulável e data civil textual `YYYY-MM-DD` validada pelo SQLite,
com default SQL date('now', 'localtime') quando omitida.
A semântica das categorias continua pertencendo ao CategoryEnum de Expense.
O core reforça integridade com CHECK SQL contendo os mesmos valores textuais,
sem importar Expense ou duplicar o enum. O teste arquitetural
`test/architecture/expense_category_schema_test.dart` compara as listas e testa
inserção de todas as categorias. Categoria desconhecida, vazia ou nula é rejeitada
pelo SQLite; novas categorias exigem atualização do enum, CHECK e migração.

A conexão padrão é lazy, em Application Support/cordato.sqlite, com execução em
isolate pelo NativeDatabase. Foreign keys são habilitadas antes do uso em toda
abertura, inclusive executors injetados. Testes usam SQLite real em memória ou
arquivo temporário, aguardam operações e fecham o client antes da limpeza.
`DatabaseClient.configureConnection` registra cordato_lower como função escalar
determinística usando String.toLowerCase de Dart, preservando Unicode sem remover
acentos. A conexão padrão instala o setup no isolate. Executors nativos injetados
que usam sugestões devem receber `setup: DatabaseClient.configureConnection`
antes de interceptors; SQL não registra funções Dart. O core não importa DAOs
das features. Essa função não altera schema nem exige migração.
Não há migração de Localstore/ToStore nem leitura/exclusão de seus arquivos.
Sem usuários, o schema não publicado foi consolidado na versão 1 por decisão
do usuário, com autoincrement, default de data local e CHECK de categorias.
Não há migrações de versões SQLite experimentais anteriores nem seus testes/fixtures.
Arquivos experimentais incompatíveis, inclusive versões 2/3 ou versões 1 com
outras definições, precisam ser recriados manualmente; o app não os apaga,
não faz downgrade nem reset automático.
Novas versões do schema exigem migrações explícitas e testes; não faça reset
destrutivo como fallback. Regenere com `dart run build_runner build` e versione
`database_client.g.dart`. Comentários emitidos pelo gerador não são código manual.
Regras de nomenclatura manual não se aplicam a `*.g.dart`; não edite arquivos
gerados para remover nomes emitidos pelo Drift. O teste arquitetural de nomes
continua verificando todos os arquivos Dart escritos à mão.
Preserve o construtor convencional atual do client; mudanças nessa declaração
exigem validar a geração com drift_dev, não somente a análise Dart.

Contrato aprovado para a futura integração: antes de operar, existe um perfil
com ID novo, nome Cordato e seed aleatória. Editar nome/seed preserva ID.
Apagar os dados remove o perfil e seus dependentes por cascade e cria outro
perfil padrão com novo ID/seed, na mesma transação. Isso não é autenticação.
O schema garante no máximo um perfil; UserRepository o inicializa sob demanda,
sem bootstrap externo. Troca transacional por exclusão, invalidação de tarefas
antigas e limpeza do widget ainda não estão implementadas. Views e IA ficam
fora desta etapa.
O registro usa `addLazySingleton<DatabaseClient>(DatabaseClient.new)`; não abre
storage nem cria perfil ao resolver. O Modular 7 atual não expõe callback de
descarte no ModularContext: não presuma que dispose do injector aguarde `close`.
Testes que resolvem o client fecham explicitamente a instância. A coordenação do
fechamento assíncrono no root permanece pendente, sem ownership pelas screens.
Não prometa criptografia, apagamento físico irrecuperável ou backup.

### Bootstrap atual e limite do legado

`main` monta o app sem inicializar perfil ou storage. `appModule` é estático;
o core registra DatabaseClient lazy, formatadores e IWidgetClient. O registro
de Localstore foi removido. Metrics e composição global usam o mesmo SQLite,
sem wrappers ou inicializadores adicionais. O contrato do fork anterior e resultados antigos
ficam em docs/history, não são instruções de instalação para o checkout atual.

## Contratos locais das features

User, Expense e Metrics abaixo usam Drift sobre o mesmo banco.

### User

UserEntity possui `id`, `name` e `seed` obrigatórios, sem e-mail ou autenticação.
IUserRepository expõe `get` e `update({name, seed})`, sem exclusão de conta.
UserRepository recebe DatabaseClient e usa a tabela `profiles`. `get` consulta
e cria o perfil ausente em transação, com nome Cordato e seed de 16 bytes de
Random.secure em hexadecimal. O ID é inteiro, gerado pelo banco e obtido por
insertReturning; UserEntity e UserResponse usam int para ID. Leituras seguintes
preservam o perfil; chamadas concorrentes no banco compartilhado não duplicam a criação.
Não crie inicializador externo, identidade, sessão ou cache adicional.
Dados antigos não são migrados. UserResponse converte o registro tipado do Drift
em entidade pura, sem parser JSON legado. `seed` não é anulável; texto vazio é
preservado. UI usa seed, mantendo avatar como conceito visual.

Updates executam leitura/criação, atualização somente dos campos fornecidos e
leitura do perfil final na mesma transação, preservando ID e campos omitidos.
Sem campos apenas leem (ou inicializam se ausente), sem UPDATE. Não crie fila de
Futures ou estado pendente. Falhas operacionais BUSY, LOCKED, READONLY, IOERR,
FULL, CANTOPEN e FileSystemException viram UserException segura. Erros SQL,
constraints, corrupção, parsing e programação propagam; erros remotos do Drift
são desembrulhados preservando causa/stack. Não há retry automático nem reset.
Mensagens nativas do banco não chegam à UI.

Testes usam SQLite real em memória/arquivo, inclusive isolate, transações,
concorrência e persistência. `ProfileQueryInterceptor` em `test/support/user/fakes/`
permite falhas e operações pendentes sem mockar o repository concreto.

User/Edit mantêm factories estáveis e ownership dos Blocs pela screen.
Dashboard consulta somente o contrato atualizado. Rotas User não exigem sessão.
User possui um único `userModule`, sem path, com binds e rotas completas.
Não separe dependências em outro módulo nem restrinja o repository ao lifecycle
da rota: Dashboard o consome sem visitar User.
Nome é validado na apresentação com 2–32 code points Unicode após trim;
Bloc/repository não normalizam a entrada.

### Expense

ExpenseRepository recebe DatabaseClient, IWidgetClient e SuggestionsDao
diretamente. O DAO em `expense/infrastructure/daos/` estende DatabaseAccessor,
usa o mesmo banco e é registrado como singleton lazy no expenseModule. Não crie
interface, service ou wrapper CRUD para o DAO. Ele retorna registros tipados
somente para infrastructure; mapeamento e falhas de aplicação ficam no repository.
O arquivo do DAO é `expense/infrastructure/daos/suggestions_dao.dart`.
Expense usa `expenses`, IDs int autoincrementais e `profile_id` inteiro com cascade.
Categorias usam o enum puro `CategoryEnum` em `expense/domain/enums/category_enum.dart`;
não restaure o nome anterior ExpenseCategoryEnum nos consumidores atuais.
IDs de entidades, sugestões, contratos, eventos, estados e argumentos de edição
são int; Metrics mantém seu ID sintético textual. Não exponha profile_id na UI.
Criação usa INSERT SELECT FROM profiles RETURNING, sem SELECT preparatório;
ausente gera ExpenseException com
`profile_not_found`, sem criar perfil nem depender de UserRepository. A inicialização
continua pertencendo a User. Abrir o formulário antes de User inicializar não
garante criação: falha segura permite retry manual, sem bootstrap incidental.

Centavos inteiros positivos, categoria padrão other, descrição anulável e data
civil `YYYY-MM-DD` são preservados. O default hoje pertence ao SQLite, usando
date('now', 'localtime'), não DateTime.now no repository. Create sem data omite
a coluna para usar o default; data explícita preserva seus componentes civis.
Validação de centavos pertence ao repository. Datas fora dos anos 1–9999 são
ArgumentError. Descrição nula vira
texto vazio na projeção; trim ocorre somente na criação/edição.

Listagem filtra, ordena e pagina no SQL, usando offset/limite mais um. Ordenações
aceitam somente campos conhecidos; padrão data/ID decrescentes, desempate de
outras ordenações por ID numérico ascendente. Descrição nula ordena como vazia.
Filtros incluem os dois dias civis e o perfil por subconsulta, aproveitando o
índice expenses_profile_date; não há snapshot entre páginas da listagem.

Sugestões usam uma consulta SQL no DAO, sem loop, OFFSET ou transação explícita.
CTE materializada filtra perfil, descrições válidas e correspondência literal com
instr(cordato_lower(description), parâmetro lowercase), ordena por data/ID
decrescentes e limita a 30. ROW_NUMBER por descrição lowercase deduplica depois
do limite, preservando a ocorrência mais recente e a ordem final. Query é sempre
parâmetro vinculado, não LIKE ou regex; Unicode segue Dart sem remoção de acentos
ou normalização adicional. A instrução já fornece snapshot consistente; uma
busca sem correspondências pode percorrer o histórico, mas só retorna até 30
registros. Aceitar sugestão aplica categoria inclusive other, preservando data/valor.

ID inexistente gera ExpenseException com expense_not_found pelo retorno vazio
de UPDATE RETURNING ou pela contagem zero do DELETE. Updates gravam somente
campos fornecidos em uma instrução, preservando perfil/demais campos inclusive
sob concorrência. Create/update mantêm transação para reverter se o mapeamento
do retorno falhar e publicar somente após commit. DELETE é uma instrução atômica
sem leitura ou transação explícita adicional.
`_hasUpdates` verifica presença por null, não por valor verdadeiro/texto não vazio.
Sem campos apenas leem, sem refresh; descrição vazia e categoria other são updates.
Mutações solicitam refresh nativo somente
após commit, fora do tratamento de falhas de storage e sem alterar formato nativo.
Falhas operacionais SQLite/filesystem seguem a classificação segura de User;
SQL, constraints, corrupção, parsing e programação propagam, sem retry ou reset.
ExpenseResponse/ExpenseSuggestionResponse mapeiam registros tipados, sem JSON
legado. Testes usam SQLite real e ExpenseQueryInterceptor em suporte da feature
para falhas/operações pendentes. Expense/Expenses preservam ownership pela screen
e sugestões pelo provide. Não restaure CSV ou compartilhamento.

### Metrics

Metrics é projeção local somente leitura de `expenses`, sem tabela própria,
cache, triggers ou escritas em Expense. MetricsRepository recebe MetricsDao e
IWidgetClient. MetricsDao em `infrastructure/daos/metrics_dao.dart` estende
DatabaseAccessor sobre o DatabaseClient compartilhado, registrado singleton lazy
no metricsModule. Não crie interface, service ou wrapper CRUD para o DAO.
Uma única consulta parametrizada filtra perfil por subconsulta e os dois limites
civis inclusivos do mês, usando SUM(amount), MIN(amount), GROUP BY e ORDER BY category.
Os limites inclusivos suportam até dezembro de 9999. Não há View, alteração de
schema, loop, paginação ou transação explícita. O índice expenses_profile_date
atende ao filtro; a instrução oferece snapshot consistente.
Registros tipados ficam na infraestrutura; validação, response e falhas de
aplicação pertencem ao repository.
Sem datas usa o mês atual;
intervalos incompletos ou não mensais geram MetricsException antes da leitura.
Anos fora de 1–9999 geram ArgumentError antes de acessar banco/widget.

Total e distribuição vêm dos mesmos grupos; centavos são inteiros e percentuais
são calculados em Metrics sem arredondamento antecipado. Categorias têm ordem
textual determinística; ID sintético `monthly-yyyy-MM` é estável.
Grupos usam `ExpenseCategoryMetricsResponse` em `infrastructure/responses/`;
repository monta o resumo mensal, sem camada `projections/`.
Sem agrupamento categories é null; mês vazio agrupado tem lista vazia imutável.
Entidades mensal/de categoria e response usam `total` em centavos, não
`totalAmount`. Grupos são construídos em SQL, sem parser JSON de agregados;
despesas usam `amount`.
`ExpenseMetricsPagesExtension` está em `expense_metrics_categories_extension.dart`.
Paginação visual remove categorias não positivas, ordena por total decrescente
com desempate estável e agrupa até três; a dica só aparece na última página com
uma categoria quando existem várias páginas.

Infrastructure valida categorias pelo enum puro de Expense, sem importar sua
implementação ou criar dependência reversa. Parsing inválido, categorias
desconhecidas, centavos não positivos, somas inválidas e overflow por categoria
ou mensal são inesperados. Overflow de SUM propaga como erro SQLite, sem
publicar zero fabricado; MIN(amount) permite rejeitar centavos não positivos
mesmo com soma positiva se constraints forem burladas. Isso não comprova auditoria de corrupção.

Falhas operacionais SQLite/filesystem seguem a classificação segura de User/Expense,
com desembrulho de causas remotas do Drift e preservação de causa/stack inesperadas.
Sem mensagens nativas na UI, fallback para zero ou retry automático. Só o mês atual captura
revisão antes da leitura e aguarda publicação nativa, inclusive zero válido.
Publicação fica fora do tratamento de falhas de storage.
Testes usam SQLite real em memória/arquivo/isolate e MetricsQueryInterceptor em
`test/support/metrics/fakes/` para falhas, SQL/parâmetros e operações pendentes.
Preserve IMetricsRepository, UI, ownership, módulo único sem path, formatos e
revisões nativas.

### Dashboard, Settings e Information

Dashboard não contém áudio, speech, gravação, toque longo ou dependências de
microfone, inclusive em previews. O botão manual usa IconButtonWidget do core,
sem controller/lifecycle de captura.
ActionButtonDashboardWidget abre Expense por BuildContext com retorno tipado e
`returnToPrevious`; só solicita DashboardExpensesChanged após retornar despesa
confirmada, com contexto montado e mesma instância viva do DashboardBloc.

Settings usa módulo único sem path e rotas completas, sem autenticação.
SettingsScreen é StatelessWidget, sem Bloc ou provide, e navega por BuildContext.
Não restaure LogoutBloc, confirmação de saída, seção Dados, exportação ou
callbacks de navegação na rota.

Information é somente apresentação. Os documentos 2.1 de 21/11/2026 descrevem
perfil/dados locais, sem cadastro, backend, e-mails transacionais ou IA.
Distinga arquivos exportados anteriormente de backup restaurável, suporte de
acesso remoto ao banco, cópias do sistema de backup próprio e apoio Pix de
processamento de pagamentos. Não prometa criptografia, recuperação ou
conformidade jurídica já verificadas. Backup/restore nativo será tarefa posterior.

### Root e widgets nativos

Root não depende de Session/Authentication. `main` abre Dashboard sem inicializar
perfil/storage; `/` é fallback visual e sua política pura aponta à Dashboard.
AppWidget possui somente WidgetLaunchBloc e WidgetSyncBloc por factories
estáveis, com fechamento no lifecycle.
Tipos de integração usam `WidgetLaunch*`/`WidgetSync*` e arquivos `widget_*`,
incluindo eventos, estados, repositories e testes, sem prefixo `Home`/`home_`.
O parâmetro nativo `homeWidget` da URI e o plugin `home_widget` permanecem.

O atalho fica pendente até Navigator estar disponível e abre Dashboard → criação,
preservando criações sem confundi-las com edição. Use RouteStates reais de
`popUntil`: no Modular 7, `routeState` representa a base e Page.name não identifica
rotas empilhadas. Não restaure políticas de sessão ou redirect deferral.

Launch usa IWidgetLaunchRepository para leitura/observação; infrastructure
filtra URIs antes de expor sinais. AppWidget não recebe client/streams nativos;
plugin não entra na apresentação.

WidgetSyncStartedEvent observa pedidos de atualização com `emit.onEach` em
handler contínuo e solicita o resumo inicial. Refreshes restartable habilitam a
publicação por IWidgetSyncRepository.enable antes de consultar Metrics.
O adapter usa `setMonthly(active: true)` apenas como habilitação do
client, não identidade ou sessão. Não há refresh periódico ou retry automático.

Expense sinaliza mutações pelo client compartilhado sem importar Metrics/Root.
Root compõe os contratos em WidgetSyncRepository. Preserve revisões e
serialização para bloquear respostas obsoletas. Snapshot contém somente mês e
centavos, sem credenciais; mês incompatível mostra “Abra para atualizar”.
iOS usa `group.com.bed.cordato` nos dois targets. Não faça HTTP ou cadastro em
background no widget nem converta dinheiro para double ao formatá-lo.
Não altere formatos/implementações nativas incidentalmente.

## Camadas e arquivos

```text
lib/features/<feature>/
  <feature>_module.dart
  domain/
    entities/
    enums/
    value_objects/
  application/
    exceptions/
    repositories/interface_<feature>_repository.dart
  infrastructure/
    repositories/<feature>_repository.dart
    responses/
    daos/
  presentation/
    screens/<screen>/
      <screen>_screen.dart
      bloc/
      mixins/
      widgets/
    validators/
    widgets/
    previews/
```

- Crie somente diretórios necessários; features visuais não precisam de domínio
  ou repository. Não adicione use cases, inputs, outputs, services, data sources,
  BaseBloc ou stores globais sem necessidade concreta aprovada.
- Domain é puro: sem Flutter, Bloc, SDK, storage ou application.
- Application contém contratos e exceções, sem adapters/UI. Contratos de
  repository não ficam em `domain/repositories/`.
- Infrastructure implementa contratos, usa DatabaseClient (User/Expense) ou
  MetricsDao sobre o banco compartilhado (Metrics) e converte
  payloads em tipos próprios. Capacidades nativas usam clients do core.
  `IWidgetClient` e `WidgetClient` ficam no mesmo
  `core/infrastructure/clients/widget_client.dart`; isso não muda a localização
  dos contratos de repository em application nem permite importar clients na UI.
- Presentation conhece contratos/exceções, nunca repositories concretos ou clients.
- Módulos fazem composição e podem importar implementações concretas.
- Core contém capacidades compartilhadas; não mova regras para contornar limites.
- Dashboard pode compor contratos consultados. Expense não depende de outros
  contextos financeiros. Family futura consulta contextos por contratos/adapters,
  sem dependência reversa.

Dinheiro é inteiro em centavos de BRL, nunca double. Gasto não referencia
orçamento; pertencimento deriva da data civil. Orçamentos vivos da mesma pessoa
não podem se sobrepor. Família não concede escrita nos dados de outro membro;
sair/encerrar família não altera dados individuais. Visões combinadas são derivadas.
Essas invariantes futuras não comprovam funcionalidades implementadas.

## Repositories e falhas

- Use parâmetros nomeados e tipos simples. Repository/Bloc não normalizam
  entradas que pertencem ao formulário.
- Retorne Future<void> quando somente a conclusão importa; não exponha DTO,
  envelope ou tipo do SDK na apresentação/application.
- Parsing e payload pertencem a infrastructure, com casts estritos. Não esconda
  TypeError/FormatException como falhas de negócio.
- Converta somente falhas esperadas para exceções específicas de aplicação.
  Não introduza catch genérico para mascarar erros inesperados.
- Preserve ordem e metadados dos erros em ErrorsEntity, incluindo code, pointer
  e parameter quando presentes. Não converta falhas de storage em sucesso.
- UI usa mensagens locais em português, nunca diagnósticos nativos diretamente.
  Formatação por campo/operação pertence a formatters puros da feature.
  ErrorMessageFormatter contém somente mensagens compartilhadas.
- Preserve ErrorsEntity original nos contratos/estados e teste formatters sem UI.
- Não coloque segredos, tokens ou credenciais em código, fixtures reais ou logs.

## Bloc, screens e lifecycle

- Use Bloc para operações assíncronas, sem commands. Eventos/estados ficam junto
  ao Bloc da screen; prefira eventos concretos e estados sealed imutáveis.
- Derive disponibilidade das ações do estado; não espelhe loading/erro/resultado
  em flags locais. Defina concorrência explicitamente.
- Submissões droppable descartam eventos durante envio; sucesso bloqueia novos
  envios e falha permite retry manual, sem retry automático.
- Falha esperada preserva ErrorsEntity. Inesperada usa fallback seguro e
  `addError(error, stackTrace)`, sem client/callback de telemetry no Bloc.
- Após await respeite `isClosed` e `emit.isDone`. Fechamento não cancela storage.
  Use lifecycle nativo, sem flags paralelas ou override de close para imitá-lo.
- Blocs de página novos/explicitamente migrados usam `provide` e
  `scope.addBloc<MyBloc>(MyBloc.new)` pela BlocScopedExtension. Rota lê com
  `context.read` e entrega à screen; Modular é o único dono do fechamento.
  Não duplique bind no módulo. Testes/previews têm owner externo explícito.
- Fluxos ainda com ownership pela screen recebem factory estável, criam em
  initState, fecham em dispose e substituem em didUpdateWidget somente se a
  factory mudar. Rebuild não cria outro Bloc. BlocProvider.value não muda o owner.
- Use BlocBuilder para renderizar e listeners/consumers para efeitos únicos.
  Não navegue, envie operação ou mostre toast durante build.
- Formulário mantém entrada, validação e erros por campo; preserve entrada na
  falha e limpe somente o erro do campo editado. Desabilite conforme o estado.
- Ação next aponta explicitamente ao FocusNode do próximo campo por
  onEditingComplete. Mixin possui/descarta nós; ação final preserva submissão.
- Extraia lifecycle, controllers, timers e handlers substanciais para mixin
  específico com `on State<Widget>`. Screen mantém composição visual.
  Mixin não acessa repository/storage e descarta recursos que cria.
- Helpers usam context do próprio State, sem repasse redundante. Lógica pura
  de StatelessWidget pode usar mixin `on StatelessWidget`, sem recursos mutáveis
  ou operações assíncronas.

## Dart, imports e componentes

- Não use `var`, inclusive em testes/previews/ferramentas. Use final quando
  não há reatribuição e tipo explícito para variáveis mutáveis.
- Não nomeie variáveis, parâmetros, campos ou getters como `result`.
  Use nomes que expressem o dado/operação, não outro nome genérico.
- Métodos têm responsabilidade identificável. Separe validação, erros de campo,
  envio de eventos, feedback e navegação em handlers extensos.
- Separe etapas por linhas em branco. Use chaves em if/else/laços; prefira guard
  clauses e switch/pattern matching. Evite ternários aninhados e cascatas de if.
- Extraia alternativas visuais substanciais em widgets públicos em arquivos
  próprios, sem árvores de ternários; preserve foco/controllers/acessibilidade.
- Não crie services/stores/flags/hierarquias de mixins/helpers genéricos apenas
  para reduzir linhas. Revise consumidores sem deslocar complexidade.
- Flutter >=3.50.0, Dart ^3.14.0. Use primary constructors em declarações novas
  elegíveis, campos imutáveis explícitos e final; preserve const.
  Parâmetros só de inicialização não induzem campos. Avalie semanticamente
  construtores com lifecycle/múltiplos caminhos generativos.
- Não introduza primary constructor vazio em interfaces, mixins, States ou mocks.
- Widgets novos são públicos, final, sufixo Widget, arquivo próprio, parâmetros
  nomeados, required e super.key; const quando possível.
- Imports da aplicação usam `package:cordato/`, não relativos de lib.
- UI Material usa `package:material_ui/material_ui.dart`, não flutter/material.
  Imports Flutter especializados são permitidos para símbolos não exportados.
  Remova imports sem uso; não crie barrels.
- Reutilize botões, fields, BounceWidget, animações/imagens do core.
  Botões compartilhados incorporam bounce.
- Ícones usam Icons/IconData Material pelo IconWidget estático do core; não
  adicione bibliotecas/controllers/scopes/listeners para animá-los.
  Preserve semântica, tema e estado desabilitado.
- Use context.colors, context.typography e context.radius; sem tokens/extensões
  duplicados ou fundo fixo de Scaffold sem necessidade.
- Contratos de formatação `IDateFormatter`/`IMoneyFormatter` ficam junto às
  implementações em `date_formatter.dart`/`money_formatter.dart`, sem arquivos
  `interface_*` separados.
- Recuos externos de telas/bottom sheets são 16 pixels além de áreas seguras e
  teclado. Voltar de 48 ocupa leading de 80 com simetria horizontal de 16.
  Cabeçalho expandido começa 16 abaixo da toolbar. Preserve espaçamentos internos,
  reservas para ações flutuantes e largura de leitura.
- Animações respeitam MediaQuery.disableAnimationsOf (Android) ou reduceMotionOf
  (iOS), sem substituir uma preferência pela outra.
- Assets ficam em AssetEnum/pubspec.yaml; use ImageWidget.
- Reutilize ErrorScreen; preserve rolagem, fonte ampliada e exclusão semântica
  de imagens decorativas/skeletons.
  O arquivo atual é `core/presentation/screens/error_screen.dart`.

## Módulos e navegação

Use `createModule` do Modular 7. Registre contratos apontando a implementações.
Blocs screen-owned usam factory/tear-off estável como `inject<ExpensesBloc>`,
sem closures novas por rebuild nem singleton compartilhado entre telas.

Dependências entre features exigem binds disponíveis sem visitar rotas irmãs.
User, Expense, Metrics e Settings têm módulo único sem path; não fragmente nem
use path `/` em features irmãs. Módulos com paths exclusivos permanecem até
migração explícita. Teste resolução, não apenas catálogo.

Navegação nova pertence ao widget/mixin por BuildContext, não callbacks de rota
ou Modular.to. Preserve callbacks legados fora do escopo até migrar consumidores.
Argumentos transportam dados. Use `pushNamed<T>` e `pop` com retorno tipado
para dados confirmados. ExpensesScreen recebe ExpenseEntity? da edição.
Dashboard/Metrics recarregam ao voltar da listagem, mesmo sem alteração, sem
interceptar voltar/gesto para transportar flags. Callbacks visuais locais são permitidos.

Strings Android usam `<tipo>_<contexto>_<descricao>` em snake_case inglês,
`res/values/strings_<contexto>.xml`; strings.xml pertence a app.
Prefixos: failure_, success_, label_, action_, cd_, msg_, config_.
Agrupe tipos por linhas em branco sem comentários; não misture cores/estilos.
Configuração técnica usa translatable=false. Preserve placeholders posicionais,
URLs e referências XML/Kotlin/testes ao renomear. Consulte android/README.md.

## Testes obrigatórios

Espelhe produção em `test/features/<feature>/`. Não adicione Python.
Para cada arquivo testado, preserve o caminho relativo e acrescente `_test`
ao nome: `lib/features/.../widget_launch_bloc.dart` corresponde a
`test/features/.../widget_launch_bloc_test.dart`. Suítes separadas por
responsabilidade devem identificar a implementação comum, sem sugerir um
arquivo de produção inexistente. Testes arquiteturais, de ferramentas,
composição global e políticas nativas têm organização própria.
Os desalinhamentos existentes estão registrados em
[ARCHITECTURE.md](ARCHITECTURE.md#organização-e-espelhamento-dos-testes);
documentá-los não os torna padrão nem autoriza reorganização incidental.
Não mantenha/crie testes de UI, goldens, integração visual ou flows Maestro.
Previews manuais permanecem; preserve testes unitários e arquiteturais.

| Alvo | Cobertura mínima |
| --- | --- |
| Domain | Invariantes, imutabilidade e semântica, sem SDKs. |
| Application | Contratos puros e preservação de erros nas exceções. |
| Repository | SDK real, conversão, operações, parsing, falhas esperadas/inesperadas e persistência. |
| Bloc | Estado inicial, sequência, delegação, erros, concorrência, retry e fechamento pendente. |
| Modular/rotas | Catálogo, resolução e factories sem UI. |
| Architecture | Imports, camadas, contextos e contratos; DI/rotas têm testes próprios. |

- Use mocktail, bloc_test e flutter_test. Blocs mockam contrato de repository.
- User/Expense/Metrics usam Drift real com interceptors específicos de testes,
  conforme seus contratos acima. Feche o client antes de remover arquivos;
  não restaure doubles ou suporte de storage Localstore.
- Composição global não simula módulos inteiros; pode simular canal nativo,
  sem montar UI. Preserve cobertura real de Metrics/composição.
- Testes do core verificam formatadores/client nativo e registro do DatabaseClient.
  Teste do app verifica instância única no root e ausência de fechamento pela DI.
- Não restaure testes/doubles exclusivos de PocketBase, sessão/identidade,
  HTTP/Dio, recording, áudio, CSV ou compartilhamento removidos.
- Testes de acessibilidade não enumeram telas removidas, não fazem skip por
  existência nem relaxam asserções dos componentes atuais.
- Use Completer/sinais observáveis, não sleeps arbitrários para concorrência.
- Suítes extensas usam groups por responsabilidade. Separe preparo/ação/asserts;
  helpers locais reduzem montagem repetida. Cenários com expectativas distintas
  não usam condicionais nas asserções. Matrizes homogêneas têm nomes claros.
- Tempo/debounce usa fake_async sem WidgetTester; crie/descarte recursos na zona.
- Mocks/fakes/adapters públicos ficam em arquivo próprio em
  `test/support/<feature>/mocks/` ou `fakes/`, nunca em *_test.dart ou lib.
  Reutilize double por contrato; stubs/fixtures são locais. Imports de suporte
  usam relativos explícitos.
- Cancele subscriptions, conclua Futures controlados e descarte recursos.
- Políticas nativas usam JUnit em android/app/src/test e XCTest em test/native/ios,
  compilando produção sem UI. Execute `dart run tool/test_home_widget_native.dart`
  com argumento opcional android/ios. Swift exige macOS/Xcode.
  Não execute instâncias concorrentes de dart run: build hooks compartilham arquivos.

## Previews e verificação

Previews usam @CordatoPreview, tema real, localização e toast compartilhados em
presentation/previews. Fakes não usam rede/storage/mocktail. Cada recurso tem
owner único; sugestões de Expense recebem owner externo. Use PreviewResourceWidget
quando o recurso não pertence à tela. `dart run tool/widget_preview.dart` serve
o catálogo; `.widget_preview/` não é versionado.

Quando aplicável execute, nesta ordem:

```bash
flutter pub get
flutter analyze
flutter test --reporter failures-only
```

Verificação focada inclui test/architecture e a feature. Registre comandos,
resultados e bloqueios prévios. Não anuncie homologação nativa por testes
unitários. Mudança exclusivamente documental não exige app/suíte Flutter.

Release Android usa `.github/workflows/android-release.yml`, manual e somente
main, sem publicar no Play ou commits de versão. Versão visível vem do pubspec;
tool/android_release_version.sh define código por GITHUB_RUN_NUMBER + 5.
Reexecuções mantêm código; novo código exige novo dispatch. Não altere offset
ou recrie workflow sem considerar maior código já usado no Play.
Secrets pertencem a android-release. Mudanças de workflow exigem actionlint;
script exige shellcheck, além das verificações Flutter aplicáveis.
O YAML ainda contém o passo legado de `LOCALSTORE_READ_TOKEN`/helper Git para
`bed72/localstore`, embora o pubspec atual não use o fork. Não restaure a
dependência nem solicite cadastrar esse secret para instalar Drift. A revisão
do workflow é tarefa separada e exige as validações acima. Preserve os limites
de credenciais em revisões que ainda usam o helper: token só em variável de
ambiente, nunca em URL, arquivo ou log. Setup/estado estão em android/README.md.
BASE_URL não configura o banco local nem autoriza integração remota.

## Revisão e documentação

Mudanças estruturais atualizam ARCHITECTURE.md; convenções/testes atualizam este
arquivo; produto/configuração atualizam README.md; release atualiza android/README.md.
Preserve specs/changes históricas; identifique precedência em openspec/README.md.
Resultados anteriores ficam em docs/history, sem se tornarem instruções vigentes.
Componentes usados exclusivamente em previews de recursos removidos, seus fakes e
testes não devem ser restaurados. Metrics não tem Bloc próprio: Dashboard e Root
consultam seu repository. ImageWidget recebe somente caminhos de assets locais.
Erros de formulário locais usam os códigos produzidos pelos repositories, sem
classificação HTTP ou pointers do backend antigo; preserve os metadados originais.

Antes de concluir confira camadas, contrato puro, Bloc sem SDK, efeitos fora do
build, ownership único, testes corretos, documentação coerente e ausência de
comentários novos no código. Não enfraqueça arquitetura para aparentar conformidade.

Welcome não possui arquivos, composição ou constante de rota; não restaure
referências nos testes. Rotas/associações de autenticação, permissões de microfone,
permissão de rede no manifest principal e BASE_URL no workflow foram removidos.
Preserve o scheme cordato e o App Group usados pelo widget nativo.
