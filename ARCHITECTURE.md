# Arquitetura

## Decisão Canônica

Authentication/Sign-in define a arquitetura obrigatória do Cordato: organização
por feature, contratos de aplicação, repositories concretos em infrastructure,
clients compartilhados do core e apresentação com Bloc.

Este documento distingue **padrão obrigatório** de **estado atual**. A decisão
vale para novas implementações e migrações; não significa que todo o código já
foi convertido. Implementações antigas não são modelos alternativos aprovados.

```text
Fluxo de execução

Screen/Form -> evento -> Bloc -> IFeatureRepository
                                     |
                         FeatureRepository
                                     |
                       IHttpClient / IStorageClient
                                     |
                              adapters / SDKs

Direção de dependências

presentation ----------------> application ----------------> domain
infrastructure --------------> application / domain
infrastructure da feature ---> clients do core
módulo ----------------------> contratos + implementações + apresentação
```

Não há data source obrigatório entre repository e client, nem command ou use
case obrigatório entre tela e repository. Não adicione abstrações que apenas
deleguem a mesma chamada. O Bloc nunca depende da implementação do repository.

## Produto E Contextos

Cordato oferece finanças pessoais e familiares. A pessoa é dona dos dados;
família é somente uma lente autorizada de leitura. O backend Kotlin legado é
referência de domínio, não dependência de execução ou modelo de pastas Flutter.
Não há schema ou migrations do backend versionados neste repositório.

| Contexto/feature | Escopo |
| --- | --- |
| Authentication | E-mail/senha, cadastro, confirmação por link, reenvio e logout. |
| Session | Presença do token e observação de suas mudanças. |
| User | Perfil, nome, avatar e exclusão da conta. |
| Expense | Registro, consulta, edição e exclusão de gastos individuais. |
| Metrics | Agregações somente leitura, como totais e distribuição por categoria. |
| Insight | Análises derivadas somente leitura, sem persistência própria. |
| Budget | Planejado: tetos por intervalo inclusivo de datas. |
| Family | Planejado: membros e leitura combinada autorizada. |
| Dashboard | Composição de apresentação, não contexto de negócio. |
| Root | Entrada e composição visual global, sem domínio próprio. |

`identity` não será recriado para espelhar o backend antigo; `chat` está fora
do escopo atual. Features visuais não precisam de camadas vazias.

Invariantes financeiras:

- Valores monetários em centavos inteiros de BRL, sem conversão por `double`.
  Percentuais não são valores monetários.
- Gastos são fatos individuais; não referenciam orçamento. Pertencimento ao
  orçamento deriva da data civil, preservada sem conversão de fuso.
- Orçamentos vivos da mesma pessoa não se sobrepõem.
- Participar de família não concede escrita nos dados de outra pessoa.
- Sair ou encerrar família não modifica os dados individuais.
- Visões combinadas e insights derivam dos dados proprietários.

As garantias de autorização pertencem ao serviço responsável e exigem testes
no backend; o aplicativo não as prova por ocultar ações na interface.

## Estrutura E Responsabilidades

```text
lib/
  main.dart
  app_module.dart
  features/
    core/
    root/presentation/
    <feature>/
      <feature>_module.dart
      domain/
        entities/
        enums/
        value_objects/
      application/
        exceptions/<feature>_exception.dart
        repositories/interface_<feature>_repository.dart
      infrastructure/
        repositories/<feature>_repository.dart
        responses/
      presentation/
        screens/<screen>/
          <screen>_screen.dart
          bloc/<screen>_bloc.dart
          bloc/<screen>_event.dart
          bloc/<screen>_state.dart
          mixins/
          widgets/
        validators/
        widgets/
        previews/
```

A árvore representa localizações, não diretórios obrigatórios. Não crie inputs,
outputs, wrappers, services ou clients próprios sem necessidade concreta.
Parâmetros nomeados e records são suficientes para operações simples.

### Domain

Contém entidades, enums, value objects e regras puras. Não conhece JSON:API,
HTTP, storage, Bloc, Flutter ou tipos de aplicação. Não faz parsing de DTOs,
formatação visual ou navegação. Os contratos de repository do novo padrão
pertencem a application, não a `domain/repositories/`.

### Application

Define os contratos consumidos pelo Bloc e as exceções esperadas do fluxo.
Não importa infrastructure, presentation, clients, SDKs ou frameworks de UI.
Pode usar tipos puros de domain e do core.

`IAuthenticationRepository`, em
`authentication/application/repositories/interface_authentication_repository.dart`,
define:

- `signIn({required String email, required String password}) -> Future<void>`;
- `signUp({required String email, required String password}) -> Future<void>`;
- `resendEmail({required String email}) -> Future<void>`;
- `logout() -> Future<void>`;
- `confirmEmail(String url) -> Future<EmailVerificationStatusEnum>`.

Não há entidade de sessão ou output de login. Token e ID são detalhes internos
de persistência. `AuthenticationException`, em `application/exceptions/`,
transporta `ErrorsEntity` para falhas esperadas; não é regra de domínio.
Novos contratos retornam dados diretamente em `Future<T>`, sem `Either`.

### Infrastructure

Implementa contratos de application e coordena clients, payloads, DTOs e storage.
`AuthenticationRepository`, em `infrastructure/repositories/`, recebe
`IHttpClient` e `IStorageClient` do core diretamente. Não usa data sources,
Dio diretamente, BuildContext, Modular ou Bloc.

DTOs ficam em `infrastructure/responses/`, usam Dart puro e não atravessam o
contrato de aplicação. Casts e parsing inválidos devem falhar explicitamente;
não fabrique dados de sucesso ou transforme todo defeito de contrato em erro
de conexão. Repository não aplica trim ou normalização oculta.

### Presentation

Contém Bloc, eventos, estados, telas, widgets, validators e mixins de UI.
Conhece contratos e exceções de application e tipos de domain. Não importa
repository concreto, DTO, data source ou clients HTTP/storage.

O Bloc coordena operações e estados; o formulário possui entrada e validação;
a screen compõe e entrega efeitos ao usuário. Módulos fazem a ligação concreta.
Não introduza BaseBloc, store global ou handlers genéricos para padronizar telas
com semânticas diferentes.

### Core E Dependências Entre Features

Core reúne tema, widgets básicos, animações, imagens, formatters, erros
compartilhados e clients de infraestrutura. Não recebe regras específicas de
uma feature para contornar imports proibidos.

- Authentication e Session não importam uma à outra. Escrita e observação da
  mesma chave de storage fazem a comunicação.
- Expense e Budget não dependem de outros contextos financeiros.
- Family pode ler Expense/Budget por contratos próprios e adapters de
  infrastructure; não depende de Insight.
- Insight pode ler contextos financeiros por contratos próprios e adapters de
  infrastructure. Contextos proprietários não dependem de Family ou Insight.
- Dashboard pode compor contratos de aplicação de User, Expense, Metrics e
  Insight, sem conhecer suas implementações.
- A dependência legada de Settings em `LogoutCommand` não deve ser copiada:
  fluxos novos usam Bloc e contrato de aplicação.

## Referência Executável: Authentication/Sign-in

### Caminho De Uma Tentativa

1. `FormSignInWidget` mantém e-mail/senha, valida os campos e entrega um record.
2. O validator faz trim do e-mail; a senha é preservada. Nenhuma normalização
   adicional ocorre no evento, Bloc ou repository.
3. `SignInScreen` envia `SignInSubmittedEvent(email, password)`.
4. `SignInBloc` publica `SignInSubmitting` e aguarda o contrato `signIn`.
5. `AuthenticationRepository` envia POST JSON:API para `authentication/sign-in`, com
   `data.type: access-tokens` e atributos `email` e `password`.
6. `SignInResponse.fromJson` extrai token e ID do usuário do relacionamento.
7. O repository aguarda as duas gravações por `Future.wait` antes de concluir.
8. O Bloc publica sucesso ou falha. A navegação de sucesso pertence à observação
   global da sessão, não ao listener de SignInScreen.

Credenciais podem existir no evento para a operação, mas nunca no estado do
Bloc. DTO, token e ID não são devolvidos à apresentação.

### Estados E Concorrência

`SignInState` é sealed, com quatro variantes imutáveis:

| Estado | Interface e ações |
| --- | --- |
| `SignInInitial` | Campos e envio disponíveis, sem request automática. |
| `SignInSubmitting` | Campos/envio desabilitados e botão em loading. |
| `SignInSuccess` | Tentativa concluída; novos envios bloqueados. |
| `SignInFailure(errors)` | Feedback e retry manual disponíveis. |

`canSubmit` e `isSubmitting` são derivados do estado. Não há booleans locais
duplicando a execução nem credenciais armazenadas nas variantes.

O handler usa `droppable`: envios iguais ou diferentes durante uma tentativa
são descartados, não substituem a request nem entram em fila. O guard de
`canSubmit` também impede envio após sucesso. Falha não agenda retry automático.

Outros fluxos devem definir sua própria política explícita de concorrência;
`droppable` não deve ser aplicado cegamente a consultas substituíveis.
Dashboard já usa `restartable` para sua coordenação de leituras, mas seu desenho
de estado e seus contratos legados ainda não constituem a referência geral.

### Falhas

No repository:

- `HttpResponseException` vira `AuthenticationException` com os erros remotos
  convertidos, preservando mensagens, ordem e metadados.
- Outras `HttpClientException` viram a exceção de aplicação com fallback.
- Parsing inválido, erros de programação e falhas inesperadas de storage
  propagam sem `catch` genérico e sem confirmar sucesso.

No Bloc:

- `AuthenticationException` publica `SignInFailure` com a mesma `ErrorsEntity`,
  inclusive lista vazia; não é reportada como erro inesperado.
- Erro inesperado chama `addError(error, stackTrace)` e publica falha segura.
- `isClosed` e `emit.isDone` impedem publicação de conclusões obsoletas.

`addError` usa o mecanismo do Bloc; não representa, por si só, integração
automática com Crashlytics. O Bloc não recebe CrashClient nem callback de telemetry.

Na UI, erros 422 com pointers conhecidos e detalhe vão para os campos. Os
restantes vão para toast, sem duplicação; ausência de mensagens usa fallback
localizado. Editar limpa somente o erro daquele campo. Falha preserva a entrada.

### Propriedade E Lifecycle

`SignInScreen` recebe `SignInBloc Function() bloc` e validators. Sua factory é
estável, injetada como `bloc: inject<SignInBloc>`; o módulo registra Bloc por
factory e repository como lazy singleton pelo contrato.

O mixin da screen cria o Bloc em `initState`, fecha em `dispose` e fecha/substitui
quando a factory muda em `didUpdateWidget`. Rebuild com a mesma factory não cria
outra instância. A screen é a única dona do fechamento. `BlocProvider.value`,
quando necessário, não transfere essa propriedade.

`BlocConsumer` separa composição de efeitos únicos. Loading e disponibilidade
dos campos vêm do estado; toast não é emitido no build. Mixins de UI concentram
lifecycle e handlers, nunca chamadas ao repository.

O fechamento é nativo do Bloc. Não há override de `close()`, flag paralela ou
cancelamento HTTP. A operação remota e gravações de storage podem continuar
após saída da tela; ausência de estado tardio não significa rollback da sessão.

## HTTP E Persistência

### Cadastro Com Bloc

`SignUpScreen` recebe uma factory estável de `SignUpBloc` e possui seu fechamento,
inclusive na troca de factory. O Bloc usa `SignUpSubmittedEvent`, `droppable` e
estados `Initial`, `Submitting`, `Success(email)` e `Failure(errors)`. Senha não
fica no estado; o e-mail de sucesso identifica o destino de confirmação.
Submissões pendentes e posteriores ao sucesso são bloqueadas; falha permite
retry manual. Falhas esperadas preservam `ErrorsEntity`; inesperadas usam
`addError` e fallback seguro, respeitando fechamento/handler invalidado.

O formulário preserva validação, trim de e-mail, senha sem normalização e entrada
após falha. Erros 422 de e-mail/senha e 409 de e-mail aparecem nos campos; somente
erros restantes aparecem em toast. Campos e envio ficam desabilitados durante
submissão. O listener substitui a rota por confirmação com o e-mail, uma única
vez, sem criar sessão. O footer substitui a rota por sign-in via BuildContext.

Testes Flutter cobrem Bloc, formulário, navegação e lifecycle. Os flows e a
fixture isolada estão no [README E2E de Sign-up](test/features/authentication/presentation/screens/sign_up/e2e/README.md);
não foram executados em dispositivo devido aos bloqueios globais existentes.

### Reenvio Com Bloc

`ResendEmailScreen` recebe uma factory estável de `ResendEmailBloc`, cria a
instância em `initState`, substitui/fecha quando a factory muda e fecha no
descarte. `ResendEmailSubmittedEvent(email)` delega o endereço sem normalização.
Os estados sealed são `Initial`, `Submitting`, `Success` e `Failure(errors)`;
o Bloc usa `droppable`, preserva falhas esperadas, reporta inesperadas via
`addError` com fallback seguro e ignora conclusões após fechamento.

Ao contrário do cadastro, sucesso permite uma nova intenção de reenvio. A UI
mantém o cooldown inicial de 60 segundos e o reinicia somente após sucesso,
exibindo o toast existente sem navegar nem criar sessão. Falha mostra os erros
remotos, com fallback para mensagens ausentes, e permite retry manual imediato.
O e-mail permanece somente leitura; endereço vazio, cooldown e submissão pendente
bloqueiam o botão. Não há envio automático na entrada ou ao terminar o cooldown.

O timer pertence ao mixin da tela e é cancelado no descarte. A contagem usa os
ticks decorridos do timer periódico, não o número de callbacks, permitindo
contabilizar ticks atrasados e avançar o tempo virtual nos testes. Rebuild e
troca de factory não reiniciam o cooldown nem repetem feedback. O fechamento do
Bloc não cancela a request HTTP em andamento.

O [README E2E de Resend-email](test/features/authentication/presentation/screens/resend_email/e2e/README.md)
documenta os flows Success/Failure/Loading e a fixture isolada, ainda sem execução
em dispositivo por causa dos bloqueios globais do app.

### HTTP

`coreDependenciesModule` registra Dio, `IHttpClient` e `IStorageClient`.
`BASE_URL` padrão: `https://app.cordato.cloud/api/`. Bases devem preservar `/api/`;
a factory acrescenta a barra final quando necessário.

`Requests` possui somente `path`, `body`, `query` e `headers`. Caminhos fixos
usam `HttpPathEnum`; IDs são codificados por `Uri.encodeComponent` no adapter
responsável. Não adicione flags de autenticação ou logging por request para
contornar a política dos clients/interceptors.

`HttpClient` retorna `Responses(status, body)` em sucesso 2xx. Corpo vazio vira
mapa vazio; corpo incompatível ou status ausente produz erro tipado.

| Exceção HTTP | Significado |
| --- | --- |
| `HttpResponseException` | Resposta não 2xx, com status real e `ErrorsResponse`; erros malformados usam fallback. |
| `HttpTransportException` | Conexão, timeout ou cancelamento, identificado por `HttpExceptionEnum`, sem status sintético. |
| `HttpInvalidResponseException` | Resposta incompatível com o contrato de mapa/status. |
| `HttpUnexpectedException` | Falha Dio não classificada como transporte, sem expor causas internas. |

`ErrorsResponse` converte erros para `ErrorsEntity`, incluindo `pointer` e
`parameter` distintos. Não exponha mensagens internas ou exceções de SDK à UI.

Headers JSON:API e Bearer pertencem aos interceptors. O SessionInterceptor só
anexa token aos endpoints relativos protegidos reconhecidos na origem/base da
API, incluindo recursos suportados de User e Expense. URLs absolutas não
recebem token. Um 401 protegido remove apenas o token enviado, e somente se
ainda for o valor armazenado; não limpa o ID nem uma sessão mais recente.

Storage seguro usa `FlutterSecureStorage` por `IStorageClient`. As chaves são
`StorageKeyEnum.opaqueToken` (`@trocado.opaque_token`) e `userId`
(`@trocado.user_id`). A espera das duas escritas no sign-in não é transação:
uma falha pode deixar gravação parcial; não documente atomicidade inexistente.

Logout revoga remotamente antes de aguardar `clear()` de todo o storage.
Falha remota não limpa a sessão; falha de limpeza não confirma sucesso.
Não há validação do token no backend na abertura, refresh automático ou expiração
mantida pela apresentação. A classificação de rotas autenticadas não é um guard.

Sign-up envia e-mail e senha sem normalização, nome padrão `Trocado` e
`password_confirmation` igual à senha; não envia avatar e não cria sessão.
Não há `SignUpResponse`: o método aguarda a chamada e retorna `void`.
Reenvio também retorna `void`; cooldown e feedback permanecem responsabilidade
da apresentação. Confirmação recebe URL assinada sem reconstrução ou validação
local de host/assinatura: vazio ou 403 significa inválida, 204 sucesso e demais
resultados tratados pelo contrato significam falha; não cria sessão.

O logger Dio de debug atual registra headers e payloads sensíveis, inclusive
credenciais e URLs assinadas; não está instalado em release. Não considere esse
comportamento uma política segura nem amplie exposição em logs novos. Não há
política específica configurada de redirecionamento para URLs absolutas.

## Composição, Rotas E Bootstrap

Módulos usam `createModule` do Modular 7, pertencem à feature e registram
interfaces para implementações. Separe dependências compartilhadas de rotas
quando necessário; não crie módulos vazios para padronizar a árvore.

`authenticationModule` registra repository, validators, SignInBloc, SignUpBloc e
ResendEmailBloc por factory e o command ainda legado de confirmação, além de rotas.
Não o descreva como uma separação de módulos já concluída. O estado da composição
global depende dos registros efetivamente ativos em `app_module.dart`.

Rotas definidas nas features e no catálogo:

| Rota | Destino |
| --- | --- |
| `/` | AppScreen: decisão inicial pela presença do token. |
| `/welcome` | Boas-vindas. |
| `/authentication/sign-in` | SignInScreen com Bloc. |
| `/authentication/sign-up` | Cadastro. |
| `/authentication/confirm` | Espera/reenvio da verificação. |
| `/authentication/confirm-email` | Callback de confirmação por link. |
| `/dashboard` | Composição financeira. |
| `/settings` | Configurações. |
| `/user` e `/user/edit` | Perfil e edição de nome. |
| `/expense` | Criação sem ID ou edição com ID. |
| `/expenses` | Listagem paginada. |

Estar no catálogo ou em um módulo não garante registro ativo na composição.
Navegação nova usa extensões de BuildContext (`pushNamed`, `replace`, `pop`,
`navigate`) no widget responsável, não `Modular.to`. Sign-in não recebe callbacks
de navegação; `SignUpFooterWidget` substitui a rota diretamente pelo contexto.
Callbacks legados não devem ser removidos sem migrar todos os consumidores.

Root contém `AppScreen` e `AppWidget`. Quando Session e destinos estão ligados,
AppScreen escolhe a entrada e AppWidget observa perda do token e logout.
A abertura não faz consulta de validade ao backend.

`main.dart` inicializa o Firebase padrão antes de montar ModularApp. Core,
Crashlytics e Messaging usam o projeto `trocado-d362e`, com identificador
`com.bed.cordato` para Android/iOS. Outras plataformas não possuem opções
Firebase configuradas. Falha de inicialização impede o início do app.

O bootstrap resolve `ICrashClient` e conecta FlutterError e PlatformDispatcher;
erros do framework são não fatais e erros assíncronos não tratados são fatais.
O handler global CommandIt ainda existente pertence ao legado; não é parte do
novo desenho Bloc nem uma razão para restaurar a dependência removida.

Clients Firebase ficam em `core/infrastructure/clients/firebase/`. Messaging
expõe permissão, token e streams; NotificationClient encapsula o plugin local,
exige `initialize()` antes de `show` e usa o canal `cordato_default`.
O app não integra automaticamente envio de token ao backend, notificação em
primeiro plano, navegação por toque ou handler Dart de background.
APNs remoto e entrega real de push ainda exigem verificação.
Símbolos iOS Release são enviados por `ios/upload_crashlytics_symbols.sh`.

## Interface, Dart E Previews

- Dart `^3.13.2`, primary constructors para declarações elegíveis, campos
  imutáveis com tipo explícito e `final`, preservando `const` e super parameters.
  Construtores com lifecycle exigem avaliação semântica, não conversão mecânica.
- Imports da aplicação usam `package:cordato/`; UI usa `material_ui`, não novos
  imports de `flutter/material.dart`. Imports Flutter especializados são válidos.
- Widgets novos são públicos, `final`, com sufixo `Widget` e arquivo próprio.
- Estado efêmero de entrada/animação fica local; execução e resultado ficam no
  Bloc. Controllers, timers e listeners possuem dono e descarte explícitos.
- Mixins de estado usam `on State<Widget>`; helpers usam seu próprio `context`.
  Mixins de lógica visual pura usam `on StatelessWidget`, sem lifecycle.
- Tema: `context.colors`, `context.typography` e `context.radius`; Material 3,
  Inter e localização pt-BR. Não duplique tokens ou extensões compartilhadas.
- Reutilize botões, fields, BounceWidget, ImageWidget e ErrorScreen do core.
  Assets são centralizados em AssetEnum e declarados no pubspec.
- Preserve rolagem, acessibilidade, texto ampliado e redução de movimento.
  Skeletons e imagens decorativas não duplicam mensagens semânticas.
- Previews usam `@CordatoPreview`, wrappers reais de tema/localização/toast e
  fakes de catálogo sem rede ou storage. Não importe mocktail em `lib/`.
- A screen continua dona do seu Bloc nos previews; recursos externos usam um
  único dono, como PreviewResourceWidget. `.widget_preview/` é local.
- Código novo não recebe comentários; decisões são registradas em Markdown.

## Arquitetura Dos Testes

Testes espelham a produção e validam comportamento observável. A referência é
a suíte de Authentication/Sign-in, não os testes legados de commands/data sources.

```text
test/
  architecture/
  features/<feature>/
    domain/
    application/exceptions/
    infrastructure/repositories/
    infrastructure/responses/
    presentation/screens/<screen>/
      bloc/<screen>_bloc_test.dart
      <screen>_screen_test.dart
      e2e/
        README.md
        Success.yaml
        Failure.yaml
        Loading.yaml
  support/<feature>/
    mocks/
    fakes/
```

### Contratos, Repositories E Clients

Application testa comportamento das exceções, como identidade dos erros
transportados; não precisa de implementação falsa de regra só para preencher
uma camada. Domain testa invariantes e tipos puros sem UI ou adapters.

Repository é testado em `infrastructure/repositories/` com mocks de `IHttpClient`
e `IStorageClient`. Verifique payload exato, ausência de normalização, parsing,
conversão de erros HTTP, metadados, propagação de defeitos inesperados e espera
das operações de persistência. Sign-in só conclui após ambas as escritas;
logout só limpa depois da revogação aceita e aguarda a limpeza.

DTOs têm testes de contrato JSON, incluindo campos obrigatórios e parsing
inválido. O client HTTP é testado separadamente, usando o
`HttpClientAdapterFake` compartilhado, sem rede real ou acoplamento ao Bloc.
Não reintroduza testes de data source para um repository que já chama clients.

### Bloc

Use `bloc_test` com mock do contrato de aplicação, não do HTTP. Cubra:

- Estado inicial e ausência de request automática.
- Sequência submitting/success e delegação exata dos parâmetros.
- Mesma ErrorsEntity na falha esperada, inclusive vazia, sem reporte inesperado.
- Fallback e `addError` para falha inesperada, sem detalhes internos na UI.
- Envios duplicados ou diferentes durante request pendente descartados.
- Bloqueio depois do sucesso e retry somente após intenção manual em falha.
- Fechamento durante sucesso, falha esperada ou inesperada pendente sem estado tardio.
- Independência de instâncias pertencentes a telas diferentes.

Controle pendências com Completer e sinais do stream; não use sleeps arbitrários
para provar ordenação. Cancele toda subscription e feche os Blocs criados pelo teste.

### Screen E Widgets

Monte o Bloc real sobre mock de repository, com `Themes.light`/`Themes.dark`,
localização pt-BR e ToastProviderWidget. Não mocke o Bloc como substituto da
integração entre formulário, estados e efeitos.

Cubra validação sem request, limpeza isolada de erro ao editar, trim do e-mail
e senha preservada, envio por botão/teclado, loading e bloqueio de reenvio,
erro por campo e toast remanescente, fallback seguro, entrada preservada e
retry manual. Rebuild não pode reenviar ou duplicar feedback.

Verifique factory estável, troca de factory fechando o Bloc anterior e saída
durante operação pendente sem efeitos tardios. A screen permanece proprietária
do fechamento também no teste; conclua as pendências de maneira controlada.
Navegação global por sessão e persistência nativa não são provadas por uma
montagem isolada sem router/storage.

### Doubles E Fixtures

Use mocktail; cada mock, fake ou adapter público tem arquivo próprio sob
`test/support/<feature>/mocks/` ou `fakes/`. Não declare classes auxiliares em
`*_test.dart`, não use barrels e não coloque suporte de teste em `lib/`.
Reutilize o double por contrato, não suas instâncias mutáveis entre suítes.
Stubs, dados do cenário e teardown pertencem ao próprio teste.
Imports de suporte são relativos explícitos; produção usa `package:cordato/`.

### E2E Maestro

Flows ficam ao lado dos testes da screen em `e2e/`. Sign-in possui:

- `Success.yaml`: uma submissão, navegação e sessão preservada após reinício.
- `Failure.yaml`: validação, erro remoto, entrada preservada e retry manual.
- `Loading.yaml`: resposta retida, campos bloqueados e ausência de request dupla.

A fixture `test/support/authentication/fakes/sign_in_http_server.py` escuta
somente loopback e oferece controle de cenário, estatísticas e liberação da
request. Execute sequencialmente, sem sharding e sem backend real. Os flows
limpam dados/keychain; use dispositivo de teste e credenciais fictícias.

Consulte o [README E2E de Sign-in](test/features/authentication/presentation/screens/sign_in/e2e/README.md)
para comandos e pré-requisitos. YAML existente ou sintaticamente válido não
significa execução aprovada. Parsing, storage, erros inesperados e lifecycle
continuam cobertos por testes unitários/widget. Não há suíte `integration_test`.

### Testes Arquiteturais

O contrato desejado verifica imports de todos os contextos relevantes,
isolamento de domain/application, apresentação sem adapters e dependências
entre features. Scanners devem reportar arquivo, import e regra violada.
Ausência de feature planejada não é erro. DI e navegação exigem testes próprios:
inspecionar strings de RouteEnum não prova composição Modular.

A suíte atual ainda não garante integralmente esse contrato. Possui checks
Supabase/RPC históricos, helper que reconhece apenas contextos financeiros e
exceção específica para o contrato de Authentication em application. As listas
atuais já incluem Dio entre SDKs proibidos. Migrações devem atualizar os checks
para a regra geral de contratos de aplicação, não liberar infrastructure na UI.

## Estado Atual E Migração

O repository e o contrato de Authentication já seguem o novo desenho.
Sign-in e Sign-up têm Bloc, estados sealed, testes de Bloc, widget e flows E2E.
Isso não significa que toda Authentication ou o aplicativo estejam migrados.

| Área | Situação encontrada |
| --- | --- |
| Sign-in | Novo padrão implementado. |
| Cadastro | SignUpBloc por factory, lifecycle da tela e confirmação por navegação de contexto. |
| Reenvio | ResendEmailBloc por factory, cooldown e feedback no mixin da tela. |
| Callback e logout | Repository novo; apresentação ainda usa commands legados. |
| User, Session, Expense, Insight e Metrics | Ainda possuem contratos/implementações/data sources no desenho anterior. |
| Dashboard | Já usa Bloc, mas depende de contratos e resultados financeiros legados. |
| Bootstrap e Root | Ainda referenciam CommandIt/SessionCommand. |
| Dependências/core | CommandIt não está no pubspec; Either e `response<T>` foram removidos, com consumidores ainda existentes. |
| Composição global | Há módulos comentados e referência a `authenticationRoutesModule` sem definição no módulo atual de Authentication. |
| E2E | Flows presentes, dependentes de build compilável e composição de sessão/destinos restaurada corretamente. |

Portanto, não há garantia de análise, build, suíte completa ou navegação E2E
aprovados neste checkout. Não restaure dependências antigas apenas para esconder
a migração incompleta; também não declare comportamento de módulo desativado
como disponível no app em execução.

Na migração de Sign-up, `flutter pub get` concluiu e o lote focado de arquitetura,
application/infrastructure de Authentication, validators e telas Sign-in/Sign-up
passou (120 testes). `flutter analyze` e `flutter test` completos continuam
bloqueados pelos consumidores legados de CommandIt, `Either` e `response<T>`;
o módulo atual compõe cadastro com factory, mas não corrige a composição global.

Na migração de Resend-email, `flutter pub get` e a análise focada da tela/Bloc e
seus testes concluíram sem problemas. O lote focado acima, incluindo reenvio,
passou com 143 testes (23 novos). `flutter analyze` global encontrou 568 problemas
nos consumidores legados; `flutter test` completo também falhou por essas
dependências removidas. A migração não altera callback, logout ou composição global.

O código financeiro existente inclui formulário compartilhado de criação/edição,
listagem com paginação/filtros/gestos, métricas e insights na Dashboard, além de
perfil e avatar. São comportamentos a preservar durante migrações, não modelos
de camadas a replicar. Em particular:

- Preserve centavos, datas civis, filtros explícitos e continuações opacas.
- Preserve seleção mensal da Dashboard e recarga somente após mutação confirmada.
- Preserve dados de entrada em falha e efeitos de sucesso únicos.
- Preserve ownership, rolagem, acessibilidade e proteção contra respostas obsoletas.

Migre por fluxo completo: contrato em application, repository em infrastructure,
resultados/exceções, Bloc e estados, screen/lifecycle, bindings e todos os testes
consumidores. Remova intermediários legados apenas quando não houver consumidores.
Não faça essa migração inteira incidentalmente em uma tarefa localizada.

## Verificação

Para alterações Flutter, execute quando aplicável:

```bash
flutter pub get
flutter analyze
flutter test
```

Verificações focadas:

```bash
flutter test test/architecture
flutter test test/features/authentication/infrastructure/repositories
flutter test test/features/authentication/presentation/screens/sign_in/bloc
flutter test test/features/authentication/presentation/screens/sign_in/sign_in_screen_test.dart
flutter test test/features/authentication/presentation/screens/sign_up
flutter test test/features/authentication/presentation/screens/resend_email
```

Registre comandos, resultado e causa de bloqueios. Teste focado aprovado não
implica suíte ou app aprovados. Documentação pura pode ser revisada sem executar
Flutter; não invente resultado de análise, testes ou execução no dispositivo.

## Revisão De Documentação

- `ARCHITECTURE.md`: decisões, camadas, contratos, estado de migração e testes.
- `AGENTS.md`: regras operacionais para implementar e revisar essas decisões.
- `README.md`: produto, pré-requisitos, início rápido e limitações atuais.
- `android/README.md`: build, assinatura e verificação de release Android.

Mudanças estruturais atualizam os documentos afetados na mesma alteração.
Histórico de OpenSpec não substitui o código atual nem redefine estas decisões.
