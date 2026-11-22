# Arquitetura

Estado canônico da versão local na branch `tostore`, revisado em **22/11/2026**.
Convenções obrigatórias: [AGENTS.md](AGENTS.md). Execução e limites do produto:
[README.md](README.md). Registros anteriores:
[histórico da transição](docs/history/local-transition.md).

## Decisão canônica

O aplicativo é exclusivamente local. Authentication, Session, Welcome, PocketBase,
backend, worker, áudio, IA, Insight, CSV e infraestrutura de compartilhamento
sem consumidores foram removidos. Documentos históricos não autorizam restaurá-los.
Não há identidade autenticada, `owner` nas despesas ou autorização remota.

```text
Screen/Widget → Bloc → contrato de repository em application
                            ↑
                 repository em infrastructure → ToStore compartilhado
                                            → contrato de client nativo do core
```

O módulo injeta a implementação; o Bloc conhece somente contratos e exceções
de aplicação. Contratos usam `Future<T>`, sem Either, commands ou envelopes do
SDK. Não há camada de data sources, wrapper genérico de CRUD ou store global.

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
 └─ await createDependencies()
     ├─ getApplicationSupportDirectory()
     ├─ await ToStoreFactory.create(schemas, directory)
     ├─ await initializeProfile(database)
     └─ createAppModule(database)
         ├─ addInstance<ToStore>(database)
         ├─ coreModule
         └─ módulos das features
```

Somente `createAppModule` recebe o banco pronto. `coreModule` e os módulos das
features não o recebem por parâmetro. Repositories continuam com injeção por
construtor e acesso direto ao SDK em infrastructure. Não há singleton estático
manual, service locator nos repositories ou Future de abertura na DI.

A factory recebe diretório e schemas da composição, sem importar features.
Abre `cordato` em diretório persistente com `RecoveryDurability.durable` e logs
diagnósticos desativados, inclusive em debug. Isso não comprova criptografia,
backup, auditoria de durabilidade ou proteção contra desinstalação.

`main` aguarda banco e perfil antes de `runApp`. Falha de abertura propaga;
falha na preparação após abertura tenta fechar o banco e preserva a falha
original. Não há limpeza, reset, retry ou fallback para banco vazio.
A instância pertence ao bootstrap. Descartar a DI ou trocar rotas não fecha o
banco; testes fecham explicitamente suas instâncias. Encerramento abrupto depende
da recuperação do motor, não de um `dispose` garantido pelo sistema.

### Escopos Modular

A composição usa a API funcional `createModule` do Modular 7. `addInstance`
compartilha o banco; não cria outro mecanismo de lifecycle. `coreModule` registra
formatadores e `IHomeWidgetClient`, sem propriedade sobre o ToStore.

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
- **Infrastructure:** acesso ao ToStore e conversão de dados com casts estritos.
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

O bootstrap usa chaves KV independentes:

| Chave | Valor inicial |
| --- | --- |
| `profile.name` | `Cordato` |
| `profile.avatar` | Seed aleatória de 16 bytes em hexadecimal, persistida. |

O inicializador grava somente chaves ausentes e verifica `hasErrors`. Valores
válidos existentes são preservados; valores presentes malformados são rejeitados.
Uma inicialização interrompida pode completar a chave ausente na próxima abertura.
Não há ID, e-mail, tabela de usuários, sessão ou migração do antigo objeto KV
`profile` ou de dados remotos.

`IUserRepository` expõe `get` e `update`, sem exclusão de conta.
O repository lê o perfil a cada chamada, não cria defaults silenciosos e grava
somente os campos fornecidos, verificando os reconhecimentos e relendo a entidade.
Nome e avatar não são derivados um do outro.

Não há cache, fila de Futures, estado pendente ou transação no repository.
Atualizações de campos diferentes não se sobrescrevem. Atualizar ambos usa duas
gravações e não é atômico; falha na segunda não desfaz a primeira. Leituras também
não são snapshots atômicos. Concorrência na mesma chave segue o motor.

Ausência de perfil e falhas esperadas geram UserException. Parsing e erros de
programação propagam como inesperados. A apresentação valida nome com 2–32 code
points Unicode após trim; Bloc e repository não normalizam entradas.
Avatar vazio é ausência na projeção, sem fallback por identidade.

### Despesas locais

`expenseSchema`, em infrastructure de Expense, define a tabela `expenses`:

- ID sequencial automático em String.
- `amount` inteiro obrigatório, positivo, em centavos.
- `category` textual obrigatória, default `other`.
- `description` textual anulável.
- `occurred_on` datetime obrigatório, indexado.

Não há `owner`, TTL ou expulsão por capacidade. O schema não restringe o enum,
normaliza datas ou define timestamp padrão; o repository valida categorias e
define hoje na criação quando não recebe data.

Datas são ISO UTC à meia-noite pelos componentes civis, sem conversão de fuso.
Filtros finais incluem todo o dia escolhido. Descrição nula vira texto vazio
na projeção. O SDK aplica trim nativo aos campos textuais; o repository não
adiciona normalização. Tipos, datas ou categorias inválidos são inesperados.

CRUD usa operações nativas. Escritas verificam `hasErrors` e registros afetados;
ID ausente gera ExpenseException. Updates enviam somente campos fornecidos.
Sem campos, update apenas lê a entidade e não solicita refresh.

Listagem recebe página numérica, usa offset/limite mais um e retorna itens
imutáveis com `nextPage` opcional. A ordem padrão é data/ID decrescentes; ID
desempata outras ordens. Filtros são reenviados pelo Bloc a cada página, e refresh
retorna à primeira. Não há snapshot transacional entre páginas.

Sugestões percorrem lotes de 100 até 30 correspondências literais
case-insensitive antes de deduplicar descrições. Preservam categoria e valor da
ocorrência mais recente e ignoram descrições vazias/nulas. A busca pode percorrer
todo o histórico, sem carregá-lo inteiro na memória. Aceitar sugestão aplica
categoria, inclusive `other`, preservando data e valor manual do formulário.

Mutações reconhecidas solicitam refresh pelo client nativo antes da releitura
da entidade. Falha posterior não desfaz a escrita nem gera retry automático.
Não há exportação CSV ou contrato de compartilhamento.

### Métricas locais

Metrics é projeção somente leitura de `expenses`, sem tabela própria, cache,
triggers, materialização ou escritas em Expense.

`IMetricsRepository.getExpenses` preserva o contrato mensal. Sem datas usa o
mês civil atual; intervalo incompleto, parcial, invertido ou de vários meses
gera MetricsException antes da leitura. Horário e indicação UTC da entrada não
alteram seus componentes civis.

Uma única consulta agrupa por categoria usando `Agg.sum`, desde o início
inclusivo do mês até o início exclusivo do próximo mês, em ISO UTC civil.
Total e distribuição vêm dos mesmos grupos. Centavos permanecem inteiros;
percentuais são calculados em Metrics sem arredondamento antecipado.

`ExpenseCategoryMetricsResponse`, em `infrastructure/responses/`, converte os
grupos; o repository monta o resumo, sem camada `projections/`. Categorias têm
ordem textual determinística. O ID `monthly-yyyy-MM` é estável. Sem agrupamento,
`categories` é null; mês vazio agrupado tem lista vazia imutável.

Queries verificam `hasErrors`. Categorias desconhecidas, grupos duplicados,
parsing inválido, somas inválidas e overflow projetado são inesperados.
O schema garante o inteiro positivo dos registros; agregação não audita corrupção
que o motor ignora. Nenhuma falha é convertida em zero ou retry automático.

Somente a consulta do mês atual captura revisão antes da leitura e aguarda a
publicação nativa, inclusive para zero válido. Consultas históricas não publicam.

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
- AppWidget possui HomeWidgetLaunchBloc e HomeWidgetSyncBloc por factories
  estáveis, sem singleton ou SessionBloc.
- Settings e Information não possuem Bloc.
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

Não há proteção por sessão. Constantes de autenticação ainda presentes em
RouteEnum não equivalem a rotas registradas. Welcome foi removida, incluindo
composição, arquivos, constante de rota e referências nos testes.

Navegação nova usa extensões de BuildContext no widget/mixin responsável.
Argumentos levam dados, não callbacks. Preserve callbacks legados fora do escopo
até migrar seus consumidores explicitamente.

ExpensesScreen abre edição com retorno `ExpenseEntity?`. Dashboard e Metrics
recarregam ao retornar da listagem mesmo sem mutação. O botão manual da Dashboard
abre Expense com retorno tipado e `returnToPrevious`; solicita
DashboardExpensesChanged somente após despesa confirmada, contexto montado e
mesma instância viva do DashboardBloc. Cancelamento não solicita atualização.

## Widgets nativos e Root

HomeWidgetLaunchBloc usa `IHomeWidgetLaunchRepository` para lançamento inicial
e observação. Infrastructure filtra URIs antes de expor sinais. AppWidget não
recebe clients ou streams nativos; seu mixin coordena navegação e lifecycle.

O intent fica pendente até o Navigator estar disponível. A navegação usa os
RouteStates reais de `popUntil`, preserva criação existente e distingue edição
por ID. Não há SessionRoutePolicy, HomeWidgetLaunchPolicy ou redirect deferral.

HomeWidgetSyncStartedEvent mantém uma observação via `emit.onEach`, separada dos
refreshes restartable, e solicita atualização inicial. Cada refresh aguarda
`IHomeWidgetSyncRepository.enable` e depois consulta Metrics sem filtros.
`setMonthlySessionActive(active: true)` é apenas a API legada de habilitação do
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
botões reutilizam bounce compartilhado. Recuos externos são 16 pixels além das
áreas seguras e teclado. Cabeçalhos recolhíveis de Expense/Information usam
slivers e respeitam movimento reduzido. Preserve rolagem, fonte ampliada,
ErrorScreen e semântica de imagens decorativas/skeletons.
Previews são manuais, com tema/localização reais e owner explícito dos recursos.

## Testes e verificação

Não há testes de UI, goldens, integração visual ou flows Maestro. Cobertura é
unitária de domínio, contratos, repositories, Blocs, validação, formatação,
arquitetura, DI/rotas e políticas nativas.

ToStore é real em diretórios temporários com fechamento explícito. Mocks do SDK
são restritos a falhas e operações pendentes do inicializador e repositories
User, Expense e Metrics, em `test/support/core/mocks/`. Blocs mockam contratos.
Composição global não mocka módulos inteiros e pode simular o canal nativo sem UI.

`test/app_module_test.dart` verifica o banco compartilhado no módulo raiz,
ausência de ownership do banco pela DI, catálogo local e consumidores reais.
`test/features/core/tostore_module_test.dart` verifica formatadores e client
nativo sem receber ou abrir ToStore.

Use Completer/sinais observáveis para concorrência e `fake_async` para tempo.
Doubles públicos ficam em arquivos próprios de suporte. Cancele observações,
conclua Futures controlados e descarte recursos.

Verificações, nesta ordem:

```bash
flutter pub get
flutter analyze
flutter test --reporter failures-only
```

Testes nativos: `dart run tool/test_home_widget_native.dart`, opcionalmente
`android` ou `ios`, sem instâncias concorrentes de `dart run`.
Não substituem build nativo ou inspeção manual.

Última verificação em 22/11/2026, após concluir a remoção de Welcome:
`flutter pub get` concluído, `flutter analyze` sem problemas e
`flutter test --reporter failures-only` com 946 testes aprovados.
Resultados antigos estão no histórico, não são bloqueios atuais.

## Limites e pendências

- Não há backup/restauração, migração remota, criptografia auditada ou garantia
  de recuperação.
- Constantes antigas de autenticação permanecem sem rotas registradas.
- Android ainda declara microfone e app links antigos; iOS e ferramentas de
  associação também exigem revisão antes da distribuição.
- O workflow passa `BASE_URL` legado, sem configurar o armazenamento local.
- Builds atuais, assinatura, comportamento em dispositivo, widget, declarações
  de loja, publicação web e revisão jurídica não foram validados nesta revisão.

Essas pendências não autorizam restaurar fluxos removidos, enfraquecer testes ou
ampliar uma tarefa documental para mudanças de comportamento.
