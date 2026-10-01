# Arquitetura

## Visão Geral

Cordato é um aplicativo Flutter de finanças pessoais e familiares organizado
por feature e por camadas. Cada pessoa é dona dos próprios dados financeiros;
a família é uma lente de leitura compartilhada, nunca uma dona de dinheiro.

O aplicativo integra o fluxo de autenticação à API HTTP JSON:API configurada em
`authenticationModule` (padrão `https://api.cordato.cloud/api/`). Não há schema
ou backend financeiro ativo versionado neste repositório. O Kotlin legado é
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
de apresentação. `authentication` encapsula sign-in e sign-up por e-mail e
senha via API JSON:API; não recria o contexto `identity`. `chat` permanece fora
de escopo.

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
`test/architecture/bounded_context_dependencies_test.dart` protege essas
direções e restringe dependências de SDKs externos nas camadas internas. As
invariantes financeiras dependem da implementação futura da persistência.

## Estrutura E Camadas

```text
lib/
  main.dart
  app_module.dart
  app_widget.dart
  features/
    core/
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
- `data` implementa contratos e converte respostas em `Either<Failure, R>`.
- `infrastructure` chama clientes HTTP, storage ou plugins.
- `core/infrastructure/clients/http` oferece um cliente Dio reutilizável com
  `Requests` e `Responses` (`Either` de `HttpResponse`, com status HTTP e corpo),
  usado pela autenticação.
- `authentication/infrastructure/clients/AuthenticationClient` usa esse cliente
  para enviar sign-in, sign-up e reenvio de verificação em JSON:API. O
  `coreModule` registra `IHttpClient` com `BASE_URL` (padrão
  `https://api.cordato.cloud/api/`) e instala o `HeadersInterceptor` para os
  headers da API. Os caminhos de autenticação são relativos à base para
  preservar o prefixo `/api/`.
- `authentication/infrastructure/remoto/AuthenticationDataSource` converte os
  mapas JSON do client em `SignInResponse` ou `SignUpResponse` e preserva a lista
  de erros JSON:API em `ErrorsResponse`. `ErrorsResponse.fromJson` transforma
  listas de erros vazias em erro genérico; respostas inválidas e exceções do
  client também retornam erro genérico, sem propagar exceções de transporte.
  No sign-in, `SessionEntity.userId` vem de `data.relationships.user.data.id`;
  `data.id` identifica o token de acesso.
- `core/domain/entities/errors_entity.dart` representa uma lista de erros com
  título, detalhe, status e apontamento de campo sem depender do cliente HTTP.
  A extensão `ErrorsResponse.toEntity()` no core infrastructure converte a lista
  completa, com erro genérico quando a resposta não contém itens.
- `AuthenticationRepository.signIn` converte `SignInResponse` em `SessionEntity`
  com `toEntity()` e solicita ao `IAuthenticationLocalDataSource` a gravação do
  token opaco antes de retornar sucesso. Falhas de gravação retornam erro
  genérico; erros da API não gravam token. `AuthenticationLocalDataSource` usa
  `IStorageClient` e `StorageKeyEnum.accessToken`, compartilhado com o
  `OpaqueTokenInterceptor`. `signUp` retorna sucesso após a
  resposta de cadastro. Ambos retornam `Either<ErrorsEntity, R>`: todos os erros
  JSON:API são preservados
  no `Left`; respostas sem erros e falhas inesperadas usam um erro genérico.
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
- `presentation` contém screens, widgets, validators, estado local e commands.
- A confirmação de e-mail por link tem rota própria `/authentication/confirm-email`:
  `ConfirmEmailScreen` exibe um callback de espera e inicia automaticamente uma
  única confirmação por link recebido. Se a URL não vier na rota, a screen
  apresenta link inválido sem executar o command; `ConfirmEmailCommand` recebe
  uma `String` não nula e chama o
  contrato `IAuthenticationRepository`, que encaminha a URL recebida ao
  `IAuthenticationDataSource` sem validar host, caminho ou assinatura. O data
  source usa `AuthenticationClient` e `IHttpClient.get` com a URL original;
  a chamada compartilhada
  não envia Bearer, não segue redirecionamentos e omite a URL dos logs. O
  resultado 204, 403 ou falha de conexão aparece em toast e a tela reconstrói
  a pilha como Welcome → Sign In, sem manter o
  callback nela; Voltar no sign-in retorna a Welcome mesmo após um deep link
  com o app fechado. A API não cria sessão nesse fluxo.

O fluxo de uma mutação é:

```text
Screen/widget -> Command -> repository do domínio -> data source -> client HTTP
```

Commands usam `command_it` e implementam `ICommand` quando precisam de descarte.
O sign-in entrega `Either` à apresentação para tratar os erros da API; commands
de outras features podem expor falhas como erros observáveis. Estado
efêmero pertence à screen ou widget. Quando lifecycle, controllers e handlers
prejudicarem a leitura, use um mixin específico em `presentation/mixins/` ou
no diretório da própria tela, restrito ao `State` correspondente e responsável
por seu `dispose`.

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

`main.dart` inicializa Flutter e Modular com `/welcome` como rota inicial.
`AppWidget` instala temas, localização `pt_BR`, router e provider de toast. Não
há restauração de sessão nem guard de autenticação no fluxo atual; o sign-in
ainda não navega após sucesso; o token retornado pela API é persistido.

`app_module.dart` compõe os módulos existentes:

```text
coreModule
expenseModule
welcomeModule
settingsModule
dashboardModule
authenticationModule
```

Registros importantes:

- `coreModule`: registra `IMoneyFormatter` com `MoneyFormatter` e
  `IStorageClient` com `FlutterSecureStorage`; também
  instala `OpaqueTokenInterceptor` no Dio compartilhado. Ele só lê o token
  quando o `HttpPathEnum` associado à requisição exige autenticação e o destino
  coincide com a rota na base da API; requisições públicas ficam sem Bearer.
- `authenticationModule`: registra client HTTP de autenticação, data sources
  remoto e local,
  repository e os commands `SignInCommand`, `SignUpCommand`,
  `ResendEmailVerificationCommand` e `ConfirmEmailCommand`. A rota de sign-in
  usa `SignInScreen` e `FormSignInWidget`: o mixin do formulário valida e-mail
  e senha (6 a 12 caracteres, com maiúscula e número). A screen apresenta erros
  do command sem navegar após o sucesso; o repository solicita ao data source
  local a gravação do token em storage seguro. A rota de sign-up usa a mesma composição visual e validação para criar
  a conta. Após sucesso, substitui a rota pela tela de confirmação e passa o
  e-mail cadastrado como argumento de navegação para exibi-lo em um campo
  desabilitado.
- `dashboardModule`: `GetUserNameCommand`, tela inicial de dashboard e client
  que retorna um usuário fixo; a ação de gasto abre `/expense`.
- `expenseModule`: validators, command, repository, data source e client para o
  formulário de criação. O client atual retorna falha e ainda não persiste gastos.
- `welcomeModule`: tela e navegação de entrada.
- `settingsModule`: tela de configurações com retorno à tela anterior. A ação
  visual “Sair” ainda não executa logout; os demais itens sem destino têm
  callbacks de apresentação sem integração.

Rotas registradas:

```text
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
não tem destino. A tela de entrada abre `/authentication/sign-in`, e o sign-in
   bem-sucedido ainda não muda a rota. A rota de cadastro está disponível em
   `/authentication/sign-up`. O link de cadastro abaixo do botão de sign-in
   substitui a rota de entrada, mantendo `/welcome` na pilha para o botão voltar.
    O link de entrada abaixo do botão de sign-up faz a substituição inversa.
    O cadastro bem-sucedido substitui sign-up por `/authentication/confirm`,
     que mostra o e-mail enviado em um campo desabilitado e permite reenviar
     o link para esse endereço, com feedback de sucesso ou erro e botão
     desabilitado durante a requisição. Um cooldown local de 60 segundos
     começa ao abrir a tela e reinicia após cada reenvio aceito; o tempo
     restante aparece no `ResendCooldownLabelWidget`.

Os módulos financeiros, dashboard e welcome registram suas rotas dentro de seu
escopo de composição. A navegação usa extensões de `BuildContext` do Modular 7,
como `context.pushNamed`, `context.navigate`, `context.replace` e `context.pop`;
não use `Modular.to`.

## API HTTP E Persistência

`coreModule` configura `Dio` com `BASE_URL` (padrão
`https://api.cordato.cloud/api/`) e `HeadersInterceptor`, que usa o media type
`application/vnd.api+json`. Os endpoints de sign-in e sign-up são relativos à
base. `HttpClient` decodifica JSON e preserva status e corpo em `HttpResponse`,
seja no sucesso, seja na falha; o data source converte os corpos em respostas
tipadas e erros JSON:API. O repository expõe
`Either<ErrorsEntity, SessionEntity>` no sign-in e
 `Either<ErrorsEntity, bool>` no sign-up e no reenvio. No sucesso do cadastro, a tela abre
  a confirmação com o e-mail usado no envio em um campo desabilitado e orienta
  a pessoa a verificar o link recebido.
  O link da API usa o `APP_URL` de produção `https://app.cordato.cloud` para a
  página de entrada e a URL assinada da API em `verification_url`; o servidor
  deste domínio precisa servir uma página web e os arquivos de associação
  `/.well-known/assetlinks.json` e `/.well-known/apple-app-site-association`.
  Android e iOS usam o deep linking nativo do
  Flutter/Modular, incluindo inicialização e entrega com o app já aberto.

O `coreModule` mantém o Dio compartilhado e o storage seguro. `HttpPathEnum` marca
as rotas protegidas (`expenses` está no catálogo, mas ainda não é consumida pela
feature Flutter); `Requests.forPath` carrega essa informação até o interceptor,
que lê `authentication.access_token` do storage e envia
`Authorization: Bearer <token>` apenas à rota correspondente na base da API.
O token é opaco; `Bearer` é o esquema HTTP exigido pelo backend. Sign-in,
sign-up e reenvio são públicos. A confirmação de e-mail usa `IHttpClient.get`
no mesmo Dio com a URL original, sem autenticação, redirecionamento ou registro
da URL assinada; o status 204, 403 ou uma falha de transporte permanece acessível.
As chaves internas em `RequestOptions.extra` são definidas por
`HttpExtraKeyEnum` em `core/infrastructure/clients/http/enums/`.
O logger de debug não registra headers nem payloads de requests/responses, que
podem conter senha ou token. A API decide a validade e renovação do token:
`expiresAt` do login não é usado para bloquear chamadas, pois pode ficar
desatualizado quando o backend estende o mesmo token. Não há nesta etapa
restauração de navegação, logout ou tratamento global de 401.

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
