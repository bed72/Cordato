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
O serviço PocketBase 0.41.1 agora está versionado separadamente em `backend/`,
incluindo schema, migrations, Compose e testes próprios. Seu contexto de build
fica restrito a essa pasta; runtime e volume são independentes do aplicativo.
Essa inclusão não migra os clients, contratos ou fluxos Flutter para PocketBase,
nem declara equivalência com os recursos financeiros do backend anterior.

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

O repositório contém duas unidades independentes: `lib/` e `test/` para o
aplicativo Flutter; `backend/` para o serviço PocketBase e seus testes. A árvore
abaixo descreve apenas o aplicativo. A organização Flutter não deve ser aplicada
ao runtime do backend.

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
- Settings coordena sua interação de logout com `LogoutBloc` próprio, consumindo
  somente contrato e exceção de aplicação de Authentication. Não importa a
  apresentação ou a implementação do repository de Authentication.

## Backend PocketBase E Limite De Integração

O backend adotado está em `backend/`, com PocketBase 0.41.1 e APIs nativas.
Schema e regras ficam em `pb_migrations/`; empacotamento em `Dockerfile`,
`compose.yml` e `docker/`; testes em `tests/`. Não há hooks, worker ou runtime
Node. Configuração operacional e evidências pertencem ao
[README do backend](backend/README.md); suas regras de manutenção estão em
[backend/AGENTS.md](backend/AGENTS.md).

O escopo implementado é conta individual e CRUD de despesas próprias. Login
exige e-mail verificado, exclusão da conta remove suas despesas e regras nativas
protegem propriedade. Isso não implementa família, orçamento, agregações,
insights ou sugestões remotas.

### Contrato Atual Do Cliente Versus Backend Adotado

| Aspecto | Flutter atual | PocketBase atual |
| --- | --- | --- |
| Transporte | Endpoints próprios e envelopes JSON:API. | API REST nativa de coleções, sem envelope JSON:API. |
| Autenticação | Token opaco/ID em storage; logout revoga remotamente. | Autenticação nativa da coleção `users`; não reproduz o contrato anterior de logout. |
| Confirmação | URL assinada recebida pelo callback Flutter. | Verificação nativa; templates apontam para telas PocketBase. Cadastro não envia confirmação automaticamente. |
| Erros e paginação | Erros com pointer/parameter e links de continuação opacos. | Formatos nativos PocketBase; exigem adaptação em infrastructure. |
| Datas de despesas | Semântica de data civil. | `occurred_on` opcional como Date UTC, sem default. |
| Categoria | Contrato e validação atuais do cliente. | Select opcional; vazio não significa `other`. |
| Recursos derivados | Metrics, Insight e sugestões têm consumidores HTTP. | Sem implementação equivalente nesta configuração. |

Centavos inteiros continuam obrigatórios. A representação UTC do campo nativo
não resolve a semântica de data civil: essa compatibilidade precisa ser definida
antes da integração, sem conversão implícita de fuso ou perda de significado.

Trocar a URL não é migração. SDK/adapters, persistência de sessão, mapeamento de
erros, verificação de e-mail, paginação e destino dos recursos ausentes precisam
de decisão e implementação próprias. Nenhuma escolha de SDK ou estratégia para
os recursos ausentes é estabelecida por esta atualização documental.

A arquitetura de camadas Flutter permanece válida. As seções seguintes descrevem
o código executável atual, incluindo o transporte anterior, e não endpoints a
recriar no PocketBase. A integração futura deverá atualizar implementação,
consumidores e testes juntos, sem apresentar fixtures como homologação do serviço.
Não há migração de dados, contas ou sessões do backend anterior neste trabalho.

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
Dashboard usa `restartable` para sua coordenação de leituras sobre contratos de
aplicação. Seu estado agregado não constitui a referência geral para submissões.

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
automática com telemetria. O Bloc não recebe client nem callback de telemetry.

Na UI, erros 422 com pointers conhecidos e detalhe vão para os campos. Os
restantes vão para toast, sem duplicação; ausência de mensagens usa fallback
localizado. Editar limpa somente o erro daquele campo. Falha preserva a entrada.

### Propriedade E Lifecycle

Sign-in é o piloto de ownership pelo escopo de página do Modular V7.
`authenticationModule` registra `SignInBloc.new` no `provide` da rota por
`scope.addBloc<SignInBloc>`, sem bind adicional do Bloc no módulo. A extension
`BlocScopedExtension`, em `core/presentation/extensions/`, adapta `addStreamable`
para `BlocBase`, preservando constructor tear-offs com dependências injetadas.
O repository é lazy singleton pelo contrato no único módulo Authentication,
sem path, disponível no injector raiz inclusive para logout de Settings.

`SignInScreen` recebe a instância `SignInBloc bloc` e validators. O Modular cria
uma instância por página montada e chama `close()` no descarte do escopo; rebuild
não cria outra instância. A screen e seu mixin não criam nem fecham o Bloc.
`BlocConsumer` recebe a instância explicitamente. Testes e previews também precisam
de um proprietário externo explícito; nunca há dois donos do fechamento.
Os demais fluxos mantêm factories com ownership pelas respectivas telas;
Session continua global e pertence exclusivamente a `AppWidget`.

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

### Callback Com Bloc

`CallbackScreen` recebe uma factory estável de `CallbackBloc` e possui a criação,
substituição e fechamento da instância. A entrada da tela envia
`CallbackRequestedEvent(verificationUrl)` uma única vez; rebuild comum não
repete a confirmação. Alterar a URL ou a factory inicia uma nova confirmação.
Os estados sealed são `Initial`, `Confirming`, `Success`, `Invalid` e `Failure`;
não armazenam a URL assinada nem dados de sessão.

O Bloc trata URL nula/vazia como inválida sem acessar o repository. Nos demais
casos, delega a URL original, sem trim ou reconstrução, e traduz o status do
contrato. Falhas inesperadas usam `addError` e o feedback seguro já existente.
`restartable` invalida o handler anterior quando outro link chega: somente o
resultado mais recente pode produzir efeitos. Ao contrário do command legado,
uma URL nova não precisa aguardar a request anterior terminar. Isso não cancela
HTTP nem desfaz uma confirmação remota já iniciada.

O listener mantém os três toasts existentes e usa as extensões de BuildContext
para resetar a navegação em Welcome e empilhar Sign-in. Não há callback de
navegação recebido pela rota, sessão criada ou redirecionamento autenticado.
A tela mantém o indicador animado e seu rótulo semântico durante a confirmação.
Fechamento, troca de factory e substituição do link impedem efeitos obsoletos.

Testes próprios do módulo verificam factories independentes, repository real
com clients mockados e decodificação de exatamente um `verification_url`,
incluindo query ausente/duplicada. Os [flows de callback](test/features/authentication/presentation/screens/callback/e2e/README.md)
cobrem Success/Invalid/Failure/Loading com fixture local, ainda não executados
em dispositivo. A entrega nativa de deep links não é provada pelos testes Flutter.

### Logout Em Settings

Authentication continua dona da revogação e da limpeza de sessão pelo contrato
`IAuthenticationRepository.logout`. Como a interação pertence a Configurações,
`LogoutBloc` fica em `settings/presentation/screens/settings/bloc/`, junto dos
eventos e estados, sem tela ou módulo artificial de logout em Authentication.
`settingsRoutesModule` registra o Bloc por factory e injeta `bloc: inject<LogoutBloc>`;
o contrato de Authentication precisa estar disponível na composição externa.

`SettingsScreen` é dona do lifecycle da instância e usa `BlocConsumer` para
renderização e falhas. A confirmação mantém os textos e o cancelamento existentes;
confirmar somente envia `LogoutRequestedEvent` se a tela ainda estiver montada,
o Bloc for o mesmo dono do diálogo e estiver disponível. Troca de factory fecha
o Bloc anterior e invalida confirmações antigas.

Os estados sealed são `Initial`, `Submitting`, `Success` e `Failure(errors)`.
`droppable` descarta duplicatas pendentes; sucesso bloqueia novos envios e falha
permite retry manual com nova confirmação. Falhas esperadas preservam a mesma
`ErrorsEntity`; inesperadas usam `addError` e fallback seguro. Fechamento impede
estado/feedback tardio, não cancela revogação HTTP nem limpeza já iniciada.

Sucesso só ocorre quando o repository conclui a revogação remota e aguarda o
`clear()` de todo o storage. Settings não navega nem mostra toast de sucesso:
a observação global de Session continua responsável pelo redirecionamento.
Os testes de módulo/rota usam o repository real com clients mockados para provar
essa ordem e a espera da limpeza, além das factories independentes.

O [E2E de logout](test/features/settings/presentation/screens/settings/e2e/README.md)
prepara cenários Success/Failure/Loading com login e Bearer fictícios na fixture
local. Não foi executado em dispositivo e não prova o redirecionamento global
neste checkout, cuja composição ainda tem bloqueios.

### Session E Composição Root

`ISessionRepository` fica em `session/application/repositories/` e retorna
`Future<bool> loadSession()` e `Stream<bool> sessionChanges`. A implementação em
`session/infrastructure/repositories/` usa `IStorageClient` diretamente, sem data
source intermediário. Lê/observa somente `opaqueToken`: nulo/vazio significa
ausência, qualquer outro valor significa presença, sem normalização, validação
remota, expiração ou exposição do token à apresentação. Falhas de storage
propagam; o repository não as transforma em ausência ou limpa dados.

`SessionBloc`, em `session/presentation/bloc/`, começa em `Initial` e recebe
`SessionStartedEvent` do proprietário. `Loading`, `Authenticated`,
`Unauthenticated` e `Failure` são estados sealed sem token. O handler `droppable`
inicia uma única observação por instância e registra o watch antes da leitura
inicial. A leitura só publica enquanto o estado continuar `Loading`: um evento
mais recente, inclusive falha do watch, tem precedência sobre o resultado antigo.

O handler aguarda `emit.onEach`, usando o lifecycle nativo para cancelar a
subscription no fechamento, sem campo de subscription ou override de `close`.
Fechar não cancela a leitura de storage já iniciada; `isClosed`/`emit.isDone`
impedem resultados tardios. Falhas de leitura/watch usam `addError` e `Failure`,
sem detalhes internos ou suposição de token ausente. O watch continua ativo após
falhas recuperáveis e pode publicar uma presença posterior, sem retry automático
de leitura. Presenças repetidas não duplicam estados prontos.

`sessionDependenciesModule` registra repository por contrato e Bloc por factory.
Para esta observação contínua, o único proprietário é `AppWidget`, que recebe
`bloc: inject<SessionBloc>`, inicia em `initState`, fecha no descarte e substitui
somente quando a factory muda. Não há singleton de Bloc nem uma instância por
tela. `AppScreen` é apenas o splash visual e não possui operação ou fechamento.

O listener de Root agenda navegação depois do frame e valida instância, estado
atual e navigator key antes do efeito. Entrada protegida a frio passa pelo splash;
presença resolve `/` para Dashboard e ausência/falha resolve para Welcome. Um token
novo em Welcome/Sign-in abre Dashboard; perda/falha de observação em rota protegida
volta a Welcome. Cadastro, reenvio e callback públicos são preservados. Essa decisão
visual não prova autorização remota e não limpa storage em falha de observação.

`app_module.dart` ativa Session, Welcome, Authentication, Dashboard, Settings,
User e Expense, além das dependências de Insight e Metrics. Authentication e
Expense têm um único módulo sem path por feature; seus binds são root-owned e
as URLs completas permanecem inalteradas. User mantém seu módulo de dependências
compartilhadas existente. Logout resolve o contrato de Authentication sem ativar
uma rota irmã. Blocs de
tela continuam registrados por factory nos módulos de suas features, exceto
Sign-in, cujo Bloc pertence ao `provide` da página.
`test/app_module_test.dart` verifica todos os destinos de `RouteEnum` e a resolução
de Dashboard e logout sem ativar rotas irmãs. O teste composto de Root usa
repositories/Blocs reais de Session, Authentication e Settings com clients
mockados e Dashboard visual de teste para validar login → token → Dashboard →
logout → limpeza → Welcome com o mesmo proprietário de Session.

Os [flows Session/Root](test/features/root/presentation/screens/app/e2e/README.md)
reutilizam a fixture local de logout e estão preparados, não executados em
dispositivo. Falhas/leitura pendente do storage são verificadas nos testes Flutter,
não injetadas por uma API HTTP ou por bypasses de segurança no app.

### User: Repository E Perfil Com Bloc

`IUserRepository` fica em `user/application/repositories/` e retorna diretamente
`Future<UserEntity>` em `getById`/`update` e `Future<void>` em `delete`.
`UserException`, em `application/exceptions/`, transporta os erros esperados.
O repository concreto fica em `user/infrastructure/repositories/`, recebe
`IHttpClient` e `IStorageClient` e absorve os antigos data sources local/remoto.

O repository lê o ID atual do storage em cada operação, rejeita ID nulo/vazio
ou composto só por espaços e preserva o valor original nos demais casos.
Codifica o ID no caminho `users/<id>`, sem alterar o ID do payload JSON:API.
Update envia somente nome/avatar fornecidos e devolve a entidade da resposta,
sem normalização oculta. Erros HTTP preservam ordem, mensagens e metadados;
demais falhas tipadas do client usam fallback. Parsing inválido, falhas de
storage e exceções inesperadas propagam sem serem convertidos em falhas esperadas.

Exclusão só conclui após HTTP 204 e `storage.clear()` aguardado. Outro status
2xx lança `UserException` com fallback seguro, sem limpar o storage. Falhas remotas
ou na limpeza não confirmam sucesso. Não há booleano: conclusão sem exceção é
suficiente para o consumidor.

`UserBloc`, em `presentation/screens/user/bloc/`, substitui os commands de
consulta, avatar e exclusão. Um único handler `droppable` coordena os três eventos:
operações pendentes descartam novas consultas e mutações, inclusive concorrentes
de outro tipo, sem fila ou cancelamento HTTP. Estados sealed distinguem consulta,
perfil pronto, salvamento de avatar, exclusão e seus resultados. A disponibilidade
das ações deriva do estado. Falhas de mutação preservam o perfil confirmado;
`UserException` preserva a mesma `ErrorsEntity`, inclusive vazia. Falhas inesperadas
usam `addError` e fallback seguro. Fechamento impede publicações tardias.

Avatar delega a seed original ao repository e só confirma se a entidade retornada
contiver a mesma seed. Falha ou resposta divergente permite nova tentativa manual,
sem retry automático. Conclusão de `delete` publica sucesso e bloqueia novas
operações; exceções publicam falha. Sucesso não navega nem mostra toast: Session
observa a limpeza do token.

`UserScreen` recebe a factory estável `bloc: inject<UserBloc>`, cria em `initState`,
fecha em `dispose` e substitui/fecha somente se a factory mudar. O módulo registra
Bloc por factory e repository pelo contrato, sem data sources. `BlocConsumer`
separa renderização dos toasts únicos. Erro de consulta usa `ErrorScreen` com retry
e acesso à confirmação de exclusão; skeleton é excluído da semântica.

O mixin possui somente estado visual da seed ainda não confirmada e o timer de
dois segundos. Gerar outra seed reinicia o debounce. Troca de factory, saída,
edição de nome e confirmação de exclusão cancelam o timer. Diálogos e retornos
de edição conferem o dono atual antes de enviar eventos. Salvar/excluir bloqueia
as demais ações. A volta da edição só recarrega após uma mutação confirmada.
Previews mantêm uma factory estável; somente a tela fecha o Bloc.

`EditBloc`, em `presentation/screens/edit/bloc/`, substitui o último command de
User. `EditSubmittedEvent(name)` delega o nome original ao contrato. Os estados
sealed são `Initial`, `Submitting`, `Success(user)` e `Failure(errors)`.
`droppable` descarta envios iguais ou diferentes durante uma operação. Sucesso
bloqueia novas submissões; falha permite retry manual, preserva os erros esperados
e usa `addError` com fallback seguro para falhas inesperadas. Fechamento não
cancela HTTP, mas impede estados e feedback tardios.

`EditScreen` recebe `bloc: inject<EditBloc>` por factory, cria e fecha a instância
e substitui seu proprietário somente se a factory mudar. O formulário mantém a
entrada e os erros por campo: rejeita nome vazio ou igual ao inicial após trim,
faz trim somente ao enviar e preserva a entrada após falha. Botão e teclado usam
o mesmo guard. Erros 422 pelo pointer de nome ficam no campo; editar limpa esse
erro, e somente erros restantes aparecem em toast. Sucesso mostra o feedback
existente e devolve a entidade da API pelo callback de navegação já existente,
uma única vez. O perfil recarrega ao receber esse resultado confirmado.

User não depende mais de CommandIt. O teste composto do módulo verifica factories
independentes dos dois Blocs, estabilidade, argumentos de edição, PATCH com o
repository real sobre clients mockados e retorno/recarga após conclusão remota.
Dashboard compõe os contratos de aplicação financeiros. Os [flows de perfil](test/features/user/presentation/screens/user/e2e/README.md)
e de [edição de nome](test/features/user/presentation/screens/edit/e2e/README.md)
preparam Success/Failure/Loading com fixture HTTP isolada, sem execução em dispositivo.

### Metrics: Repository E Consulta Com Bloc

`IMetricsRepository` fica em `metrics/application/repositories/` e retorna
`Future<ExpenseMetricsEntity> getExpenses({startDate, endDate, groupBy})`.
`MetricsException` transporta `ErrorsEntity` nas falhas esperadas. A implementação
em `metrics/infrastructure/repositories/` recebe `IHttpClient` diretamente e
absorve o data source remoto removido, sem storage ou operações de escrita.

O repository consulta `metrics/expenses`, serializa datas civis sem conversão de
fuso e envia somente os filtros fornecidos. Não inventa período, agrupamento,
datas complementares ou validação remota. Ausência de filtros mantém query nula.
O DTO permanece interno a infrastructure e devolve entidade com centavos inteiros,
categorias imutáveis na ordem da API, categorias desconhecidas e distinção entre
agrupamento ausente e vazio. Percentuais continuam `double`, pois não são dinheiro.

Respostas HTTP de erro viram `MetricsException`, preservando mensagens, ordem,
pointer e parameter. Demais `HttpClientException` usam fallback seguro. Parsing
inválido (`TypeError`/`FormatException`) e falhas inesperadas propagam, sem catch
genérico que as transforme em erro de negócio ou sucesso vazio.

`ExpenseMetricsBloc`, em `metrics/presentation/bloc/`, substitui o command de
consulta compartilhada, sem criar uma screen artificial. Recebe
`ExpenseMetricsRequestedEvent` com filtros opcionais e delega os valores sem
normalização. Estados sealed distinguem `Initial`, `Loading`, `Success(data)` e
`Failure(errors)`. Somente sucesso expõe métricas; zero, categorias ausentes e
categorias vazias permanecem resultados válidos, não falhas.

O handler usa `restartable`: uma consulta nova invalida o resultado anterior,
sem cancelar HTTP. Sucessos e falhas obsoletos ou posteriores ao fechamento não
publicam estados. `MetricsException` preserva a mesma `ErrorsEntity`; falhas
inesperadas usam `addError` e fallback seguro. Sucesso permite refresh e falha
permite retry manual, sem request automática na criação ou retry automático.

O módulo registra o repository pelo contrato e o Bloc por factory independente.
Os dois previews consumidores usam BlocBuilder e PreviewResourceWidget como único
dono do fechamento. Metrics não depende mais de CommandIt. A Dashboard mantém sua
própria coordenação pelo contrato: preserva o erro esperado de Metrics quando a
leitura paralela o envolve em `ParallelWaitError`, sem adicionar um Bloc
intermediário à Dashboard.

### Insight: Repository E Consulta Com Bloc

`IInsightRepository` fica em `insight/application/repositories/` e retorna
`Future<List<InsightEntity>> get({year, month})`. `InsightException`, em
`application/exceptions/`, transporta `ErrorsEntity` nas falhas esperadas.
`InsightRepository`, em `infrastructure/repositories/`, chama `IHttpClient`
diretamente, absorvendo o antigo data source remoto, sem Either, storage ou escrita.

O endpoint relativo `insights` recebe somente `filter[year]` e `filter[month]`
fornecidos; ausência de ambos mantém query nula. O repository não inventa mês/ano,
completa filtros ou valida intervalos que pertencem ao backend. DTOs permanecem
internos a infrastructure. A lista preserva ordem, conteúdo original, tipos/grupos
desconhecidos, onboarding com período nulo e períodos de comparação/múltiplos meses.
Lista vazia é sucesso; não há persistência nem cálculo financeiro novo no app.

`HttpResponseException` vira `InsightException`, preservando mensagens, ordem,
status, pointer e parameter. Demais `HttpClientException` usam fallback seguro.
Parsing inválido (`TypeError`/`FormatException`) e falhas inesperadas propagam,
sem catch genérico que as transforme em erro esperado ou lista vazia.

`InsightsBloc`, em `insight/presentation/bloc/`, substitui o command de consulta
compartilhada, sem criar uma screen artificial. `InsightsRequestedEvent` delega
mês/ano opcionais sem normalização ou validação adicional. Estados sealed são
`Initial`, `Loading`, `Success(data)` e `Failure(errors)`; loading e disponibilidade
dos dados derivam do estado. Sucesso contém uma cópia imutável da lista, preservando
ordem e identidade das entidades. Lista vazia continua sendo sucesso.

`restartable` dá precedência à consulta mais recente, sem cancelar HTTP. Resultados
e falhas obsoletos ou posteriores ao fechamento não publicam estados nem reportam
erros. Falhas esperadas preservam a mesma `ErrorsEntity`, inclusive vazia;
inesperadas usam `addError` e fallback seguro. Sucesso permite refresh e falha
permite retry manual; não há request na criação ou retry automático.

O módulo registra o repository pelo contrato e o Bloc por factory independente.
Insight não depende mais de CommandIt. Previews continuam usando listas e exceções,
sem Either. Dashboard mantém sua própria coordenação sobre o contrato, consome a
lista diretamente e preserva os erros esperados quando `ParallelWaitError` envolve
uma falha isolada de Insight, sem adicionar um Bloc intermediário.

### Expense: Repository, Formulário E Listagem Com Bloc

`IExpenseRepository` fica em `expense/application/repositories/`. Consulta por ID,
criação e atualização retornam `Future<ExpenseEntity>`; listagem retorna
`Future<ExpensePageEntity>`; exclusão retorna `Future<void>`. `ExpenseException`
transporta os erros esperados. O repository concreto fica em
`expense/infrastructure/repositories/` e usa `IHttpClient` diretamente, sem data
source, Either, storage ou dependência de outro contexto financeiro.

Sugestões usam `suggestions({required String query})`, retornando uma lista imutável
de `ExpenseSuggestionEntity` com ID, descrição e centavos opcionais positivos.
`ExpenseSuggestionResponse` interpreta JSON:API em infrastructure; o repository
chama `expenses/suggestions` com query separada, sem expor DTOs ou inventar valor
quando `amount` está ausente/null. Parsing inválido propaga como nas demais operações.

`ExpenseSuggestionsBloc` é independente de consulta/submissão do gasto. Processa
eventos concorrentemente com geração latest-wins: uma entrada/invalidação nova
impede publicação de operações antigas, inclusive durante o debounce de 300 ms.
A política inicial é consultar a partir de 3 caracteres. Invalidar impede o HTTP
do debounce obsoleto; chamadas já iniciadas não são fisicamente canceladas. Estados
sealed distinguem idle/loading/success/failure e identificam a revisão da consulta.
Uma ponte local de apresentação conclui Futures do `optionsBuilder` por resultado,
invalidação ou fechamento e cancela subscriptions; não executa HTTP ou debounce.

O novo Bloc é fornecido exclusivamente pelo `provide` da rota `/expense` com
`addBloc`; Modular cria e fecha a instância. Screen e formulário recebem-na, sem
duplicar bind ou owner. `ExpenseBloc` mantém o lifecycle anterior pela screen.
Somente cadastro consulta sugestões. A origem manual/automática do valor e a
seleção pertencem ao formulário: resposta recebida não preenche campos, seleção
não salva, valores manuais não são sobrescritos e data civil é preservada.

O core oferece `AutocompleteTextFieldWidget<T>` sobre `RawAutocomplete`, compondo
o `TextFieldWidget` existente com foco externo opcional. Não conhece Expense ou
rede. Um controller interno sincroniza valores com o controller emprestado;
renovar o motor nativo ao recuperar foco/concluir composição preserva o campo
por GlobalKey, sem editar artificialmente o texto ou recriar a cada tecla. O campo
padrão não força o encerramento de composição IME. Recursos externos não são
descartados e trocas de controller/foco transferem listeners.

GET/POST/PATCH/DELETE preservam o endpoint relativo `expenses`, ID codificado no
caminho, payload JSON:API, descrição original e centavos inteiros. Atualização
envia somente atributos fornecidos, sem inserir data ou normalizar o formulário.
Criação preserva a data civil fornecida e usa o dia atual somente quando ausente,
mantendo o comportamento anterior. Exclusão conclui somente após HTTP 204;
outros status de sucesso geram `ExpenseException`, sem confirmar a exclusão.

Listagem preserva ordem, links opacos, filtros opcionais e fallback de pageSize
não positivo para 30. Continuações fornecem somente a query: host e caminho não
são seguidos, mantendo a chamada no endpoint relativo protegido. Parâmetros
repetidos são preservados; tamanho, categoria, ordenação e limites explícitos
prevalecem sobre os respectivos filtros da continuação. Um intervalo explícito
remove os filtros antigos de ano/mês/dia; sem intervalo eles permanecem. Não há
complementação de limites ausentes. Links sem query ou com fragmento lançam
`FormatException` antes de HTTP.

`AmountValueObject.create` retorna o valor diretamente e rejeita centavos não
positivos com `ArgumentError`, preservando igualdade por centavos e sem dependência
de erros de aplicação. DTOs devolvem entidades diretamente. Respostas inválidas
(casts, datas, categorias ou centavos não positivos) propagam sem virar falha
esperada, página parcial ou sucesso vazio. Erros HTTP preservam ordem, mensagens,
status, pointer e parameter em `ExpenseException`; demais falhas tipadas do client
usam fallback seguro. Falhas inesperadas propagam sem catch genérico.

`ExpenseBloc`, em `presentation/screens/expense/bloc/`, substitui consulta,
criação e atualização. Estados sealed distinguem inicial, consulta, dados prontos,
submissão e suas falhas/sucesso. Consultas usam `restartable`: o ID mais recente
vence. Submissões são filtradas por `canSubmit` antes de `restartable`: intenções
durante envio são descartadas sem invalidar o handler ativo; trocar o contexto
do formulário permite substituir um handler obsoleto ainda pendente. Sucesso
bloqueia novo envio, exceto criação contínua explicitamente solicitada por hold.
Falhas preservam a entrada e permitem retry manual. Uma troca de ID invalida o
resultado da submissão anterior, sem cancelar a operação remota.

`ExpenseScreen` possui a factory estável `bloc: inject<ExpenseBloc>`, cria em
`initState`, fecha no descarte e substitui somente quando a factory muda.
Erro de consulta usa `ErrorScreen` e retry. O formulário mantém controllers,
validação, trim da descrição, centavos, data civil e estado dos pickers; não fecha
o Bloc recebido da tela. `BlocConsumer` renderiza loading e entrega efeitos únicos:
422 por pointer conhecido vai ao campo; os demais erros vão ao toast. Sucesso
contínuo limpa o formulário somente após confirmação remota. A navegação fica nos
widgets responsáveis, pelas extensões de `BuildContext`, sem callbacks de entrada
em `ExpenseScreen` ou `ExpenseFormWidget`: voltar faz `pop`, edição devolve a
entidade confirmada por `pop(expense)` e criação faz `pop(expense)` quando
`returnToPrevious` é verdadeiro, ou `navigate` para Dashboard nos demais casos.
`ExpenseScreen` e `ExpenseFormWidget` não recebem `onExpensesChanged`; a Dashboard
aguarda o resultado tipado da rota e atualiza somente se uma entidade confirmada
for retornada. Após cadastro contínuo, voltar pelo botão ou pelo sistema devolve
a última entidade salva, derivada do estado do Bloc, inclusive se a tentativa
seguinte falhar ou estiver pendente. Sair sem salvar não sinaliza alteração;
consulta de edição não é confundida com mutação. Não há cópia local do resultado
ou store global para comunicar a mudança.

`ExpensesBloc`, em `presentation/screens/expenses/bloc/`, possui os snapshots
imutáveis de lista, filtros, continuação e estados de execução. Refresh/filtros
usam `restartable` e revisão para invalidar páginas antigas. Paginação descarta
novas intenções enquanto há operação ativa, mas uma página de uma consulta nova
pode substituir uma página obsoleta ainda pendente. Os links permanecem opacos;
IDs repetidos são deduplicados, com ordenação estável por data civil decrescente.
Falha de página preserva itens e continuação para retry manual. Retorno da edição
atualiza a lista ou remove o item quando deixa de corresponder aos filtros.
`ExpensesScreen` não recebe callbacks de navegação ou de alteração. Seu mixin
abre a edição por `context.pushNamed<ExpenseEntity>` e volta por `context.pop`.
Os argumentos da rota de listagem contêm somente período e categoria. Dashboard
e o card de categoria de Metrics aguardam o retorno da listagem e recarregam suas
consultas, inclusive ao voltar sem alterações, evitando interceptar o botão do
sistema ou o gesto de retorno para transportar um sinal de mudança.

Exclusão usa `droppable`, bloqueia consultas/mutações concorrentes e remove o item
somente quando o contrato conclui. Falha mantém o item e permite nova confirmação.
Se os filtros externos mudarem durante a exclusão, somente a última intenção fica
pendente e é consultada depois da mutação, sem sobrepor leitura e escrita.
O mixin da listagem possui somente scroll, diálogo de confirmação e navegação de
edição; não mantém cópia local dos dados ou do loading. Factory, filtros e descarte
invalidam retornos de diálogos/edições antigos. A tela é dona do fechamento do Bloc.
Os Blocs preservam `ExpenseException.errors`, reportam inesperadas por `addError`
com fallback seguro e verificam fechamento/handler invalidado antes de publicar.
Isso não cancela HTTP ou desfaz mutações já iniciadas.

O módulo registra os dois Blocs por factory, sem commands ou data source. Previews
usam factories estáveis ou `PreviewResourceWidget` como único dono do recurso.
Testes de Bloc, tela e módulo cobrem concorrência, retry, lifecycle e retorno da
edição com repository real sobre HTTP mockado. Os flows de
[criação](test/features/expense/presentation/screens/expense/e2e/README.md) e
[listagem/exclusão](test/features/expense/presentation/screens/expenses/e2e/README.md)
usam fixture HTTP isolada e estão preparados, não executados em dispositivo.

Dashboard agora compõe somente resultados diretos de User, Metrics, Insight e
Expense, sem Either. Uma falha no histórico continua sendo desconhecimento do
limite inicial, não um histórico vazio confirmado. Falhas esperadas isoladas nas
seções preservam a `ErrorsEntity` mesmo envolvidas em `ParallelWaitError`.
Previews e testes consumidores usam entidades/resultados diretos. O teste de
SessionInterceptor usa o repository real no lugar do data source removido.

### Clients Compartilhados

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
interfaces para implementações. Authentication e Expense têm um módulo por
feature sem path: repository, validators, factories e rotas no mesmo registro.
Não fragmente em módulos dependencies/form/list/routes para resolver a DI.
Os endpoints são URLs completas de `RouteEnum`; o root continua compondo os
módulos sem alterar os caminhos públicos.

O padrão para estado de página novo ou explicitamente migrado é `provide` com
`BlocScopedExtension.addBloc`, em `core/presentation/extensions/`. A extension
aceita `Function constructor`, preservando tear-offs com dependências obrigatórias
resolvidas pelo injector, e delega stream/fechamento a `addStreamable`.
Não cria BaseBloc, repository intermediário ou store global.

```dart
context.route(
  RouteEnum.authenticationSignIn.path,
  provide: (scope) => scope.addBloc<SignInBloc>(SignInBloc.new),
  child: (context, _) => SignInScreen(
    bloc: context.read<SignInBloc>(),
    emailValidation: inject<EmailValidation>(),
    passwordValidation: inject<PasswordValidation>(),
  ),
);
```

O escopo da página é o único dono: cria uma instância por montagem, preserva-a
em rebuild e chama `close()` ao desmontar. A screen recebe a instância e mantém
`BlocBuilder`/`BlocConsumer` e listeners explícitos, sem fechamento manual ou
`BlocProvider(create:)` que assuma um segundo ownership. `context.read` neste
exemplo é a extensão do Modular; evite ambiguidade com extensões do flutter_bloc.
Testes e previews podem usar um escopo externo ou `PreviewResourceWidget` como
dono, sem tornar a screen dependente do roteador para renderizar.

Hoje Sign-in e `ExpenseSuggestionsBloc` usam esse padrão. SignUpBloc, ResendEmailBloc, CallbackBloc
e os demais Blocs de tela ainda são factories com ownership pelas screens;
SessionBloc permanece global e pertence a `AppWidget`. Não declare migração
completa nem altere outros lifecycles incidentalmente.

Módulos com `path` ativam binds por feature; módulos sem `path` registram
dependências root-owned compartilhadas. Um consumidor entre features não pode
depender de uma rota irmã ativa. Authentication e Expense não usam `path: '/'`:
no Modular 7.1.1, binds são indexados pelo path e features irmãs com o mesmo path
sobrescrevem registros. O módulo sem path evita colisão, disponibiliza o repository
para logout e preserva factories, sem tornar Blocs singletons. Perde-se o descarte
automático dos binds por saída da feature; telas ainda não migradas fecham seus
Blocs; os provides de Sign-in e sugestões fecham suas instâncias por página.
Outros módulos com paths exclusivos não foram reorganizados.

`test/app_module_test.dart` monta a composição real, verifica resolução sem
ativar rotas de Authentication/Expense e abre criação, edição, listagem e Settings.
Não confunda rotas registradas com DI funcional nem widget tests com E2E nativo.

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

Todos os destinos do catálogo estão registrados na composição atual.
Isso não comprova DI nem execução bem-sucedida no dispositivo.
Navegação nova usa extensões de BuildContext (`pushNamed`, `replace`, `pop`,
`navigate`) no widget responsável, não `Modular.to`. Sign-in não recebe callbacks
de navegação; `SignUpFooterWidget` substitui a rota diretamente pelo contexto.
Argumentos de rota contêm dados, não funções. A edição devolve `ExpenseEntity`
confirmada por `pop(expense)`. Listagem não recebe `onExpensePressed`,
`onBackPressed` ou `onExpensesChanged`; seu mixin usa o próprio `context`.
Dashboard e Metrics recarregam ao retornar da listagem, inclusive sem mutação,
sem flags de alteração transportadas pela rota e sem interceptar o voltar nativo.
Callbacks locais entre widgets de composição não são callbacks de rota.
Outros callbacks legados exigem migração conjunta de todos os consumidores.

Root contém `AppScreen`, o splash visual, e `AppWidget`, proprietário do
SessionBloc e das decisões globais de navegação. A abertura lê presença no
storage e não faz consulta de validade ao backend.

`main.dart` inicializa o binding Flutter e monta ModularApp sem depender de
serviços remotos. Não há client de crash reporting ou push remoto registrado
no core; os handlers padrão do Flutter e da plataforma são preservados.
`addError` usa o mecanismo de Bloc, sem envio automático a serviços externos.

NotificationClient encapsula o plugin de notificações locais, exige
`initialize()` antes de `show` e usa o canal `cordato_default`. Não há integração
automática de navegação por toque ou recebimento de notificações remotas.

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
- Previews respeitam o ownership do fluxo: Sign-in recebe uma instância de um
  dono externo; telas ainda não migradas continuam donas de sua factory. Recursos
  externos usam um único dono, como PreviewResourceWidget. `.widget_preview/` é local.
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

No Sign-in, verifique uma instância por escopo, estabilidade em rebuild,
fechamento ao sair/substituir o escopo, nova instância ao retornar e operação
pendente sem efeitos tardios. O teste da screen usa `ModularApp.provide` como
dono; o teste de módulo verifica o `provide` da rota real e DI dos construtores.
Nas telas não migradas, mantenha testes de factory estável, troca de factory e
fechamento pela screen. Nunca feche manualmente para mascarar um dono ausente.
Conclua pendências de maneira controlada. Testes de navegação cobrem edição
confirmada/cancelada e recarga do consumidor ao voltar pelo app bar ou sistema.
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
Sign-in, Sign-up, reenvio e callback têm Bloc, estados sealed, testes de Bloc,
widget e flows E2E. O módulo de Authentication possui testes próprios para DI
e roteamento do callback, sem garantir a composição global do aplicativo.
Os fluxos de Authentication e a observação Session/Root usam o novo desenho;
isso não significa que todo o aplicativo esteja migrado ou componha seus destinos.

| Área | Situação encontrada |
| --- | --- |
| Sign-in | Bloc no `provide` da rota via extension do core; screen recebe instância sem fechar. |
| Cadastro | SignUpBloc por factory, lifecycle da tela e confirmação por navegação de contexto. |
| Reenvio | ResendEmailBloc por factory, cooldown e feedback no mixin da tela. |
| Callback | CallbackBloc por factory, latest-link-wins e navegação/feedback no listener da tela. |
| Logout | LogoutBloc em Settings, contrato de Authentication e navegação global por sessão preservada. |
| Session | Contrato em application, repository direto em infrastructure e SessionBloc contínuo. |
| User | Contrato/repository migrados; perfil, avatar e exclusão com UserBloc; edição de nome com EditBloc; sem commands. |
| Metrics | Contrato em application, repository direto em infrastructure e ExpenseMetricsBloc por factory, sem Either/data source/commands. |
| Insight | Contrato em application, repository direto em infrastructure e InsightsBloc por factory, sem Either/data source/commands. |
| Expense | ExpenseBloc e ExpensesBloc por factory; CRUD, cadastro contínuo, filtros e paginação; sem Either/data source/commands. |
| Dashboard | Bloc agregado sobre contratos de aplicação e resultados diretos dos contextos consultados, sem Either. |
| Bootstrap e Root | AppWidget é dono do SessionBloc; AppScreen apenas visual; handler CommandIt removido do bootstrap. |
| Dependências/core | CommandIt, Either e `response<T>` removidos; testes de core alinhados aos DTOs e exceções HTTP atuais. |
| Composição global | Todos os destinos registrados; Authentication e Expense sem path, sem colisão de binds; logout resolve o contrato no injector raiz. |
| Navegação de despesas | Contexto local e resultados tipados na edição; listagem sem callbacks de rota; consumidores recarregam em qualquer retorno da listagem. |
| E2E | Flows preparados, não executados em dispositivo nesta revisão; registro de rotas e testes Flutter não comprovam E2E. |

Última verificação após consolidar Authentication e Expense sem path:
`flutter analyze` sem problemas; `flutter test` com **917 aprovados, sem falhas**.
O teste global de logout antes pendente passou; novos testes cobrem os binds
root-owned e a abertura real de cadastro, edição, listagem e Settings em widget.
O launcher de previews compilou/serviu sem cliente conectado e atingiu timeout;
isso não valida visualmente o catálogo. Nenhum E2E foi executado.

### Histórico De Verificações

Os resultados abaixo registram etapas anteriores, não o estado atual da suíte
ou da composição. Referências a commands, rotas desativadas e bloqueios já
resolvidos não constituem instruções para restaurar o desenho antigo.

Após a revisão de testes e a migração do Firebase Messaging para registro por
FID, a suíte completa passou com 907 testes, incluindo 10 de arquitetura e 15 do
MessagingClient. `flutter pub get` e `flutter analyze` concluíram sem problemas.
Build, entrega real de push e navegação E2E não foram validados.
Não restaure dependências antigas apenas para esconder
a migração incompleta; também não declare comportamento de módulo desativado
como disponível no app em execução.

Os registros a seguir descrevem resultados históricos das migrações, anteriores
à revisão da suíte completa acima.

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

Na migração de Callback, `flutter pub get` concluiu e a análise focada do módulo,
da tela/Bloc e dos testes passou sem problemas. O lote focado de arquitetura e
Authentication passou com 172 testes, incluindo 29 novos de callback/DI/rotas.
A fixture local passou em verificação HTTP de 204, 403, 500, URL completa,
retenção/liberação e isolamento de endpoints. `flutter analyze` global continua
com 564 problemas legados e `flutter test` completo falha por referências
removidas, como `Either` e CommandIt. Nenhum flow Maestro foi executado em dispositivo.

Na migração de Logout, `flutter pub get` concluiu e a análise focada de Settings,
seus testes e o check arquitetural passou sem problemas. `flutter test
test/architecture test/features/authentication test/features/settings` passou com
195 testes, incluindo 23 novos de Logout/Settings. O teste de módulo verifica
factories independentes e a espera da revogação remota seguida de `storage.clear`.
A fixture passou em verificação HTTP de login, erro remoto, sucesso, retenção/
liberação e Bearer. A análise global permanece bloqueada pelo legado, assim como
`flutter test` completo. `LogoutCommand` e a dependência cruzada de apresentação
foram removidos; Authentication não usa mais commands, mas Session/Root e demais
features permanecem em migração. Os flows E2E de logout não foram executados.

Na migração de Session, `flutter pub get` concluiu e a análise focada de Session,
Root, bootstrap/composição e seus testes passou sem problemas. O lote de
arquitetura, Authentication, Settings, Session, Root e storage passou com 250
testes, incluindo 49 novos de Session/Root. A verificação adicional de
`session_interceptor_test.dart` foi bloqueada pelo import legado de Expense que
ainda depende de `Either`. A análise global encontrou 550 problemas, inclusive
testes do handler CommandIt removido e consumidores antigos de `Either`/
`response<T>`; `flutter test` completo também falhou. Não houve execução E2E em
dispositivo. Os caminhos dos subflows/scripts novos foram conferidos, o que não
constitui validação de sintaxe ou execução Maestro.

Na primeira rodada de User, `flutter pub get` concluiu e a análise focada de
domain/application/infrastructure e seus testes passou sem problemas. Os testes
focados cobrem payload, parsing, ID, erros HTTP e propagação de falhas inesperadas,
além da ordem/espera da exclusão e limpeza. O comando `flutter test
test/architecture test/features/authentication test/features/settings
test/features/session test/features/root test/features/user/application
test/features/user/infrastructure test/features/user/domain` passou com 289 testes.
A análise e a suíte globais continuam
bloqueadas por `Either`, `response<T>` e CommandIt nos consumidores legados;
os testes dos commands de User e de Dashboard foram adaptados, mas sua execução
continua bloqueada por essas dependências. Nenhum E2E foi executado nesta rodada.

Na segunda rodada de User, `flutter pub get` concluiu. A análise focada da tela,
Bloc, preview e testes passou sem problemas. O lote focado da primeira rodada,
acrescentando `test/features/user/presentation/screens/user`, passou com 344 testes
(55 adicionais, incluindo 32 de Bloc, 22 de tela e um check arquitetural).
`flutter test test/features/user/user_module_test.dart` foi executado e bloqueado
na compilação por CommandIt da rota `edit`, não por um teste de DI aprovado.
A análise e a suíte globais também continuam bloqueadas pelo legado. Foram removidos
somente os cenários obsoletos de UserCommand do teste do handler CommandIt legado;
erros esperados/inesperados de User agora são verificados pelo mecanismo do Bloc.
A fixture de User passou em verificações HTTP locais de perfil, avatar, respostas
401/422/503, exclusão 204, liberação e isolamento de endpoints. Isso não valida
Maestro nem os seletores em dispositivo. Nenhum E2E foi executado nesta rodada.

Na terceira rodada de User, `flutter pub get` concluiu e a análise focada de toda
a feature, testes/suporte de User e check arquitetural passou sem problemas.
`flutter test test/architecture test/features/authentication test/features/settings
test/features/session test/features/root test/features/user` passou com 374 testes,
incluindo 11 de EditBloc, 18 de EditScreen e o teste composto de módulo anteriormente
bloqueado. O command e seus testes legados foram removidos; o check arquitetural
agora impede commands em todo User. A análise e a suíte globais continuam bloqueadas
pelo legado de outras features (`Either`, `response<T>` e CommandIt), sem novos
problemas identificados em User. A fixture compartilhada passou em verificações
HTTP locais de nome 422/200, perfil preservado, compatibilidade do avatar, Bearer
e retenção/liberação. Nenhum flow E2E foi executado em dispositivo.

Na simplificação de `delete` para `Future<void>`, `flutter pub get` e a análise
focada de User, seu suporte/testes e o preview consumidor de Dashboard concluíram
sem problemas. `flutter test test/architecture test/features/user` passou com
137 testes. Análise e testes globais foram executados e continuam falhando pelos
consumidores legados de outras features. Não houve execução E2E nesta alteração.

Na primeira rodada de Metrics, `flutter pub get` concluiu. A análise focada de
application/infrastructure/domain, fakes de preview, seus testes/suporte e check
arquitetural passou sem problemas. O comando `flutter test test/architecture
test/features/authentication test/features/settings test/features/session
test/features/root test/features/user test/features/metrics/application
test/features/metrics/infrastructure test/features/metrics/domain
test/features/metrics/presentation/extensions` passou com 456 testes. A cobertura
inclui filtros opcionais, datas civis, centavos grandes sem perda de precisão,
categorias, parsing inválido, erros HTTP, falhas inesperadas e espera da resposta.

Os testes de módulo/command de Metrics e do Bloc consumidor de Dashboard foram
executados, mas continuam bloqueados na compilação por CommandIt e pelo Either
dos demais contextos financeiros. A análise e a suíte globais também falham
nesses consumidores legados. Não foram restauradas dependências antigas nem
declarados DI, UI, previews ou E2E aprovados em execução nesta rodada.

Na substituição do command de Metrics, `flutter pub get` concluiu. `dart analyze`
de Metrics, testes/suporte, check arquitetural e dos dois previews consumidores
passou sem problemas. `flutter test test/architecture test/features/metrics`
passou com 106 testes, incluindo 14 de Bloc e o teste de módulo com repository
real sobre HTTP mockado. A análise global encontrou 334 problemas e `flutter test`
global terminou com 606 testes aprovados e 22 falhas, incluindo compilação legada
por Either/CommandIt/response, testes antigos de headers e referência não resolvida
a `userDependenciesModule` fora do escopo. Não houve execução visual dos previews
ou E2E; a Dashboard ainda importa os contratos financeiros legados.

Na primeira rodada de Insight, `flutter pub get` concluiu. A análise focada de
domain/application/infrastructure, fake de preview, testes/suporte e check
arquitetural passou sem problemas. `flutter test test/architecture
test/features/metrics test/features/insight/application
test/features/insight/infrastructure test/features/insight/domain` passou com 134
testes, incluindo 28 de Insight. A cobertura verifica filtros opcionais, conteúdo
e ordem, períodos, onboarding, lista vazia, parsing inválido, erros HTTP, falhas
inesperadas e espera da resposta.

Os testes de módulo/command de Insight e do consumidor Dashboard foram executados,
mas falharam na compilação por CommandIt e pelo Either ainda usado em Expense.
O teste novo do módulo não constitui DI aprovada enquanto o command o bloquear.
`flutter analyze` global encontrou 288 problemas; `flutter test` global terminou
com 626 testes aprovados e 21 falhas, incluindo bloqueios de compilação e os
testes antigos de headers. Não houve execução visual dos previews ou E2E, nem
restauração de dependências legadas. Nenhum Bloc foi criado em Insight nesta rodada.

Na segunda rodada de Insight, `flutter pub get` concluiu. `dart analyze
lib/features/insight test/features/insight test/support/insight
test/architecture/bounded_context_dependencies_test.dart` passou sem problemas.
`flutter test test/architecture test/features/metrics test/features/insight` passou
com 152 testes, incluindo 17 de InsightsBloc e o teste de módulo anteriormente
bloqueado, agora verificando factories independentes sobre repository real e
client HTTP mockado. O command e seus testes legados foram removidos; a regra
arquitetural impede commands em Insight. A análise global encontrou 284 problemas
fora de Insight; a suíte global terminou com 644 testes aprovados e 19 falhas,
incluindo compilação legada e testes antigos de headers. Não houve execução visual
dos previews ou E2E. Dashboard ainda depende dos contratos legados de Expense.

Na primeira rodada de Expense, `flutter pub get` concluiu. A análise focada de
application/domain/infrastructure, fakes de preview, Dashboard, testes/suporte
correspondentes, SessionInterceptor e check arquitetural passou sem problemas.
O lote abaixo passou com 380 testes, incluindo CRUD, parsing, erros HTTP,
paginação, centavos, datas civis, coordenação da Dashboard e autenticação Bearer:

```bash
flutter test test/architecture test/features/expense/application test/features/expense/infrastructure test/features/expense/domain test/features/expense/presentation/extensions test/features/expense/presentation/screens/expense/validators test/features/dashboard/presentation/screens/dashboard/bloc test/features/metrics test/features/insight test/features/core/infrastructure/clients/http/interceptors/session_interceptor_test.dart
```

`flutter analyze` global encontrou 75 problemas; `flutter test` global terminou
com 831 testes aprovados e 11 falhas. Permanecem bloqueados os commands, telas e
teste de módulo de Expense por CommandIt removido; testes antigos de response e
do handler CommandIt, headers e a referência `userDependenciesModule` também
continuam pendentes. A análise global ainda reporta um import não utilizado em
Insight fora do escopo. Os testes dos commands foram adaptados ao novo contrato,
não validados em execução. Não houve execução visual de previews ou E2E.

O código financeiro existente inclui formulário compartilhado de criação/edição,
listagem com paginação/filtros/gestos, métricas e insights na Dashboard, além de
perfil e avatar. São comportamentos a preservar durante migrações, não modelos
de camadas a replicar. Em particular:

- Preserve centavos, datas civis, filtros explícitos e continuações opacas.
- Preserve seleção mensal da Dashboard. Cadastro recarrega após resultado
  confirmado; listagem recarrega ao retornar, inclusive sem alteração.
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
flutter test test/features/authentication/authentication_sign_in_module_test.dart
flutter test test/app_module_test.dart
flutter test test/features/expense/expense_module_test.dart
flutter test test/features/metrics/presentation/widgets/expense_category_metrics_card_widget_test.dart
flutter test test/features/authentication/presentation/screens/sign_up
flutter test test/features/authentication/presentation/screens/resend_email
flutter test test/features/authentication/presentation/screens/callback test/features/authentication/authentication_callback_module_test.dart
flutter test test/features/settings
flutter test test/features/session test/features/root
```

Registre comandos, resultado e causa de bloqueios. Teste focado aprovado não
implica suíte ou app aprovados. Documentação pura pode ser revisada sem executar
Flutter; não invente resultado de análise, testes ou execução no dispositivo.

## Revisão De Documentação

- `ARCHITECTURE.md`: decisões, camadas, contratos, estado de migração e testes.
- `AGENTS.md`: regras operacionais para implementar e revisar essas decisões.
- `README.md`: produto, pré-requisitos, início rápido e limitações atuais.
- `android/README.md`: build, assinatura e verificação de release Android.
- `.opencode/skills/cordato-*/SKILL.md`: orientações locais alinhadas às regras.
- `openspec/README.md`: precedência, histórico e mapa de specs vigentes/legadas.
- `test/**/e2e/README.md`: execução de fixtures/flows e limites de validação.

Mudanças estruturais atualizam os documentos afetados na mesma alteração.
Histórico de OpenSpec não substitui o código atual nem redefine estas decisões.
