# Cordato

Aplicativo Flutter de finanças pessoais e familiares. O objetivo é ajudar cada
pessoa a cuidar do próprio dinheiro com clareza e, quando fizer parte de uma
família, oferecer uma visão compartilhada das finanças de seus membros.

## Produto

O modelo de negócio tem como referência o backend legado em Kotlin. O app usa
uma API HTTP JSON:API para autenticação e possui data sources remotos de User, Expense, Insight e Metrics;
o cadastro de despesas está conectado à API. A regra central é:

> A pessoa é dona dos próprios dados. A família é apenas uma lente de leitura.

Os bounded contexts do produto são:

- `user`: modelo de domínio, contrato de repository e data source HTTP para
  consulta, atualização do nome e exclusão, com repository concreto e UI de
  edição de nome integrada à API pelo ID persistido no sign-in.
- `expense`: entidade de domínio, value object para valores positivos em centavos,
  categorias com rótulos pt-BR, input e contrato
  de repository para criação, implementação de repository, command, DTO e data
  source HTTP, com formulário e validators integrados ao cadastro e consulta
  paginada consumida pela Dashboard e pela listagem completa.
- `budget`: planejado. Tetos por intervalo de datas, com gasto e saldo derivados.
- `family`: planejado. Organização familiar com acesso combinado somente de leitura.
- `insight`: análises derivadas somente leitura consultadas pela API, com domínio,
  repository, DTOs, data source HTTP e `GetInsightsCommand`. Cards informativos
  na Dashboard, sem persistência própria.
- `metrics`: agregações somente leitura consultadas pela API, com distribuição
  mensal dos gastos em cards ilustrados por categoria na Dashboard.

O contexto `identity` do backend não será reproduzido no app neste momento. A
autenticação por e-mail e senha usa a API JSON:API; há sign-in, sign-up,
confirmação de e-mail por link e reenvio da verificação. O token opaco do
sign-in e o ID do usuário são salvos em storage seguro. A feature `session` lê
o token na abertura e observa mudanças para decidir entre dashboard e welcome, inclusive após o
logout confirmado em Settings. Não há validação da sessão no backend ao iniciar.
O contexto `chat` está fora do escopo atual.

## Estado atual

O app já possui:

- tela de boas-vindas;
- tela de entrada `AppScreen` em `/`, com logo e decisão inicial pela presença do token;
- tela de sign-in com validação, feedback de erro e persistência segura do token
  e do ID do usuário no sucesso, seguida de navegação para o dashboard;
- tela de sign-up com validação e tela de reenvio da verificação que mostra o e-mail
  cadastrado em um campo desabilitado após o sucesso, com reenvio do link de
  verificação após uma espera de 60 segundos e feedback da API;
- dashboard com nome e avatar gerado a partir da semente consultada na API por `UserCommand`,
  carrossel de cards de distribuição dos gastos por categoria no topo, com
  total em BRL, navegação mensal, valores e percentuais por categoria. As páginas
  têm um card ilustrado acima e dois menores abaixo; a última página com duas
  categorias mantém um card inferior em largura total. As alturas são uniformes
  por linha e grupos de uma categoria ficam ocultos. O carrossel é seguido de
  cards de insights com ícone e cor por tipo em lista horizontal acima das despesas,
  e seção de despesas recentes com as seis primeiras despesas do mês na API, skeleton,
  estado vazio, erro com título e descrição e atualização por gesto ou
  ao retornar do formulário de gasto e da listagem completa; insights e despesas
  são atualizados em paralelo com as métricas. O seletor mensal controla as três
  seções, impede meses futuros e bloqueia as setas enquanto qualquer seção carrega.
  Cada seção possui skeleton no mês selecionado, sem dados do mês anterior sob
  o novo título. Falha financeira apresenta uma tela de erro com retry único,
  preservando o mês até a recuperação das três seções, sem cabeçalho durante o
  erro e a recuperação. Insights vazios ocultam a seção; recentes
  vazios indicam ausência de despesas naquele mês. Refresh preserva a seleção;
- listagem completa em `/expenses`, aberta por “Ver tudo” da Dashboard, com
  rolagem infinita em páginas de 20 itens, atualização por gesto, skeleton, vazio
  e nova tentativa após erro, preservando os itens já carregados em refresh e
  paginação. O cabeçalho mantém “Despesas” e “Acompanhe todas as suas despesas.”.
  Categoria e período recebidos da Dashboard aparecem em pílulas removíveis,
  identificadas também na acessibilidade. Remover categoria mantém o período;
  remover período consulta o histórico completo da categoria restante. A troca
  limpa itens e cursor, volta ao topo e consulta a primeira página. Paginação,
  refresh, retry e edição respeitam os filtros ativos. Despesas editadas para
  outro mês saem do recorte somente enquanto o período permanece ativo;
  edição dentro do mês e exclusão preservam agrupamentos, paginação e rolagem.
  A rota sem período continua oferecendo a listagem geral;
- formulário de gasto integrado à API, com descrição obrigatória, calculadora
  de valor em centavos, seleção de data, validação, loading, erros por campo e
  toast de sucesso; toque simples cadastra e retorna ao dashboard, enquanto
  completar o hold cadastra e limpa o formulário para adicionar outro gasto.
  Quando aberto pela Dashboard, sucesso por toque simples ou cancelamento retorna
  à mesma tela com o mês selecionado preservado e as três seções recarregadas.
  A data inicial continua sendo hoje, inclusive ao visualizar um mês passado;
  acesso independente mantém Dashboard como destino após o cadastro;
- tela de configurações com confirmação de saída, loading e erros em toast;
  o logout revoga o token na API e limpa o storage seguro, com retorno à welcome
  pelo observador global de sessão;
- tela de dados pessoais em `/user`, aberta por Settings, com nome clicável,
  nome e e-mail consultados na API por `UserCommand`, skeleton e opção de tentar
  novamente em caso de erro, e-mail desativado e exclusão de conta com confirmação,
  loading e feedback de erro por `DeleteUserCommand`; após exclusão confirmada,
  a limpeza da sessão redireciona para as boas-vindas;
- avatar gerado com `flutter_boring_avatars`, estilo `marble`, compartilhado entre
  Dados pessoais e Dashboard; refresh permite experimentar opções e salva a última
  seed automaticamente após dois segundos sem regenerar, usando `avatar` na API;
  cada clique reinicia o prazo. Falhas preservam a escolha e mostram erro; sair
  antes do envio cancela o salvamento pendente. A Dashboard recarrega
  nome e avatar ao retornar de Dados pessoais ou Settings;
- tela de edição de nome em `/user/edit`, aberta pelo item Nome, seguindo a UI
  centralizada da autenticação, com atualização pela API, loading, erros no campo
  ou toast e retorno dos dados atualizados para a tela de dados pessoais;
- navegação de Welcome para Sign In, de Sign In para Sign Up por substituição
  de rota e de Dashboard para Settings e Expense;
- tema claro/escuro e componentes de apresentação reutilizáveis;
- confirmação automática de e-mail ao abrir o link HTTPS, com feedback por toast
  e retorno ao sign-in após sucesso, expiração ou erro de conexão, sem criar sessão;
- remoção do token após 401 em requisição protegida e retorno à welcome quando
  o usuário estiver em uma rota protegida;
- estrutura de `user` com entidade, contrato de repository, DTO e data source
  HTTP para buscar por ID, atualizar somente o nome e excluir o usuário; essa
  estrutura está registrada em DI e é consumida pela tela de edição.

A tela de dados pessoais consulta o perfil ao abrir e novamente após salvar
o nome, usando o ID persistido no sign-in.

`budget` e `family` seguem planejados. Ao integrar esses contextos, o grupo
familiar não deve se tornar dono dos dados financeiros de seus membros.

## Arquitetura

O código é organizado por feature e por camadas:

```text
Screen/Widget -> Command -> contrato de repository (domain)
  -> repository (application) -> data source (infrastructure) -> HTTP/storage
```

`presentation` não conhece SDKs externos. `domain` contém contratos e regras
independentes de framework, `application/repositories/` implementa os repositórios,
`application/data/` reúne tipos puros de entrada e
`infrastructure` contém data sources que acessam HTTP, storage e plugins. Na
autenticação, o data source remoto usa o `IHttpClient` compartilhado do core
diretamente; `session` encapsula a leitura e a observação do token para a
entrada do app. Essas camadas estão implementadas em Authentication, User,
Session e Expense; features exclusivamente visuais não precisam de camadas vazias.

```text
lib/features/<feature>/
  <feature>_module.dart
  domain/
    entities/
    repositories/
  application/
    data/
    repositories/
  infrastructure/
    local/
    remoto/
    responses/
  presentation/
    commands/
    screens/
    widgets/
```

A árvore representa as localizações aprovadas; cada feature contém somente
diretórios necessários às suas implementações. Os contratos de repository ficam
em `domain/repositories/`, enquanto as implementações ficam em
`application/repositories/` e seus testes em
`test/features/<feature>/application/repositories/`. A criação de Expense recebe
`cents`, `description` e `occurredOn` como parâmetros nomeados no repository e
no data source; o command transporta esses campos em um record.

Dashboard compõe User e Expense pelos commands e widgets de apresentação.
Expense organiza os commands e mixins por tela em
`presentation/screens/expense/` e `presentation/screens/expenses/`.
Os validators do formulário ficam em `screens/expense/validators/`.
`ExpenseScreen` compartilha cadastro e edição na rota `/expense`: sem argumento
abre cadastro; com ID textual consulta a API e mostra skeleton até preencher o
formulário. O record opcional `({bool returnToPrevious})` com valor `true`, enviado
pela Dashboard, faz o sucesso do cadastro fechar o formulário com `pop`, sem
recriar a Dashboard. Sem argumento, o sucesso navega para `/dashboard`.
Ao abrir cadastro ou listagem pela Dashboard, voltar sem alterações preserva
os dados exibidos, sem novas consultas. Criação, edição ou exclusão confirmada
sinaliza a alteração por `onExpensesChanged` no record da rota e atualiza as
três seções ao retornar, inclusive após cadastro por hold e voltar pelo sistema.
A listagem abre a edição ao arrastar o item da esquerda para a direita,
revelando o lápis; o gesto oposto mantém a exclusão. Recebe a entidade atualizada
ao retornar, preservando paginação e rolagem. O PATCH altera valor, descrição e
data civil, enviando somente os atributos alterados. O envio e os toasts refletem o modo ativo.
`GetExpensesCommand` pertence a `screens/expenses/commands/` e continua sendo
consumido pela Dashboard por uma instância própria registrada por factory.
Os contratos de consulta de Expense aceitam `from`/`to` opcionais, serializados
como `filter[from]`/`filter[to]` por data civil. A paginação reaplica limites
explícitos e tamanho, remove filtros herdados de ano/mês/dia incompatíveis e
preserva a continuação. Insight aceita `year`/`month` opcionais em
`filter[year]`/`filter[month]`, preservando integralmente as análises retornadas.
Consultas sem filtros continuam disponíveis na listagem geral e em outros
consumidores. A Dashboard envia o mês selecionado às três consultas; o intervalo
civil respeita viradas de ano e fevereiro bissexto.
Os cards de categoria possuem bounce e abrem a mesma listagem de “Ver tudo”,
acrescentando `filter[category]` ao mês selecionado. A listagem identifica mês
e categoria em pílulas removíveis abaixo da descrição fixa. Os filtros são
estado local inicializado pelos argumentos: rebuilds e troca isolada do command
não restauram filtros removidos. Mudanças efetivas nas entradas reiniciam a lente,
ignorando respostas antigas. Remoção limpa o resultado antes da consulta, enquanto
refresh da mesma lente preserva os itens até sucesso. Falha após remoção mantém
os filtros novos e permite retry da primeira página. Loading, edição e confirmação
ou execução de exclusão bloqueiam remoções. Remover filtros não chama
`onExpensesChanged` nem altera o mês da Dashboard; reabrir a listagem restaura a
combinação enviada nessa nova abertura.
`ExpensesSkeletonWidget`, de `expense/presentation/widgets/`, é reutilizado nas
duas telas: seis placeholders na Dashboard, oito na listagem sem itens e três
no rodapé durante consultas com despesas já carregadas.

Decisões técnicas atuais:

- Dart `^3.13.2` e primary constructors para declarações elegíveis;
- `flutter_modular` 7 com módulos de dependências separados dos módulos de rotas;
- `command_it` para operações observáveis e estado efêmero local nos widgets;
- Material 3 via `material_ui`, tema compartilhado, Inter e localização `pt_BR`;
- `Requests` com parâmetros nomeados e somente `path`, `body`, `query` e `headers`;
  caminhos do enum são usados diretamente, com IDs interpolados no data source;
- `response<T>` compartilhado no core para conversão de sucesso e tratamento
  dos erros JSON:API nos data sources;
- testes unitários para lógica e adapters; validação visual e de fluxos com
  Maestro, sem suíte Flutter de widgets ou `integration_test`.

`AppWidget` cuida de tema, router, toast e redirecionamentos globais;
`AppScreen` compõe a entrada do app. Ambos ficam em
`lib/features/root/presentation/`; `root` reúne a apresentação de composição
global, e `app_module.dart` registra a rota `/`.
`session` observa o token sem importar `authentication`; o logout é um command
de `authentication` consumido por Settings. Não há guard de rota do Modular
nem validação ou renovação automática do token no app.

Consulte [`ARCHITECTURE.md`](ARCHITECTURE.md) para módulos, rotas, limites
técnicos e validação, e [`AGENTS.md`](AGENTS.md) para as convenções de
contribuição.

## Desenvolvimento

```bash
flutter pub get
flutter analyze
flutter test
```

Para abrir os previews de telas e componentes no Widget Previewer do Flutter:

```bash
dart run tool/widget_preview.dart
```

Abra no navegador a URL impressa pelo comando. O launcher usa
`flutter widget-preview start --web-server` e dispara uma atualização após o
servidor iniciar para contornar a descoberta vazia na abertura do Flutter 3.47.6
e 3.47.7.
A atualização cria um arquivo Dart temporário em `tool/`, removido ao encerrar o
comando, sem reescrever os arquivos da aplicação.
Se o painel de preview do editor mostrar “No previews detected”, use a ação de
atualização do painel após a análise inicial.

O catálogo mensal inclui a Dashboard completa em claro/escuro, carregamento
agregado, mês vazio e falha parcial; o seletor inclui fevereiro bissexto e
virada de ano. A listagem possui previews de categoria + mês, somente mês,
somente categoria, entrada geral, loading, vazio e falha com retry. Também cobre
categoria longa em largura reduzida, texto ampliado, categoria futura e intervalo
não mensal, além de paginação de 20 itens. Todos usam fakes locais sem
rede ou storage. Previews não substituem a validação da API e dos fluxos reais
com Maestro; os resultados são registrados na change OpenSpec.

Para executar o app, use `flutter run`. A autenticação usa por padrão
`https://app.cordato.cloud/api/`. Para apontá-la a outra API:

```bash
flutter run --dart-define=BASE_URL=https://api.exemplo.com/api/
```

O valor de `BASE_URL` deve incluir o prefixo `/api/`. A factory HTTP acrescenta
a barra final quando omitida, aceitando também bases terminadas em `/api`.
O domínio de entrada de produção confirmado para `APP_URL` é
`https://app.cordato.cloud`. Esse servidor precisa oferecer a página
`/authentication/confirm-email` e os arquivos de associação Android e iOS
em `/.well-known/`.

Para usar o backend local do Lerd em um Android físico conectado por USB, execute
`python3 tool/android_usb_proxy.py --device <id-do-adb>` e mantenha esse terminal
aberto antes de iniciar **Cordato (debug)** no VS Code. Consulte o ID com
`adb devices`. O proxy escuta somente no loopback do Mac, encaminha a API para
`https://trocado.test` com validação pelo CA do mkcert e configura `adb reverse`.
O perfil de debug usa `http://127.0.0.1:8765/api/`; o Android não precisa resolver
`.test` nem instalar o certificado do Mac. Reexecute o proxy após reconectar o USB.

Para usar o backend local do Lerd em um Android na mesma rede, execute
`make android-lan` antes de iniciar **Cordato (debug)** no VS Code. O comando
compartilha o site pelo IP da rede e atualiza a URL de debug em
`.vscode/launch.json`; reinicie o app para aplicar o novo `--dart-define`.
O backend é procurado em `../../../BackEnd/PHP/Trocado` a partir deste projeto;
use `make android-lan LERD_SITE_PATH=/caminho/do/backend` se estiver em outro
local. O HTTP da rede local é permitido apenas no build Android de debug.

No simulador iOS, execute
`flutter run --dart-define=BASE_URL=https://trocado.test/api/`. O simulador usa
o domínio HTTPS local do Lerd no Mac. A configuração **Cordato (debug)**
aponta para o proxy USB Android no arquivo versionado, mas `make android-lan` a
substitui pelo IP da rede para Android. Reinicie o app após mudar o
`--dart-define`.

As configurações **Cordato (profile)** e **Cordato (release)** do VS Code
atualmente sobrescrevem a base com `https://app.cordato.cloud/api`, diferente
do padrão de `coreDependenciesModule`. Consulte `.vscode/launch.json` ao
executar por esses perfis; `BASE_URL` é definido em tempo de compilação.

## Firebase

O app inicializa Firebase Core e configura Crashlytics no bootstrap após
montar as dependências do Modular, usando o projeto
`trocado-d362e` (Trocado). Android e iOS estão registrados com o identificador
`com.bed.cordato`. Core, Crashlytics e Cloud Messaging usam a instância padrão.
Seus clientes ficam juntos em `lib/features/core/infrastructure/clients/firebase/`.

Os arquivos de configuração estão em
`lib/features/core/infrastructure/clients/firebase/firebase_options.dart`,
`firebase.json`, `android/app/google-services.json` e
`ios/Runner/GoogleService-Info.plist`. Para regenerá-los com acesso ao projeto:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure \
  --project=trocado-d362e \
  --out=lib/features/core/infrastructure/clients/firebase/firebase_options.dart \
  --platforms=android,ios \
  --android-package-name=com.bed.cordato \
  --ios-bundle-id=com.bed.cordato
```

Após regenerar, revise o diff e remova comentários adicionados em código Dart
e Gradle conforme as convenções do projeto. Para executar, escolha um dispositivo
Android ou iOS com `flutter run -d <id-do-dispositivo>`.

Crashlytics captura erros do framework e erros assíncronos não tratados pelos
handlers conectados diretamente ao `ICrashClient` resolvido pelo Modular.
A coleta segue o padrão do Firebase, sem configuração por modo de build no app.
Para confirmar no console, execute um
build release em dispositivo, registre um erro controlado e confira o relatório
do app correto no projeto `trocado-d362e`. O recebimento real ainda não foi
validado. Para falhas nativas fatais, o relatório normalmente é enviado na
abertura seguinte, sem debugger conectado.

O iOS usa Swift Package Manager. O script `ios/upload_crashlytics_symbols.sh`
envia os símbolos nos builds Release para dispositivo e requer FlutterFire CLI
no PATH da máquina de build. Debug, Profile e simulador não executam o envio.
Após regenerar a configuração pelo CLI, preserve essa fase e o script próprio.
Se usar `--split-debug-info`, guarde os símbolos Dart e envie-os separadamente
com `firebase crashlytics:symbols:upload --app=<firebase-app-id> <diretorio>`.

Cloud Messaging está disponível por `IMessagingClient` no módulo do core para
solicitar permissão, consultar token, observar renovação e receber mensagens em
primeiro plano com o payload completo. O app ainda não pede permissão na abertura,
não envia tokens ao backend e não exibe mensagens em primeiro plano nem navega
ao tocar em uma notificação. Mensagens somente de dados em background ainda não
possuem handler Dart.

Para completar o push no iOS:

1. Configure a chave APNs `.p8`, Key ID e Team ID em **Configurações do projeto →
   Cloud Messaging → app iOS `com.bed.cordato`** no console Firebase.
2. Use uma conta Apple Developer e provisioning profile com Push Notifications.
   O projeto já declara a capability e os modos de background; a exportação
   assinada deve usar o ambiente APNs apropriado ao profile.
3. Solicite a permissão pelo cliente. Antes de consultar o token FCM, o token
   APNs precisa estar disponível; enquanto não estiver, o cliente retorna `null`.

Para testar entrega, autorize notificações, obtenha o token no dispositivo e
use **Messaging → Enviar mensagem de teste** no console, com o app em background.
Android precisa de Google Play Services. A entrega real de push e a configuração
APNs remota ainda não foram validadas. A chave `.p8` não deve ser versionada.

## Notificações Locais

`flutter_local_notifications` fornece a exibição nativa por
`INotificationClient`, registrado como lazy singleton no Modular. O cliente
fica em `lib/features/core/infrastructure/clients/notification/notification_client.dart`.
O consumidor deve aguardar `initialize()` antes de
chamar `show(id: ..., title: ..., body: ...)`.

A inicialização configura o canal Android `cordato_default` com importância alta
e o ícone existente `ic_notification`, sem pedir permissão no iOS. A permissão
de notificações deve ser solicitada explicitamente pelo fluxo consumidor,
usando `IMessagingClient.requestPermission()`. O adapter propaga falhas do plugin.

Esta etapa prepara a infraestrutura de exibição imediata. O aplicativo ainda
não inicializa o cliente automaticamente, não conecta mensagens FCM à exibição,
não agenda notificações e não implementa navegação ao tocar. A exibição local
não exige chave APNs nem backend.

A exibição real foi validada no Android conectado com Maestro, usando um
entrypoint temporário e as dependências do Modular: inicialização, exibição,
título e corpo no painel de notificações. O build debug para simulador iOS
também foi verificado; a exibição real no iOS ainda não foi validada.

## Android Release

O processo de configuração segura da chave, build e verificação de artefatos
Android está documentado em [`android/README.md`](android/README.md).

## API E Persistência

`coreDependenciesModule` registra o Dio compartilhado, o cliente HTTP e o storage seguro.
O fluxo de autenticação passa por command, contrato de repository, repository
e data sources remoto/local. O remoto monta as requisições e usa `IHttpClient`
do core diretamente, sem client próprio da feature. `HttpClient` preserva
status e corpo em `HttpResponse`; `SignInResponse` e `SignUpResponse` leem os
mapas JSON com Dart puro, o data source remoto converte erros JSON:API e o
local grava token e ID do usuário. A API é externa a este repositório; não há
schema ou migrations do backend financeiro versionados aqui. Ao conectar as features
financeiras, preserve propriedade individual, autorização e invariantes no
serviço responsável, com testes próprios.

`AuthenticationLocalDataSource` usa `IStorageClient`, implementado por
`StorageClient` com `FlutterSecureStorage`. `saveToken` grava
`StorageKeyEnum.opaqueToken` (`@trocado.opaque_token`) e `saveUserId` grava
`StorageKeyEnum.userId` (`@trocado.user_id`). O repository aguarda ambas as
gravações com `Future.wait` antes de retornar sucesso. Após revogação remota
aceita no logout, `clear()` limpa todo o storage seguro. Um 401 de endpoint
protegido remove somente o token enviado, sem limpar o ID do usuário.

`HttpPathEnum.authenticated` marca endpoints protegidos; o
`SessionInterceptor` só envia `Authorization: Bearer <token>` quando o
caminho relativo coincide com a origem e o endpoint da API. `Bearer` é o esquema
HTTP, não o formato do token. A validade é controlada pelo backend; o app não
implementa refresh nem bloqueia chamadas por `expiresAt`. A confirmação por
link usa uma URL absoluta. URLs absolutas não recebem token. O cliente HTTP
atual não configura uma política específica de redirecionamentos ou logging
para essas URLs. Um 401 de
requisição protegida remove o token somente se ele ainda for o token enviado;
`SessionCommand` observa a mudança e o app volta à welcome se estiver em uma
rota protegida.

A integração HTTP atual inclui os fluxos de autenticação e o data source e
repository de User, registrados em `userDependenciesModule` e compostos por
`appModule`, com atualização de nome consumida por `UpdateUserCommand` na edição.
As operações `getById()`, `update({String? name, String? avatar})` e `delete()` de `UserRepository`
leem o ID por `UserLocalDataSource.getId()` e chamam o data source remoto
com o ID explícito; ID ausente impede a requisição. `UserRepository` converte
respostas e erros remotos para os tipos de domínio nas operações de consulta,
atualização do nome e exclusão. Após exclusão de User confirmada com status 204,
o repository aguarda a limpeza de todo o storage seguro por `UserLocalDataSource`,
que delega a `IStorageClient.clear()`. `expenses` consta
no catálogo de endpoints protegidos e é usado por `ExpenseRemoteDataSource.create`
e `get`, além dos endpoints de recurso usados por `getById`, `update` e `delete`.
O POST envia centavos inteiros, descrição e data civil como `yyyy-MM-dd`, e retorna
`ExpenseResponse`; sua conversão à entidade valida o valor pelo VO. O data source
é registrado em DI e consumido por `ExpenseRepository` e `CreateExpenseCommand`
no formulário. A consulta preserva a ordem da API e entrega páginas imutáveis
com `next` e `prev` opacos. `ExpenseRepository.get` usa `pageSize = 30` por
padrão e substitui tamanhos menores ou iguais a zero por 30 antes da consulta.
`GetExpensesCommand` não acumula páginas. Dashboard
solicita seis itens, enquanto `ExpensesScreenStateMixin` acumula páginas de 20
e preserva os itens após falhas. O logger Dio
de debug registra headers e payloads, inclusive credenciais e resposta de
sign-in e URLs absolutas como a confirmação assinada. Em release esse logger
não é instalado.

Os data sources de Authentication, User e Expense reutilizam a função top-level
`response<T>` em `core/infrastructure/clients/http/responses/responses.dart`.
Ela recebe `execute` para a requisição e `from` para converter o `HttpResponse`
de sucesso, com acesso ao corpo e ao status, e retorna `Either<ErrorsResponse, T>`.
Erros JSON:API são preservados; exceções inesperadas viram erro genérico.
O status da confirmação de e-mail continua sendo tratado por Authentication.

## Revisão De Mudanças

Mudanças em módulos, rotas, contratos, integração HTTP, comandos de validação
ou configuração de release devem atualizar, na mesma alteração, a
documentação canônica correspondente. Consulte a seção de revisão em
[`ARCHITECTURE.md`](ARCHITECTURE.md#revisão-de-documentação).

Não adicione comentários no código, incluindo comentários de documentação.
Use nomes e estrutura claros e registre explicações e decisões nos arquivos
Markdown, conforme a regra de [`AGENTS.md`](AGENTS.md#comentários-no-código).
