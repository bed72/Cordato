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
                 repository em infrastructure → Localstore compartilhado
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
 └─ runApp(ModularApp(module: appModule))
     ├─ coreModule → addInstance<Localstore>(Localstore.instance)
     └─ módulos das features → repositories com injeção por construtor
```

`appModule` e `coreModule` não recebem banco por parâmetro. O core registra
o singleton fornecido pelo próprio Localstore. Repositories acessam o SDK
diretamente em infrastructure, sem client de persistência, wrapper CRUD,
data source, fork ou service locator.

Não há factory, schemas, abertura ou fechamento explícito. O SDK usa seu
diretório padrão: Documents em Android/iOS e diretório corrente no desktop.
Dados anteriores de ToStore não são migrados, por decisão explícita.

`main` não inicializa perfil ou storage. UserRepository cria o perfil sob demanda.
Localstore 1.4.0 não aguarda a escrita interna em `set`; o Future público
não comprova persistência em disco e nem toda falha de escrita é propagada.
Leituras podem tratar JSON inválido como ausência/omitir documentos.
Essas limitações foram aceitas. Não há garantia adicional de atomicidade,
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
O SDK mantém cache próprio de documentos; o repository
não garante releitura física do disco nem cria cache adicional.

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
nativo. Isso não garante escrita concluída; uma consulta da coleção pode observar
um estado anterior. Falha posterior não desfaz escrita nem gera retry automático.
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
O parser JSON de grupos ainda lê `total_amount`; os documentos de despesas
continuam usando `amount`.

`ExpenseCategoryMetricsResponse`, em `infrastructure/responses/`, converte os
grupos; o repository monta o resumo, sem camada `projections/`. Categorias têm
ordem textual determinística. O ID `monthly-yyyy-MM` é estável. Sem agrupamento,
`categories` é null; mês vazio agrupado tem lista vazia imutável.

Categorias desconhecidas, parsing inválido, centavos não positivos e overflow
por categoria ou mensal são inesperados. O SDK pode omitir JSON inválido;
a projeção não audita corrupção que o SDK oculta.
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
botões reutilizam bounce compartilhado. Recuos externos são 16 pixels além das
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

Localstore é real em diretórios temporários isolados. Mocks do SDK
são restritos a delegação, falhas e operações pendentes dos repositories
User, Expense e Metrics, em `test/support/core/mocks/`. Blocs mockam contratos.
Composição global não mocka módulos inteiros e pode simular o canal nativo sem UI.

Testes aguardam sinais do SDK antes de limpar arquivos, sem prometer durabilidade
pelo Future público. Não há `close` ou reabertura da instância singleton.

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

Conferência de nomes e caminhos em 22/11/2026: 64 arquivos `*_test.dart` em
`test/features/`, dos quais 57 têm correspondência exata após remover `_test`.
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

Última execução registrada em 22/11/2026, após Localstore, perfil no
UserRepository e renomeação de Root para `Widget*`:
`flutter pub get` concluído, `flutter analyze` sem problemas e
`flutter test --reporter failures-only` com 904 testes aprovados.
Os comandos não foram repetidos nesta revisão documental e não validam
alterações de código posteriores à execução. Resultados antigos estão no
histórico, não são bloqueios atuais.

## Limites e pendências

- Não há backup/restauração, migração remota, criptografia auditada ou garantia
  de recuperação.
- Constantes antigas de autenticação permanecem sem rotas registradas.
- Android ainda declara microfone e app links antigos; iOS e ferramentas de
  associação também exigem revisão antes da distribuição.
- O workflow passa `BASE_URL` legado, sem configurar o armazenamento local.
- O espelhamento de nomes/pastas dos testes tem as exceções e pendências
  registradas acima.
- Builds atuais, assinatura, comportamento em dispositivo, widget, declarações
  de loja, publicação web e revisão jurídica não foram validados nesta revisão.

Essas pendências não autorizam restaurar fluxos removidos, enfraquecer testes ou
ampliar uma tarefa documental para mudanças de comportamento.
