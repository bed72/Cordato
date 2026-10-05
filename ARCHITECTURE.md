# Arquitetura

## Visão Geral

Cordato é um aplicativo Flutter de finanças pessoais e familiares organizado
por feature e por camadas. Cada pessoa é dona dos próprios dados financeiros;
a família é uma lente de leitura compartilhada, nunca uma dona de dinheiro.

O aplicativo integra o fluxo de autenticação à API HTTP JSON:API pelo cliente
compartilhado de `coreModule` (padrão `https://api.cordato.cloud/api/`). Não há
schema ou backend financeiro ativo versionado neste repositório. O Kotlin legado é
referência de domínio, não uma dependência de execução. A apresentação permanece
independente de clientes HTTP, storage e plugins.

```text
Flutter UI -> presentation -> domain -> data -> infrastructure -> API HTTP
```

Uma screen conhece commands e contratos de repositório, nunca `Dio`,
`FlutterSecureStorage` ou clientes de rede diretamente.

## Produto E Contextos

Os contextos financeiros e seu estado atual são:

- `expense`: formulário, domínio e camadas de criação presentes; o client ainda
  retorna falha, sem persistência financeira conectada.
- `budget`: planejado; não há feature Flutter de orçamento nesta versão.
- `family`: planejado. Será uma organização de membros com leitura combinada autorizada.
- `insight`: planejado; não há feature Flutter, dados ou consultas analíticas.

`dashboard` é uma feature de apresentação e composição. `settings` é uma tela
de apresentação. `authentication` encapsula sign-in, sign-up, reenvio e
confirmação de e-mail via API JSON:API; não recria o contexto `identity` nem
gera sessão ao cadastrar ou confirmar o e-mail. `chat` permanece fora de escopo.

Invariantes do produto:

- dinheiro é BRL em centavos inteiros positivos;
- gastos não referenciam orçamentos; o pertencimento é derivado pela data;
- orçamentos do mesmo dono não podem sobrepor dias;
- participar de uma família nunca concede escrita nos dados financeiros de outro membro;
- sair ou encerrar uma família preserva os dados individuais;
- visões de família e insights são recalculados, não persistidos como dados-fonte.

Contextos proprietários não dependem de lentes. Quando implementados, `family`
e `insight` só poderão ler contextos financeiros por contratos próprios, com
adapters concretos na borda de infrastructure. O teste
`test/architecture/bounded_context_dependencies_test.dart` verifica essas
direções de import e parte do isolamento entre camadas e SDKs; as invariantes
financeiras dependem da implementação futura da persistência.

## Estrutura E Camadas

```text
lib/
  main.dart
  app_module.dart
  app_widget.dart
  features/
    core/
    session/
    authentication/
    welcome/
    dashboard/
    expense/
    settings/
```

Cada feature pode conter `domain`, `data`, `infrastructure` e `presentation`.
`core` contém capacidades compartilhadas, como tema, formatação monetária,
widgets, animações, imagens e storage; não deve receber regras de uma
feature.

- `domain` define entidades, failures e contratos sem Flutter ou SDKs.
- `data` implementa contratos de repository do domínio e converte resultados
  dos data sources em `Either`. Na autenticação, importa as interfaces de data
  source e response DTOs definidos em `infrastructure`.
- `infrastructure` define data sources que acessam HTTP, storage ou plugins;
  a apresentação não importa essas implementações.
- `core/infrastructure/clients/http` oferece `IHttpClient`/`HttpClient`,
  `Requests` e `Responses` (`Either<HttpResponse, HttpResponse>`). Cada
  `HttpResponse` contém status HTTP e corpo em mapa; falhas de transporte
  retornam `Left` com status `0` e erro genérico. O `coreModule` registra o
   Dio com `BASE_URL` e os interceptors compartilhados.
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
  usando `IStorageClient` e `StorageKeyEnum.opaqueToken`, sem expor o plugin
  ao repository; `removeToken()` exclui somente essa chave no logout.
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
  com `toEntity()` e aguarda a gravação do token opaco pelo data source local
  antes de retornar sucesso. Falhas de gravação retornam erro genérico; erros
  da API não gravam token. `signUp` retorna sucesso após o cadastro. Sign-in,
  sign-up e reenvio retornam `Either<ErrorsEntity, R>`: os erros JSON:API são
  preservados no `Left` e falhas inesperadas usam um erro genérico.
  `SignInCommand` e `SignUpCommand` entregam esse `Either` como resultado ao
  `command_it`, para a apresentação decidir como exibir os erros.
  As duas rotas retornam o envelope JSON:API `errors` com itens contendo
  `title`, `detail`, `status` e, para erros de campo, `source.pointer`.
  A apresentação usa `status` e `source.pointer` para mostrar erros de e-mail
  e senha nos respectivos campos (422, além do 409 de e-mail no cadastro);
  os demais erros são apresentados em toast, incluindo múltiplos itens.
  `resendEmailVerification` envia o e-mail cadastrado para
  `authentication/email-verification/resend` com tipo `email-verifications`;
  a resposta 202 sem corpo é sucesso. O data source e repository preservam
  erros JSON:API em `Either<ErrorsEntity, bool>`.
- `IAuthenticationRepository.logout()` retorna `Either<ErrorsEntity, bool>`.
  O repository aguarda a revogação remota e, somente após sucesso, aguarda
  `IAuthenticationLocalDataSource.removeToken()` antes de retornar `Right(true)`.
  Erros remotos são convertidos de `ErrorsResponse` para `ErrorsEntity`, sem
  solicitar remoção local; exceções remotas ou de persistência retornam
  `Left(ErrorsEntity.unknown())`. O interceptor mantém sua regra existente de
  remoção do token enviado após 401 de endpoint protegido.
- `presentation` contém screens, widgets, validators, estado local e commands.
- A confirmação de e-mail por link tem rota própria `/authentication/confirm-email`:
  `CallbackScreen` exibe o estado de espera e inicia automaticamente uma
  confirmação por link recebido. Se a URL estiver ausente, a screen apresenta
  link inválido sem executar o command. `CallbackCommand` recebe uma
  `String` não nula e chama `IAuthenticationRepository.confirmEmail`, que
  encaminha a URL ao `IAuthenticationRemoteDataSource` sem validar host,
  caminho ou assinatura. A requisição não envia Bearer, não segue
  redirecionamentos e omite a URL dos logs. O resultado 204, 403 ou falha de
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
Commands específicos de uma tela ficam em `presentation/screens/<tela>/commands/`,
junto da screen, com testes no caminho espelhado. O command do fluxo principal
usa o nome-base da tela (`CallbackScreen` → `CallbackCommand`); operações
específicas podem manter o nome da ação (`CreateExpenseCommand`,
`GetUserNameCommand`). `SessionCommand` permanece em
`session/presentation/commands/` por observar a sessão independentemente
de uma tela. Renomeações de tela e command atualizam arquivo, tipo, imports,
registro no módulo, testes e documentação sem mudar a rota por consequência.
O sign-in entrega `Either` à apresentação para tratar os erros da API; commands
de outras features podem expor falhas como erros observáveis. Estado
efêmero pertence à screen ou widget. Quando lifecycle, controllers e handlers
prejudicarem a leitura, use um mixin específico em `presentation/mixins/` ou
no diretório da própria tela, restrito ao `State` correspondente e responsável
por seu `dispose`.

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

## Inicialização, Módulos E Rotas

`main.dart` inicializa Flutter e Modular com `/splash` como rota inicial para
uma abertura normal. `AppWidget` instala temas, localização `pt_BR`, router e
provider de toast; observa `SessionCommand` para navegar ao dashboard após o
sign-in e voltar à welcome após a remoção do token em uma rota protegida.
O command é recebido pelo construtor de `AppWidget` e resolvido por DI em um
`Builder` dentro de `ModularApp`, em `main.dart`.
`AppWidgetStateMixin`, em `lib/presentation/mixins/`, concentra o lifecycle do
listener e os redirecionamentos de sessão, restrito a `State<AppWidget>`;
o State mantém apenas a composição visual.
`SplashScreen` mostra a logo enquanto lê o token e substitui a rota inicial por
dashboard ou welcome; erro de leitura também leva à welcome. Links diretos
para `/authentication/confirm-email` continuam públicos e ignoram `/splash`.
O logout em Settings remove o token pela arquitetura de Authentication e deixa
essa mesma observação global navegar para welcome. Não há validação da sessão
no backend na abertura.

`RouteEnum` centraliza os caminhos e a classificação das rotas pelo parâmetro
`authenticated`, que é `false` por padrão. Dashboard, Settings e Expense usam
`authenticated: true`. Os métodos estáticos `authenticatedRoutes()` e
`authenticatedPaths()` devolvem, respectivamente, as rotas privadas e seus
caminhos; `AppWidget` consulta esses caminhos nos redirecionamentos de sessão.

`app_module.dart` compõe os módulos existentes:

```text
coreModule
sessionModule
expenseModule
welcomeModule
settingsModule
dashboardModule
authenticationModule
```

Registros importantes:

- `coreModule`: registra `IMoneyFormatter`, `IStorageClient` com
  `FlutterSecureStorage`, `IHttpClient` e o Dio compartilhado. A factory instala
  `HeadersInterceptor`, `SessionInterceptor` e, apenas em debug, o logger.
- `sessionModule`: registra `ISessionLocalDataSource`, `ISessionRepository` e
  `SessionCommand` como dependências do app inteiro (módulo sem `path`), para
  continuar observando mudanças depois que a splash sair da pilha; registra
  a rota `/splash`.
- `authenticationModule`: compõe o módulo privado sem `path`
  `_authenticationDependenciesModule`, que registra os data sources remoto e
  local e `IAuthenticationRepository` como dependências root-owned, disponíveis
  também em Settings sem ativar uma rota de Authentication. Registra os commands
  `SignInCommand`,
  `SignUpCommand`, `ResendEmailVerificationCommand` e `CallbackCommand`.
  A rota de sign-in usa `SignInScreen` e `FormSignInWidget`: o mixin do
  formulário valida e-mail e senha (6 a 12 caracteres, com maiúscula e número).
  A screen apresenta erros do command sem navegar após o sucesso; o repository
  solicita ao data source
  local a gravação do token em storage seguro. Após o sucesso do sign-up, a
  rota é substituída por `ResendEmailVerificationScreen`, que recebe o e-mail
  cadastrado para exibi-lo em um campo desabilitado e permitir o reenvio do link.
- `dashboardModule`: `GetUserNameCommand`, tela inicial de dashboard e client
  que retorna um usuário fixo; a ação de gasto abre `/expense`.
- `expenseModule`: validators, command, repository, data source e client para o
  formulário de criação. O client atual retorna falha e ainda não persiste gastos.
- `welcomeModule`: tela e navegação de entrada.
- `settingsModule`: registra `LogoutCommand` em
  `settings/presentation/screens/settings/commands/`, injetado na tela e
  dependente somente de `IAuthenticationRepository`. “Sair” abre
  `showBottomSheetWidget<bool>`; cancelar ou dispensar não executa o command.
  Confirmar fecha a modal pelo `Navigator` e executa o command. O estado do
  `command_it` mostra loading, bloqueia novas execuções e entrega erros em toast.
  Settings não navega no sucesso nem acessa adapters de Authentication.
  Os demais itens sem destino têm callbacks sem integração.

Rotas registradas:

```text
/welcome
/splash
/authentication/sign-in
/authentication/sign-up
/authentication/confirm
/authentication/confirm-email
/dashboard
/settings
/expense
```

`/dashboard` é uma tela de apresentação, sem shell de navegação autenticada.
Dashboard abre Settings e Expense como rotas próprias; a ação de orçamento ainda
não tem destino. Welcome abre `/authentication/sign-in`, e o sucesso do sign-in
grava o token e conduz ao dashboard pela observação da sessão. Os links abaixo
dos formulários substituem sign-in por sign-up e vice-versa, mantendo
`/welcome` na pilha. O cadastro bem-sucedido substitui
sign-up por `/authentication/confirm`, que exibe o e-mail em um campo
desabilitado e permite reenviar o link com feedback da API. Um cooldown local
de 60 segundos começa ao abrir a tela e reinicia após cada reenvio aceito; o
tempo restante aparece no `ResendEmailVerificationCooldownLabelWidget`. O
link de confirmação abre `/authentication/confirm-email` com
`verification_url` como parâmetro na `CallbackScreen`.

Os módulos financeiros, dashboard e welcome registram suas rotas dentro de seu
escopo de composição. A navegação usa extensões de `BuildContext` do Modular 7,
como `context.pushNamed`, `context.navigate`, `context.replace` e `context.pop`;
não use `Modular.to`.

## API HTTP E Persistência

`coreModule` configura `Dio` com `BASE_URL` (padrão
`https://api.cordato.cloud/api/`) e `HeadersInterceptor`, que usa o media type
`application/vnd.api+json`. `HttpClient` decodifica corpos JSON em mapas e
retorna `Either<HttpResponse, HttpResponse>`: 2xx no `Right`, demais status
no `Left`, com o status e o corpo preservados; falhas de transporte usam
status `0` e corpo de erro genérico. Respostas bem-sucedidas sem corpo usam
mapa vazio. O data source remoto traduz os corpos da autenticação em respostas
tipadas e erros JSON:API, e o repository expõe
`Either<ErrorsEntity, SessionEntity>` no sign-in e `Either<ErrorsEntity, bool>`
no sign-up e no reenvio.

O link da API usa o `APP_URL` de produção `https://app.cordato.cloud` para a
página de entrada e a URL assinada da API em `verification_url`. Esse servidor
precisa servir uma página web e os arquivos de associação
`/.well-known/assetlinks.json` e `/.well-known/apple-app-site-association`.
Android e iOS usam o deep linking nativo do Flutter/Modular, incluindo
inicialização e entrega com o app já aberto.

`HttpPathEnum` identifica os endpoints relativos à base e marca os protegidos.
`Requests.forPath` carrega essa rota em `RequestOptions.extra` usando
`HttpExtraKeyEnum.route`. `expenses` está marcado como protegido no catálogo,
mas `ExpenseClient` ainda não usa a API. O `SessionInterceptor` só lê
`StorageKeyEnum.opaqueToken` para uma rota protegida cuja origem e caminho
coincidam exatamente com o endpoint da base e então envia
`Authorization: Bearer <token>`. O token é opaco; `Bearer` é o esquema HTTP.
Sign-in, sign-up e reenvio são públicos. O backend controla a validade e
renovação do token; `expiresAt` do login é apenas um retrato inicial e não
bloqueia chamadas no app. Se uma requisição protegida que enviou esse token
receber 401, o interceptor remove somente `StorageKeyEnum.opaqueToken` do
storage, preservando a resposta 401; não remove um token novo gravado depois
do envio da requisição. A exclusão notifica `SessionCommand`, e `AppWidget`
redireciona para welcome se o usuário estiver numa rota protegida.

O logout usa `DELETE authentication/sign-out`, sem payload, marcado como
protegido em `HttpPathEnum.logout`. `AuthenticationRemoteDataSource.logout()`
usa `Requests.forPath` e o interceptor existente para enviar Bearer; o backend
revoga o token atual e retorna 204 sem corpo, convertido em `Right(true)`.
O data source remoto não manipula storage.

A confirmação de e-mail usa `IHttpClient.get` no Dio compartilhado com a URL
assinada original em `Requests(path)`, sem rota autenticada, com
`followRedirects: false` e `logRequest: false`. A última opção define
`HttpExtraKeyEnum.skipLogging` e omite URL, resposta e erro dos logs. O data
source remoto entrega o status (`null` quando é `0`) ao repository, que traduz
204 em sucesso, 403 em link inválido e os demais resultados em falha de
conexão, sem verificar host, caminho ou assinatura localmente.

`TalkerDioLogger` é instalado apenas em debug e, nas requisições usuais,
registra headers e payloads de request, response e error (inclusive senha no
sign-in e token na resposta); o filtro de logging da confirmação assinada é
aplicado aos três tipos de evento. Não há logger Dio em release.

O fluxo financeiro ainda não usa a API: `ExpenseClient.create` retorna
`failed`, `UserClient.getUser` retorna um usuário fixo e não existe feature
Flutter de orçamento. Ao conectar persistência financeira, preserve propriedade
individual e invariantes no serviço responsável, com testes de autorização e
regras de domínio; a UI não é fronteira de autorização.

## Interface E Tema

Código novo de UI importa `package:material_ui/material_ui.dart`. Reutilize os
widgets compartilhados de `core`, especialmente os botões e `BounceWidget`, em
vez de estilizar botões Material diretamente.

O dashboard usa um botão de ação expansível para acessar o formulário de gasto;
não há barra inferior de navegação ou shell autenticado na composição atual.

O teclado compartilhado `AmountCalculatorWidget` recebe dígitos em reais:
`80` representa `R$ 80,00`. A tecla de vírgula permite informar até dois
dígitos de centavos (`80,5` representa `R$ 80,50`). A entrada permite até sete
dígitos inteiros; `DEL` remove a última entrada e `AC` limpa o valor. O estado
local usa o `IMoneyFormatter` para converter a entrada e mantém o contrato de
receber e devolver centavos inteiros ao formulário.

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

## Testes E Verificação

Testes unitários cobrem domain, data, infrastructure, validators, formatters,
commands e limites arquiteturais. Use `mocktail` para doubles. A política atual
não mantém testes Flutter automatizados para widgets, screens, temas, módulos
ou rotas; esses fluxos serão validados com Maestro quando os cenários existirem.
Não há suíte `integration_test` Flutter registrada.

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
