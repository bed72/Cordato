# Arquitetura

## Visão Geral

Cordato é um aplicativo Flutter de finanças pessoais e familiares organizado
por feature e por camadas. Cada pessoa é dona dos próprios dados financeiros;
a família é uma lente de leitura compartilhada, nunca uma dona de dinheiro.

O aplicativo integra o fluxo de autenticação à API HTTP JSON:API pelo cliente
compartilhado de `coreDependenciesModule` (padrão
`https://api.cordato.cloud/api/`). Não há schema ou backend financeiro ativo
versionado neste repositório. O Kotlin legado é
referência de domínio, não uma dependência de execução. A apresentação permanece
independente de clientes HTTP, storage e plugins.

```text
Screen/Widget -> Command -> contrato de repository (domain)
  -> repository (data) -> data source (infrastructure) -> HTTP/storage
```

Uma screen conhece commands e contratos de repositório, nunca `Dio`,
`FlutterSecureStorage` ou clientes de rede diretamente.
O diagrama descreve o fluxo de execução, não uma cadeia de imports entre
camadas: `domain` não importa `data` ou `infrastructure`. Os módulos fazem a
composição das implementações. Features exclusivamente visuais não precisam
de repositories, commands ou camadas vazias.

Este documento descreve a implementação atual e identifica explicitamente as
decisões para contextos ainda planejados. Specs OpenSpec e skills locais ainda
contêm descrições históricas de Supabase; não representam a autenticação atual
nem justificam restaurar camadas removidas.

## Produto E Contextos

Os contextos financeiros e seu estado atual são:

- `expense`: estrutura visual de formulário, validators e estado de apresentação;
  sem domínio financeiro implementado, command, repository, data source,
  client ou persistência. Os handlers são placeholders e o botão de cadastro
  permanece desabilitado em loading fixo.
- `budget`: planejado; não há feature Flutter de orçamento nesta versão.
- `family`: planejado. Será uma organização de membros com leitura combinada autorizada.
- `insight`: planejado; não há feature Flutter, dados ou consultas analíticas.

`dashboard` é uma feature de apresentação e composição, com nome fixo no widget
e conteúdo placeholder, sem consulta de perfil. `settings` é uma feature
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

Direções de dependência aprovadas:

- `presentation` consome contratos de `domain`; não importa repositories de
  `data`, data sources ou clients de `infrastructure`;
- `data` implementa contratos de `domain` e consome interfaces de data source e
  DTOs de `infrastructure`, sem acessar SDKs diretamente;
- `domain` é independente das demais camadas e de frameworks;
- `authentication` e `session` não importam uma à outra: comunicam-se pela
  escrita e observação de `StorageKeyEnum.opaqueToken` no storage do core;
- Settings recebe `LogoutCommand` de Authentication como dependência de
  apresentação; o command conhece somente `IAuthenticationRepository`;
- `root` compõe a apresentação global e consome `SessionCommand`, sem assumir
  a escrita do token ou as operações de autenticação;
- `expense` e `budget` não importam contextos financeiros irmãos; `family`
  poderá ler ambos e `insight` poderá ler os três por contratos próprios com
  adapters de infrastructure. Contextos proprietários não dependem das lentes.

Responsabilidades e implementações atuais:

- `domain` define entidades, failures e contratos sem Flutter ou SDKs.
- `data` implementa contratos de repository do domínio e converte resultados
  dos data sources em `Either`. Na autenticação, importa as interfaces de data
  source e response DTOs definidos em `infrastructure`.
- `infrastructure` define data sources que acessam HTTP, storage ou plugins;
  a apresentação não importa essas implementações.
- `core/infrastructure/clients/http` oferece `IHttpClient`/`HttpClient`,
  `Requests` e `Responses` (`Either<HttpResponse, HttpResponse>`). Cada
  `HttpResponse` contém status HTTP e corpo em mapa; falhas de transporte
  retornam `Left` com status `0` e erro genérico. O `coreDependenciesModule`
  registra o Dio com `BASE_URL` e os interceptors compartilhados.
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
  ao repository; `save(token)` grava e `remove()` exclui somente essa chave
  no logout.
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
  `resendEmail` envia o e-mail cadastrado para
  `authentication/email-verification/resend` com tipo `email-verifications`;
  a resposta 202 sem corpo é sucesso. O data source e repository preservam
  erros JSON:API em `Either<ErrorsEntity, bool>`.
- `IAuthenticationRepository.logout()` retorna `Either<ErrorsEntity, bool>`.
  O repository aguarda a revogação remota e, somente após sucesso, aguarda
  `IAuthenticationLocalDataSource.remove()` antes de retornar `Right(true)`.
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
  rejeita uma string vazia e encaminha as demais URLs ao
  `IAuthenticationRemoteDataSource` sem validar host, caminho ou assinatura.
  A requisição não envia Bearer, não segue
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

No primeiro frame, `AppWidget` encaminha uma abertura inicial em Dashboard,
Settings ou Expense para `/`, para passar pela leitura local da sessão.
Links diretos para `/authentication/confirm-email` continuam públicos e não
são desviados para a entrada. Após sign-in, a observação global navega ao
dashboard quando a rota ativa é Welcome ou Sign In; após perda do token,
navega para Welcome somente se a rota ativa estiver classificada como autenticada.
O logout em Settings remove o token pela arquitetura de Authentication e deixa
essa mesma observação global navegar para welcome. Não há validação da sessão
no backend na abertura, refresh automático ou guard do Modular. Presença do
token é um sinal local para navegação, não prova de validade ou autorização.

`RouteEnum` centraliza os caminhos e a classificação das rotas pelo parâmetro
`authenticated`, que é `false` por padrão. Dashboard, Settings e Expense usam
`authenticated: true`. O método estático `authenticatedPaths()` devolve seus
caminhos; `AppWidget` consulta esse conjunto nos redirecionamentos de sessão.
Essa classificação de UI é distinta de `HttpPathEnum.requiresAuth`, que
controla o envio do token em requisições HTTP.

`app_module.dart` compõe os módulos existentes:

```text
appModule
  dependências root (sem path):
    coreDependenciesModule
    sessionDependenciesModule
    authenticationDependenciesModule
  rotas:
    welcomeRoutesModule
    expenseRoutesModule
    settingsRoutesModule
    dashboardRoutesModule
    authenticationRoutesModule
    / -> AppScreen
```

Registros importantes:

- `coreDependenciesModule`: registra `IMoneyFormatter`, `IStorageClient` com
  `FlutterSecureStorage`, `IHttpClient` e o Dio compartilhado. A factory instala
  `HeadersInterceptor`, `SessionInterceptor` e, apenas em debug, o logger.
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
  solicita ao data source
  local a gravação do token em storage seguro. Após o sucesso do sign-up, a
  rota é substituída por `ResendEmailScreen`, que recebe o e-mail
  cadastrado para exibi-lo em um campo desabilitado e permitir o reenvio do link.
- `dashboardRoutesModule`: compõe a tela inicial; o nome `Gabriel Ramos` é
  fixo em `UserNameWidget`, e o corpo exibe `Dashboard`. Menu abre `/settings`
  e a ação de gasto abre `/expense`; orçamento e notificações não têm integração.
- `expenseRoutesModule`: registra validators e compõe o formulário visual com
  `IMoneyFormatter` do core; ainda não executa criação.
- `welcomeRoutesModule`: tela e navegação de entrada.
- `settingsRoutesModule`: registra localmente o `LogoutCommand` definido em
  `authentication/presentation/commands/`, injetado na tela e
  dependente somente de `IAuthenticationRepository`. “Sair” abre
  `showBottomSheetWidget<bool>`; cancelar ou dispensar não executa o command.
  Confirmar fecha a modal pelo `Navigator` e executa o command. O estado do
  `command_it` mostra loading, bloqueia novas execuções e entrega erros em toast.
  Settings não navega no sucesso nem acessa adapters de Authentication.
  Os demais itens sem destino têm callbacks sem integração.

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
`https://api.cordato.cloud/api/`) e `HeadersInterceptor`, que usa o media type
`application/vnd.api+json`. `HttpClient` decodifica corpos JSON em mapas e
retorna `Either<HttpResponse, HttpResponse>`: corpos válidos com 2xx no `Right`, demais status
no `Left`, com o status e o corpo preservados; falhas de transporte usam
status `0` e corpo de erro genérico. Respostas bem-sucedidas sem corpo usam
mapa vazio. Um corpo não vazio que não seja mapa retorna `Left` genérico,
preservando o status recebido. O data source remoto traduz os corpos da autenticação em respostas
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
mas não há integração HTTP de Expense. O `SessionInterceptor` só lê
`StorageKeyEnum.opaqueToken` para uma rota protegida cuja origem e caminho
coincidam exatamente com o endpoint da base e então envia
`Authorization: Bearer <token>`. O token é opaco; `Bearer` é o esquema HTTP.
Sign-in, sign-up e reenvio são públicos. O backend controla a validade do
token; não há refresh implementado no app. `expiresAt` do login é apenas um
retrato inicial e não bloqueia chamadas no app. Se uma requisição protegida
que enviou esse token
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

O sign-up ainda envia `name: 'Trocado'` fixo e repete a senha em
`password_confirmation`; o formulário não coleta nome. Isso não fornece um
perfil ao Dashboard.

O fluxo financeiro ainda não usa a API: Expense é apenas apresentação,
Dashboard usa nome fixo no widget e não existe feature Flutter de orçamento.
Ao conectar persistência financeira, preserve propriedade
individual e invariantes no serviço responsável, com testes de autorização e
regras de domínio; a UI não é fronteira de autorização.

## Interface E Tema

Código novo de UI importa `package:material_ui/material_ui.dart`. Reutilize os
widgets compartilhados de `core`, especialmente os botões e `BounceWidget`, em
vez de estilizar botões Material diretamente.

O dashboard usa um botão de ação expansível para acessar o formulário de gasto;
não há barra inferior de navegação ou shell autenticado na composição atual.

O teclado `AmountCalculatorWidget`, em
`expense/presentation/widgets/calculator/`, recebe dígitos em reais:
`80` representa `R$ 80,00`. A tecla de vírgula permite informar até dois
dígitos de centavos (`80,5` representa `R$ 80,50`). A entrada permite até sete
dígitos inteiros; `DEL` remove a última entrada e `AC` limpa o valor. O estado
local usa o `IMoneyFormatter` para converter a entrada e mantém o contrato de
receber e devolver centavos inteiros. O formulário placeholder atual ainda
não abre esse teclado.

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
O catálogo atual contém componentes compartilhados do core e Welcome;
execute-o com `flutter widget-preview start`. `PreviewResourceWidget` cuida
do descarte de recursos no catálogo, e `.widget_preview/` não é versionado.

## Testes E Verificação

Testes unitários cobrem `Either`, autenticação e sessão em data/infrastructure,
validators de autenticação, formatters, helpers,
commands e limites arquiteturais. Use `mocktail` para doubles. A política atual
não mantém testes Flutter automatizados para widgets, screens, temas, módulos
ou rotas; esses fluxos serão validados com Maestro quando os cenários existirem.
Não há suíte `integration_test` Flutter registrada.

Não há flows Maestro versionados no repositório atual. A decisão de validar
UI e fluxos com Maestro não significa que esses cenários já estejam cobertos.
O teste de `RouteEnum` verifica strings, não navegação ou integração do Modular.

O check de dependências de Settings permite os contratos do domínio de
Authentication e o arquivo específico de `LogoutCommand`; os demais imports
de Authentication continuam bloqueados nessa feature.

Limitações conhecidas da suíte arquitetural:

- ainda há listas e checks históricos de Supabase e escrita via RPC; a
  integração atual usa HTTP JSON:API, e esses checks não validam esse contrato;
- `_contextFrom` reconhece apenas contextos financeiros, de modo que o teste
  de isolamento entre `authentication` e `session` não inspeciona seus imports;
- o check de import de presentation em `data` fica depois de um filtro que
  descarta arquivos de `data`, e as listas de SDKs não incluem Dio.

O teste de `ResendEmailCommand` permanece no caminho histórico
`test/features/authentication/presentation/screens/resend_email_verification/commands/resend_email_verification_command_test.dart`,
embora importe o command atual em `screens/resend_email/`. Essas pendências
não alteram as direções aprovadas nem devem ser tratadas como novas convenções.

Outras pendências do código atual: `UserNameWidget._skeleton` não é utilizado
e gera warning no analyzer; `ExpenseFormWidget` cria um controller no `build`
sem descartá-lo. Esses placeholders não substituem a regra de lifecycle de
controllers, listeners, timers e commands em [`AGENTS.md`](AGENTS.md).

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
