# Arquitetura

Estado canônico da versão local na branch `tostore`, revisado em **23/11/2026**.
Convenções obrigatórias: [AGENTS.md](AGENTS.md). Execução e limites do produto:
[README.md](README.md). Registros anteriores:
[histórico da transição](docs/history/local-transition.md).

## Decisão canônica

A persistência escolhida passa a ser Drift/SQLite. A entrega atual é somente a
fundação em `lib/features/core/infrastructure/clients/database/`, com tabelas e
testes reais. O `coreModule` registra o client como singleton lazy. Repositories,
módulos e contratos de features ainda são legados do
Localstore. Sua dependência foi retirada pelo usuário; esta etapa intermediária
não compila o app completo e não representa migração funcional concluída.
Não há migração dos dados anteriores, por decisão explícita.

### Fundação Drift

```text
core/infrastructure/clients/database/
  database_client.dart
  database_client.g.dart
  tables/
    profiles_table.dart
    expenses_table.dart
```

`DatabaseClient` é o próprio banco tipado Drift, não um wrapper. Não possui
interface, CRUD genérico ou regras de negócio. O `coreModule` registra
`addLazySingleton<DatabaseClient>(DatabaseClient.new)`, compartilhando a instância
por DI sem abrir storage. Na integração futura será recebida por construtor nos repositories.
Tipos gerados não atravessam contratos de application nem entram em domain/UI.
O futuro owner da conexão deve aguardar operações e chamar `close`; screens não
são donas do banco. O ModularContext atual não expõe callback de descarte nos
registros: a coordenação de fechamento assíncrono pelo root permanece pendente.
Não se presume que dispose do injector feche o banco. Testes de resolução fecham
o client explicitamente, sem abrir storage.

A conexão padrão abre sob demanda `cordato.sqlite` em Application Support e
executa SQLite em isolate separado. Executors podem ser injetados nos testes.
`PRAGMA foreign_keys = ON` roda em cada abertura. Schema inicial versão 1 cria
tabelas e índices, sem inicializar perfil, ler Localstore ou apagar arquivos
legados. Evoluções exigem migrações explícitas e testadas, nunca reset automático.

| Tabela | Contrato |
| --- | --- |
| `profiles` | ID textual não vazio, nome e seed obrigatórios; índice único sobre constante garante no máximo um perfil, mesmo com IDs diferentes. |
| `expenses` | ID textual não vazio, `profile_id` obrigatório referenciando `profiles.id` com `ON DELETE CASCADE`, `amount` inteiro positivo em centavos, categoria não vazia com default `other`, descrição anulável e `occurred_on` civil `YYYY-MM-DD`, entre anos 0001–9999. |

O índice `expenses_profile_date` cobre perfil/data/ID. Categorias permitidas
continuam sendo regra do domínio de Expense, não um enum duplicado no core.
Não há default implícito para IDs/data; repositories deverão fornecê-los.
Datas civis não são timestamps nem sofrem conversão de fuso.

O contrato de produto aprovado é ter um perfil ativo antes de operar, inicialmente
com ID novo, nome `Cordato` e seed aleatória. Edições preservam o ID. Apagar os
dados deve remover perfil/dependentes e criar outro perfil padrão, com novos
ID/seed, na mesma transação. A existência do perfil e essa operação não são
responsabilidades implementadas pelo schema: ele permite banco vazio.
Não se introduzem login, `owner`, múltiplos perfis ou identidade autenticada.

O cascade é lógico e transacional dentro do SQLite. Não limpa snapshots do widget
ou tarefas de IA/edição em andamento, nem comprova apagamento físico irrecuperável.
Essas coordenações, os repositories, views, UI e IA são etapas futuras, sem
criptografia ou backup implicitamente prometidos.

Geração: `dart run build_runner build`; versione o arquivo gerado. O client usa
construtor convencional porque o parser de drift_dev não aceita sua declaração
equivalente com primary constructor. Testes espelham o client em
`test/features/core/infrastructure/clients/database/`, usando SQLite real para
constraints, cascade, rollback e reabertura de arquivo.

### Implementação legada ainda não migrada

O restante deste documento descreve a implementação Localstore ainda presente.
O antigo registro de Localstore no `coreModule` já foi removido.
Em conflitos de persistência e schema, a decisão Drift acima tem precedência;
não trate os contratos legados como migração já implementada.

O aplicativo é exclusivamente local. Authentication, Session, Welcome, PocketBase,
backend, worker, áudio, IA, Insight, CSV e infraestrutura de compartilhamento
sem consumidores foram removidos. Documentos históricos não autorizam restaurá-los.
Não há identidade autenticada, `owner` nas despesas ou autorização remota.

```text
Screen/Widget → Bloc → contrato de repository em application
                            ↑
                 repository em infrastructure → Localstore compartilhado
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
| `user` | Leitura e atualização do perfil local: nome e avatar. |
| `expense` | Despesas individuais: CRUD, consultas, paginação e sugestões. |
| `metrics` | Projeção mensal somente leitura das despesas locais. |
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
     ├─ coreModule → addInstance<Localstore>(Localstore.instance)
     └─ módulos das features → repositories com injeção por construtor
```

`appModule` e `coreModule` não recebem banco por parâmetro. O core registra
o singleton fornecido pelo próprio Localstore. Repositories acessam o SDK
diretamente em infrastructure, sem client de persistência, wrapper CRUD,
data source ou service locator.
O pacote vem do fork privado `bed72/localstore`, via Git HTTPS com `ref: main`
no pubspec. O lockfile fixa o commit resolvido para builds reproduzíveis.
Para buscar alterações da main, execute `flutter pub upgrade localstore` e
versione o lockfile. Não use URL com credenciais.
A API usada pelos repositories continua compatível.

Não há factory, schemas, abertura ou fechamento explícito. O SDK usa seu
diretório padrão: Documents em Android/iOS. Diretório corrente é fallback de
testes host, não suporte a apps desktop.
Dados anteriores de ToStore não são migrados, por decisão explícita.

`main` não inicializa perfil ou storage. UserRepository cria o perfil sob demanda.
O fork aguarda a escrita interna e propaga erros de filesystem/JSON. As escritas
usam arquivo temporário com flush e rename sobre o destino no mesmo filesystem.
Leituras não criam arquivos; null representa ausência real. Payloads não ficam
em cache. Operações são serializadas no isolate pelo SDK, sem coordenação entre
processos/isolates ou transações entre documentos.
Substituição atômica de arquivo não comprova durabilidade após queda de energia,
recuperação, criptografia ou backup.

### Escopos Modular

A composição usa a API funcional `createModule` do Modular 7. `coreModule`
registra Localstore, formatadores e `IWidgetClient`, sem lifecycle de storage.
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
- **Infrastructure:** acesso ao Localstore e conversão de dados com casts estritos.
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

UserRepository usa um único documento `profile` na coleção `user`:

| Campo | Valor inicial |
| --- | --- |
| `name` | `Cordato` |
| `avatar` | Seed aleatória de 16 bytes em hexadecimal, persistida. |

`get` cria e salva o perfil padrão quando o documento não existe.
Documentos existentes são convertidos sem substituição por defaults;
payloads malformados propagam como falhas de parsing.
Não há ID, e-mail, tabela de usuários, sessão ou migração de dados antigos.

`IUserRepository` expõe `get` e `update`, sem exclusão de conta.
O repository lê o perfil a cada chamada. Updates preservam campos omitidos e gravam
o documento completo, aguardando o Future público e retornando o perfil atualizado.
Nome e avatar não são derivados um do outro.

Não há cache, fila de Futures, estado pendente ou transação no repository.
Atualizações concorrentes do documento não têm garantia de merge atômico.
O SDK lê dados persistidos sem cache de payload; o repository não cria cache
adicional. Uma leitura inválida não é substituída pelo perfil padrão.

Falhas esperadas expostas pelo SDK geram UserException. Parsing e erros de
programação propagam como inesperados. A apresentação valida nome com 2–32 code
points Unicode após trim; Bloc e repository não normalizam entradas.
Avatar pode ser nulo; texto vazio é preservado, sem fallback por identidade.

### Despesas locais

Cada documento da coleção `expenses` contém:

- ID String gerado pelo Localstore, também salvo no documento.
- `amount` inteiro obrigatório, positivo, em centavos.
- `category` textual obrigatória, default `other`.
- `description` textual anulável.
- `occurred_on` String ISO UTC civil obrigatória.

Não há schema, índices, `owner`, TTL ou expulsão por capacidade. O repository
valida centavos positivos e categorias e define hoje na criação quando não recebe data.

Datas são ISO UTC à meia-noite pelos componentes civis, sem conversão de fuso.
Filtros finais incluem todo o dia escolhido. Descrição nula vira texto vazio
na projeção. O repository aplica trim à descrição para preservar o comportamento
anterior do ToStore. Tipos, datas ou categorias inválidos são inesperados.

CRUD usa operações nativas. ID ausente gera ExpenseException antes de update/delete.
Updates leem o documento, aplicam os campos fornecidos e gravam o documento
completo; updates concorrentes do mesmo documento podem sobrescrever campos.
Sem campos, update apenas lê a entidade e não solicita refresh.

Listagem lê a coleção inteira, filtra/ordena em Dart, usa offset/limite mais um
e retorna itens imutáveis com `nextPage` opcional. A ordem padrão é data/ID
decrescentes; ID textual desempata outras ordens, sem representar ordem de
criação. Filtros são reenviados pelo Bloc a cada página, e refresh retorna à
primeira. Não há snapshot transacional entre páginas.

Sugestões percorrem o histórico ordenado até 30 correspondências literais
case-insensitive antes de deduplicar descrições. Preservam categoria e valor da
ocorrência mais recente e ignoram descrições vazias/nulas. A busca pode percorrer
todo o histórico, carregado em memória. Aceitar sugestão aplica
categoria, inclusive `other`, preservando data e valor manual do formulário.

Após o Future público de mutação, o repository solicita refresh pelo client
nativo. O fork conclui a escrita antes desse Future; testes verificam leitura da
coleção imediatamente após criar despesa, sem barreira de stream.
Falha posterior não desfaz escrita nem gera retry automático.
Não há exportação CSV ou contrato de compartilhamento.

### Métricas locais

Metrics é projeção somente leitura de `expenses`, sem tabela própria, cache,
triggers, materialização ou escritas em Expense.

`IMetricsRepository.getExpenses` preserva o contrato mensal. Sem datas usa o
mês civil atual; intervalo incompleto, parcial, invertido ou de vários meses
gera MetricsException antes da leitura. Horário e indicação UTC da entrada não
alteram seus componentes civis.

Uma leitura da coleção fornece as despesas, filtradas pelo mês civil e somadas
por categoria em Dart.
Total e distribuição vêm dos mesmos grupos. Centavos permanecem inteiros;
percentuais são calculados em Metrics sem arredondamento antecipado.
`ExpenseMetricsEntity`, `ExpenseCategoryMetricsEntity` e
`ExpenseCategoryMetricsResponse` usam o campo `total`, não `totalAmount`.
Os grupos são construídos em Dart, sem parser JSON de agregados; os documentos
de despesas continuam usando `amount`.

`ExpenseCategoryMetricsResponse`, em `infrastructure/responses/`, converte os
grupos; o repository monta o resumo, sem camada `projections/`. Categorias têm
ordem textual determinística. O ID `monthly-yyyy-MM` é estável. Sem agrupamento,
`categories` é null; mês vazio agrupado tem lista vazia imutável.

Categorias desconhecidas, parsing inválido, centavos não positivos e overflow
por categoria ou mensal são inesperados. JSON inválido propaga pelo SDK, sem
omitir documentos nem publicar um zero fabricado.
Falhas expostas não são convertidas em zero ou retry automático.

Somente a consulta do mês atual captura revisão antes da leitura e aguarda a
publicação nativa, inclusive para zero válido. Consultas históricas não publicam.

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

Localstore é real em diretórios temporários isolados por
`getInstance(customPath: ...)`, sem trocar o diretório do processo nem simular
path_provider. A configuração do singleton é restaurada ao terminar.
Mocks do SDK
são restritos a delegação, falhas e operações pendentes dos repositories
User, Expense e Metrics, em `test/support/core/mocks/`. Blocs mockam contratos.
Composição global não mocka módulos inteiros e pode simular o canal nativo sem UI.

Testes aguardam operações e cancelam observações antes de limpar arquivos.
Há regressões para escrita aguardada e JSON inválido em User, Expense e Metrics.
Não há `close` ou reabertura da instância singleton; a conclusão da escrita não
comprova durabilidade após falha de energia.

`test/app_module_test.dart` verifica o Localstore compartilhado na composição,
ausência de ownership do banco pela DI, catálogo local e consumidores reais.
`test/features/core/core_module_test.dart` verifica formatadores, client
nativo e registro do Localstore, sem abrir banco.

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

Conferência de nomes e caminhos após a limpeza de 22/11/2026: 63 arquivos
`*_test.dart` em `test/features/`, dos quais 56 têm correspondência exata após remover `_test`.
Os sete restantes são:

| Teste (relativo a `test/features/`) | Implementação/alinhamento |
| --- | --- |
| `dashboard/presentation/screens/dashboard/bloc/dashboard_bloc_test.dart` | `lib/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart`; a pasta extra `dashboard/` não existe na produção. |
| `dashboard/presentation/screens/dashboard/bloc/dashboard_state_test.dart` | `lib/features/dashboard/presentation/screens/bloc/dashboard_state.dart`; mesmo desvio de pasta. |
| `core/presentation/enums/app_route_test.dart` | Testa `route_enum.dart`; nome legado. |
| `core/presentation/widgets/toast/toast_icons_test.dart` | Testa ícones definidos em `toast.dart`; nome especializado, não um arquivo `toast_icons.dart`. |
| `expense/presentation/screens/expenses/bloc/expenses_reregistration_test.dart` | Suíte de recadastro do `ExpensesBloc`, separada por responsabilidade. |
| `metrics/presentation/extensions/expense_metrics_pages_extension_test.dart` | Testa `ExpenseMetricsPagesExtension`, declarada em `expense_metrics_categories_extension.dart`. |
| `user/user_local_module_test.dart` | Suíte de persistência pela composição de `user_module.dart`, separada por responsabilidade. |

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

Última execução registrada em 22/11/2026, após a limpeza de código morto,
mantendo o fork privado `bed72/localstore` no commit `ac66df2`:
`flutter pub get` concluído, `flutter analyze` sem problemas e
`flutter test --reporter failures-only` com 845 testes aprovados.
`dart run tool/test_home_widget_native.dart` aprovou 39 testes Android e 27 iOS.
`plutil` validou Info.plist e entitlements do Runner. A varredura de imports a
partir de main e previews não encontrou arquivos Dart desconectados em lib.
`actionlint .github/workflows/android-release.yml` passou. O helper Git foi
verificado localmente com credencial fictícia, sem rede. A Action e o build
assinado não foram executados; `LOCALSTORE_READ_TOKEN` precisa ser cadastrado
no ambiente `android-release`. Resultados antigos estão no histórico.

## Limites e pendências

- Não há backup/restauração, migração remota, criptografia auditada ou garantia
  de recuperação.
- Constantes e associações de autenticação, ferramenta de app links, declarações
  de microfone e `BASE_URL` do workflow foram removidos. Android não declara rede
  no manifest principal; debug/profile preservam a configuração de desenvolvimento.
- O release depende de `LOCALSTORE_READ_TOKEN` com leitura do fork privado;
  o secret ainda não está cadastrado.
- O espelhamento de nomes/pastas dos testes tem as exceções e pendências
  registradas acima.
- Builds atuais, assinatura, comportamento em dispositivo, widget, declarações
  de loja, publicação web e revisão jurídica não foram validados nesta revisão.

Essas pendências não autorizam restaurar fluxos removidos, enfraquecer testes ou
ampliar tarefas futuras para mudanças de comportamento sem autorização.
