# Cordato

Aplicativo Flutter de finanças pessoais e familiares.

> Cada pessoa é dona dos próprios dados. A família é uma lente de leitura,
> nunca dona do dinheiro ou autorizada a escrever nos dados de outro membro.

## Arquitetura

Authentication/Sign-in é a referência obrigatória para desenvolvimento e testes:

```text
Screen/Form -> Bloc -> contrato de repository (application)
                         -> repository (infrastructure)
                         -> clients do core -> HTTP/storage
```

- Organização por feature, sem camadas ou abstrações vazias.
- Domain com entidades e regras puras; application com contratos e exceções.
- Repositories concretos em `infrastructure/repositories/`, usando `IHttpClient`
  e `IStorageClient` diretamente, sem data sources intermediários desnecessários.
- Retorno por `Future<T>`; falhas esperadas por exceção de aplicação, sem Either.
- Bloc com eventos concretos e estados sealed imutáveis. Sign-in usa ownership
  pelo escopo Modular; telas ainda não migradas mantêm ownership local. Formulário
  mantém entrada e validação, sem copiar loading ou resultado do Bloc.
- Testes de repository, Bloc, widget, composição Modular e E2E junto à feature/tela.

CommandIt, Either, data sources de delegação e repositories concretos em
application descritos em documentos históricos não são alternativas aprovadas
para código novo nem dependências a restaurar.

Leia [ARCHITECTURE.md](ARCHITECTURE.md) para decisões e fronteiras e
[AGENTS.md](AGENTS.md) para convenções de contribuição.

## Backend PocketBase

O backend adotado é **PocketBase 0.41.1**, isolado em [`backend/`](backend/README.md),
com Compose, imagem, migrations e testes próprios. Usa APIs e regras nativas,
sem Node, hooks ou worker. No Dokploy, usar `backend/compose.yml` com contexto de
build em `backend/`. Ele não depende do build Flutter e não deve receber arquivos
ou segredos do aplicativo.

A configuração foi trazida do repositório backend anterior; nenhum banco, volume,
segredo ou histórico Git foi transferido. O aplicativo **ainda não foi migrado**
para a API PocketBase; os contratos Flutter descritos abaixo permanecem como estão.

| Parte | Estado atual |
| --- | --- |
| Backend em `backend/` | Contas e despesas próprias nas coleções `users` e `expenses`; contrato nativo PocketBase. |
| Cliente Flutter em `lib/` | Continua usando endpoints, envelopes JSON:API e sessão do contrato anterior. |
| Metrics e sugestões | Existem no cliente; não há implementação equivalente no backend PocketBase atual. |
| Budget e Family | Planejados; não implementados no backend atual nem nas features Flutter. |
| Integração e operação | Migração do cliente, homologação integrada e validação no Dokploy ainda pendentes. |

Trocar apenas `BASE_URL` não integra o aplicativo ao PocketBase. Autenticação,
erros, paginação, datas e recursos disponíveis possuem contratos diferentes.
Veja os [limites da integração](ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração).

## Estado Do Projeto

**O checkout está em transição arquitetural. Testes de composição não substituem
a validação da navegação em dispositivo.**

Authentication já possui contrato em application e repository em infrastructure.
Sign-in, cadastro e reenvio usam Bloc, controle de submissões concorrentes, falhas tipadas
e testes de Bloc/tela. Cadastro mantém erros por campo, retry manual e navegação
para confirmação sem criar sessão. Reenvio preserva cooldown inicial/de sucesso
de 60 segundos e retry manual imediato após falha, sem criar sessão.
Confirmação por link também usa Bloc: preserva o link original, ignora resultados
obsoletos e retorna ao sign-in com o feedback existente, sem criar sessão.
Logout usa `LogoutBloc` na apresentação de Settings, consumindo o contrato de
Authentication. Mantém confirmação, loading, erros e retry manual, com revogação
remota antes da limpeza do storage. O redirecionamento continua global por sessão.
Authentication não possui mais apresentação baseada em commands; isso não
significa que todas as demais features já foram migradas.

Sign-in é o piloto de escopo de página do Modular V7: a extension `addBloc` do
core registra o Bloc no `provide` da rota, que cria e fecha a instância. A tela
recebe o Bloc pronto e mantém `BlocConsumer`. O novo `ExpenseSuggestionsBloc`
também pertence ao escopo da rota; os demais fluxos continuam com ownership pelas
telas e Session permanece sob ownership global de `AppWidget`.

Session também usa contrato em application, repository direto em infrastructure
e Bloc. `AppWidget` é o único dono da observação contínua e do fechamento;
`AppScreen` apenas mostra o splash. Uma mudança recente do token tem precedência
sobre uma leitura inicial antiga. Falhas de storage não apagam o token nem
confirmam ausência: Root usa Welcome como fallback seguro e mantém a observação.

User já possui contrato em application, `UserException` e repository em
infrastructure usando HTTP/storage diretamente, sem `Either` ou data sources.
Consulta, nome, avatar e exclusão mantêm seus contratos de API; exclusão confirmada
aguarda a limpeza do storage. A tela de perfil agora usa `UserBloc` para consulta,
avatar e exclusão, com lifecycle próprio, debounce de dois segundos, confirmação
de exclusão, feedback único e bloqueio de operações concorrentes. A edição do
nome usa `EditBloc`, preservando validação, trim no formulário, erros 422 por
campo, entrada após falha e retorno do perfil atualizado após sucesso. User não
usa mais commands. Os testes de repository usam clients mockados, e os de
Bloc/tela usam o contrato do repository mockado. O teste composto do módulo
verifica os dois Blocs, edição e retorno com recarga do perfil.

Metrics também usa contrato em application, `MetricsException` e repository em
infrastructure chamando HTTP diretamente, sem Either ou data source. Preserva
filtros opcionais, datas civis, centavos e categorias da API. `ExpenseMetricsBloc`
substitui o command, com estados sealed, falhas tipadas, retry manual e precedência
da consulta mais recente. O módulo fornece instâncias por factory e os previews
consumidores usam BlocBuilder. Dashboard mantém seu próprio Bloc sobre o contrato,
sem migrar os demais contextos financeiros.

A feature Insight foi removida do aplicativo, incluindo módulo, consultas HTTP,
seção da Dashboard, previews e testes próprios. Referências nas verificações
históricas abaixo não representam funcionalidade disponível.

Expense também usa contrato em application, `ExpenseException` e repository em
infrastructure com HTTP direto, sem Either ou data source. Preserva CRUD JSON:API,
centavos inteiros positivos, datas civis, filtros e paginação opaca. Consulta,
criação e atualização retornam entidades; exclusão retorna `Future<void>` e só
conclui após HTTP 204. `AmountValueObject.create` retorna o valor diretamente e
rejeita centavos não positivos com `ArgumentError`. Parsing e falhas inesperadas
propagam. `ExpenseBloc` substitui consulta/criação/edição e `ExpensesBloc` substitui
listagem/exclusão, com estados sealed, factories estáveis e lifecycle das telas.
Mantém validação, erros 422 por campo, retry manual, cadastro contínuo por hold,
filtros, paginação opaca e confirmação de exclusão sem remoção otimista. Consultas
obsoletas não sobrescrevem filtros recentes; mutações pendentes bloqueiam duplicatas.
Listagem navega diretamente pelo `BuildContext`, sem callbacks nos argumentos de
rota; Dashboard e métricas recarregam ao retornar da listagem, mesmo sem alteração.
Expense não depende mais de CommandIt. Dashboard consome resultados diretos de
todos os contextos consultados.

No novo gasto, Descrição oferece autocomplete remoto com `RawAutocomplete` nativo
e o mesmo `TextFieldWidget` do core. A busca começa em 3 caracteres, após 300 ms;
respostas antigas são ignoradas e falhas não bloqueiam cadastro manual. Selecionar
preenche a descrição e o valor opcional; valores confirmados manualmente são
preservados, com ação explícita para usar o sugerido. A data não muda e selecionar
não salva nem configura recorrência. Edição não consulta sugestões.

Os testes de responses cobrem DTOs e exceções HTTP atuais, sem `Either` ou
`response<T>`. Messaging expõe `register()` e `onRegistered` com stream de FIDs,
sem usar as APIs depreciadas de token.
Todos os destinos de `RouteEnum` estão registrados em `app_module.dart`, incluindo
Dashboard, Settings, User e Expense. Testes de composição verificam as rotas e a
resolução das dependências sem visitar módulos irmãos. Authentication e Expense
usam um único módulo sem path por feature, com URLs completas e binds root-owned;
isso elimina a colisão no escopo `/` e disponibiliza o contrato para logout.

Verificação após remover Insight: `flutter pub get` concluído e `flutter analyze`
sem problemas. O lote de arquitetura, Dashboard, composição global e
SessionInterceptor passou com **80 testes**. A suíte global repetida terminou
com **939 aprovados e uma falha preexistente** em
`expense_screen_test.dart:319` (`manual amount survives suggestion until explicit replacement`),
que não encontrou `Usar descrição`. O catálogo de previews compilou e serviu,
mas encerrou por timeout sem cliente conectado; não houve validação visual ou E2E.

Verificação histórica anterior à remoção de integrações remotas e Insight:
**`flutter analyze` sem problemas; `flutter test`
com 1006 aprovados, sem falhas**, incluindo arquitetura, core, Expense e composição
real. Build iOS de debug para simulador aprovado com API de fixtures isolada.
Os quatro flows de sugestões passaram no iPhone 17 Pro / iOS 26.5: descrição e
valor, descrição sem valor, falha com cadastro manual e loading não bloqueante.
Android e backend real não foram exercitados. O catálogo de previews compilou e
serviu; a execução foi encerrada por timeout sem cliente conectado, sem validação
visual do catálogo.
Os detalhes estão em [Estado atual e migração](ARCHITECTURE.md#estado-atual-e-migração).

O código existente inclui os seguintes fluxos, cuja disponibilidade depende da
conclusão da migração e da composição dos módulos:

- Boas-vindas e decisão inicial pela presença do token.
- Entrada/cadastro com e-mail e senha, confirmação por link e reenvio com cooldown.
- Perfil, edição do nome, avatar gerado com salvamento após dois segundos e
  exclusão da conta.
- Criação/edição de despesas, valor em centavos, data civil e cadastro contínuo
  por hold; listagem paginada com filtros de período/categoria e gestos de edição/exclusão.
- Dashboard mensal com métricas por categoria e seis despesas recentes.
- Configurações e logout com revogação remota antes de limpar o storage.
- Tema claro/escuro, componentes compartilhados e previews.

`budget` e `family` são planejados, sem features Flutter implementadas.
`identity` não reproduz o backend legado; `chat` está fora do escopo.
O backend PocketBase tem schema e migrations neste repositório, em `backend/`.
As descrições dos fluxos Flutter acima não comprovam suporte pelo novo backend.

## Stack

- Flutter com Dart `^3.13.2` e primary constructors.
- `bloc`, `flutter_bloc` e `bloc_concurrency` para apresentação assíncrona.
- `flutter_modular` 7 para composição, DI e rotas.
- Material 3 via `material_ui`, fonte Inter e localização pt-BR.
- Dio para HTTP JSON:API e `flutter_secure_storage` para persistência segura.
- Notificações locais com `flutter_local_notifications`.
- `flutter_test`, `bloc_test`, `mocktail` e Maestro para testes.

## Desenvolvimento

Na raiz do projeto:

```bash
flutter pub get
flutter analyze
flutter test
```

Os comandos podem expor os bloqueios de migração descritos acima. Não restaure
dependências antigas ou silencie checks para aparentar compatibilidade.

Após resolver os bloqueios de compilação e composição, execute em Android/iOS:

```bash
flutter run
```

A API padrão **do cliente ainda não migrado** é `https://app.cordato.cloud/api/`.
Para outra base compatível com esse contrato:

```bash
flutter run --dart-define=BASE_URL=https://api.exemplo.com/api/
```

Preserve o prefixo `/api/`. `BASE_URL` é definido no build; reinicie o app após
alterá-lo. Confira também os overrides de `.vscode/launch.json`.

### Backend Local

Consulte [`backend/README.md`](backend/README.md) para configuração e verificação
isoladas do PocketBase. O Compose atual depende da rede externa do Dokploy; não
é uma configuração local pronta para conectar o Flutter.

O `Makefile` e `tool/android_usb_proxy.py` do ambiente PHP anterior foram removidos.
Não use as instruções antigas de Lerd/mkcert como setup do PocketBase. Até a
migração do cliente, os E2E Flutter usam as APIs de fixtures isoladas descritas
nos READMEs de cada fluxo, não o novo backend nem produção.

### Previews

```bash
dart run tool/widget_preview.dart
```

Abra a URL impressa. O launcher contorna a descoberta inicial vazia do previewer
no Flutter 3.47.6/3.47.7; se necessário, atualize o painel após a análise inicial.
Previews usam o tema real, pt-BR e fakes locais, sem rede/storage. Não substituem
testes de contrato ou E2E. `.widget_preview/` não deve ser versionado.
Preserve um único proprietário de recursos: Sign-in recebe um Bloc externo;
as telas ainda não migradas continuam criando/fechando sua factory. Use
`PreviewResourceWidget` para um recurso externo ao lifecycle da tela.

### Modular V7 E Navegação

- Estado de página novo ou explicitamente migrado usa `provide` e a extension
  `BlocScopedExtension`, em `core/presentation/extensions/bloc_scoped_extension.dart`.
  O Modular cria e fecha o Bloc; a screen recebe a instância e mantém `flutter_bloc`.
- Apenas Sign-in foi migrado para esse ownership. Session permanece global sob
  `AppWidget`; os demais fluxos de tela ainda possuem factories locais.
- Contratos compartilhados entre features precisam de módulos sem `path`.
  Módulos com `path` ativam seus binds apenas enquanto a feature está em uso.
- Authentication e Expense mantêm um módulo por feature, sem `path` e sem
  fragmentação dependencies/form/list. Não use `path: '/'` em módulos irmãos;
  os binds colidem. Blocs registrados com `add` continuam factories, não singletons.
- Widgets/mixins navegam pelo próprio `BuildContext`; argumentos de rota levam
  dados, não callbacks. Edição devolve a entidade confirmada pelo resultado tipado.
- Ao retornar da listagem, Dashboard e Metrics recarregam mesmo sem alteração;
  o retorno do cadastro continua condicionado à entidade confirmada.

Consulte [composição e rotas](ARCHITECTURE.md#composição-rotas-e-bootstrap) para
o exemplo de `provide`, ownership, estado de migração e limites de DI.

## Testes

| Camada | Padrão |
| --- | --- |
| Domain/application | Regras puras e exceções, sem SDKs. |
| Infrastructure/repository | Mocks dos clients; payload, parsing, erros e persistência. |
| Bloc | Repository mockado; estados, concorrência, retry e fechamento. |
| Screen/widget | Bloc real com repository mockado; interação, feedback e lifecycle. |
| E2E | Maestro com fixture HTTP isolada, cobrindo Success, Failure e Loading. |
| Architecture | Imports, fronteiras de contextos e direção das dependências. |

Testes espelham os caminhos de `lib/`; doubles públicos ficam em arquivos
próprios de `test/support/`, sem classes auxiliares nos arquivos `*_test.dart`.

```bash
flutter test test/architecture
flutter test test/features/authentication/infrastructure/repositories
flutter test test/features/authentication/presentation/screens/sign_in/bloc
flutter test test/features/authentication/presentation/screens/sign_in/sign_in_screen_test.dart
flutter test test/features/authentication/authentication_sign_in_module_test.dart
flutter test test/app_module_test.dart
flutter test test/features/authentication/presentation/screens/sign_up
flutter test test/features/authentication/presentation/screens/resend_email
flutter test test/features/authentication/presentation/screens/callback test/features/authentication/authentication_callback_module_test.dart
flutter test test/features/settings
flutter test test/features/session test/features/root
flutter test test/features/user
flutter test test/architecture test/features/metrics
flutter test test/architecture test/features/expense test/features/dashboard test/features/metrics test/features/core/infrastructure/clients/http/interceptors/session_interceptor_test.dart
```

Os flows Maestro estão em
[`test/features/authentication/presentation/screens/sign_in/e2e/`](test/features/authentication/presentation/screens/sign_in/e2e/README.md).
Seu README descreve fixture, encaminhamento de porta e execução sequencial.
Não execute contra produção: usam dados fictícios e limpam dados/keychain do app.
Os flows de cadastro estão em
[`sign_up/e2e/`](test/features/authentication/presentation/screens/sign_up/e2e/README.md),
com fixture própria na porta 8766; ainda não foram executados em dispositivo.
Os flows de
[`resend_email/e2e/`](test/features/authentication/presentation/screens/resend_email/e2e/README.md)
usam fixture na porta 8767, aguardam o cooldown real e também não foram executados
em dispositivo.

### Histórico De Migrações E Verificações

Os números e bloqueios abaixo registram etapas anteriores; não descrevem o
checkout atual. O resultado vigente está em **Estado do projeto** e a referência
de implementação é `ARCHITECTURE.md`, não os comandos/rotas históricos.

Na migração de reenvio, Bloc/tela tiveram 23 testes novos aprovados; o lote focado
de arquitetura, Authentication, Settings, Session, Root e storage tem 250 testes aprovados. A análise focada está
limpa, mas análise/suíte globais continuam bloqueadas pelo legado.

O [E2E de callback](test/features/authentication/presentation/screens/callback/e2e/README.md)
usa fixture na porta 8768 e inclui sucesso, link inválido, falha e loading,
ainda sem execução em dispositivo. Callback tem 29 testes novos de Bloc, tela,
DI e rotas aprovados; eles não substituem a validação de deep links nativos.

O [E2E de logout](test/features/settings/presentation/screens/settings/e2e/README.md)
usa fixture local na porta 8769 e cobre confirmação, revogação, falha e loading.
Não foi executado em dispositivo. Os 23 testes novos de Settings/Logout incluem
Bloc, tela e módulo com repository real sobre clients mockados, verificando
que a conclusão aguarda a revogação e a limpeza do storage.

Session/Root têm 49 testes novos aprovados, incluindo o ciclo de sign-in/token/
logout com repositories e Blocs reais sobre clients mockados. Os
[flows de Session/Root](test/features/root/presentation/screens/app/e2e/README.md)
reutilizam a fixture de logout na porta 8769 e ainda não foram executados em
dispositivo. A suíte do SessionInterceptor voltou a passar após migrar o repository
de Expense; a suíte global ainda não está aprovada.
Dependem de build compilável e módulos de sessão/destinos ativos; sua existência
não significa validação em dispositivo. Não há suíte Flutter `integration_test`.

O lote focado de arquitetura, Authentication, Settings, Session, Root, User e das
camadas migradas de Metrics passou com 456 testes. A análise focada está limpa.
Após substituir o command, `flutter test test/architecture test/features/metrics`
passou com 106 testes, incluindo Bloc e módulo. A análise focada de Metrics e dos
dois previews consumidores estava limpa. A Dashboard foi desbloqueada na primeira
rodada de Expense; não houve execução visual de previews ou E2E.
Os flows de [perfil](test/features/user/presentation/screens/user/e2e/README.md)
e [edição de nome](test/features/user/presentation/screens/edit/e2e/README.md) usam
a fixture local na porta 8770 e estão preparados, não executados em dispositivo.
Análise e suíte globais permanecem bloqueadas pelo legado.

Na primeira rodada de Insight, arquitetura, Metrics e as camadas migradas de
Insight passaram com 134 testes, incluindo 28 de Insight. A análise focada dessas
camadas estava limpa; módulo/command e Dashboard estavam bloqueados pelo legado.
Após substituir o command, `flutter test test/architecture test/features/metrics
test/features/insight` passou com 152 testes, incluindo 17 de InsightsBloc e o teste
de módulo anteriormente bloqueado. A análise de toda a feature e seus testes está
limpa nessa rodada. A análise e a suíte globais continuam falhando no legado;
a dependência de Either da Dashboard foi removida na rodada de Expense.

Na primeira rodada de Expense, o lote focado de arquitetura, camadas migradas de
Expense, validators, DashboardBloc, Metrics, Insight e SessionInterceptor passou
com 380 testes. A análise focada dessas camadas e consumidores está limpa.
Na segunda rodada, os cinco commands de Expense foram removidos. Testes de Bloc,
tela, DI e rotas verificam sucesso/falha, concorrência, descarte, paginação e retorno
da edição com a entidade confirmada por HTTP. Os flows de
[criação](test/features/expense/presentation/screens/expense/e2e/README.md) e
[listagem/exclusão](test/features/expense/presentation/screens/expenses/e2e/README.md)
usam fixture isolada na porta 8771; não foram executados em dispositivo.
As rotas globais não foram reativadas. Análise/suíte globais seguem bloqueadas por
testes antigos de responses/CommandIt, referência inexistente a
`userDependenciesModule` e expectativas dos testes de HeadersInterceptor.

Verificação da segunda rodada de Expense:

- `flutter pub get`: concluído, sem restaurar dependências legadas.
- `flutter analyze lib/features/expense test/features/expense test/architecture/expense_presentation_test.dart`:
  sem issues.
- O comando focado acima de arquitetura, Expense, Dashboard, Metrics, Insight e
  SessionInterceptor passou com **435 testes**.
- `flutter analyze` e `flutter test`: executados, ainda falham nos bloqueios fora
  de Expense descritos acima; a análise também aponta deprecações Firebase e um
  import não usado em Insight, sem alteração incidental dessas áreas.
- `dart run tool/widget_preview.dart`: servidor iniciado e encerrado sem abrir
  navegador; não houve validação visual dos previews.
- Smoke HTTP da fixture local: autorização, consulta, criação, edição, exclusão e
  estatísticas aprovados; isso não é execução Maestro em dispositivo.

Após remover os callbacks de navegação de `ExpenseScreen` e `ExpenseFormWidget`,
voltar e sucesso usam diretamente as extensões de `BuildContext` nos widgets.
A edição devolve a entidade confirmada; a criação preserva `returnToPrevious` e
o cadastro contínuo não navega.
`flutter analyze lib/features/expense test/features/expense` passou sem issues;
o mesmo lote focado passou com **438 testes**, incluindo navegação real em router.
`flutter analyze` e `flutter test` globais foram repetidos e mantêm os bloqueios
externos listados acima. Não houve execução Maestro nesta alteração.

`onExpensesChanged` também foi removido de `ExpenseScreen`, do formulário e dos
argumentos usados pela Dashboard para criação. A Dashboard aguarda uma despesa
confirmada como resultado da rota; cancelar sem salvar não recarrega os dados.
Após cadastro por hold, voltar pelo botão ou pelo sistema devolve a última despesa
salva mesmo após outra tentativa falha ou ainda pendente, sem flag local espelhando
o resultado do Bloc. Testes de navegação e do botão da Dashboard cobrem esse retorno.
A análise focada de Expense e do consumidor da Dashboard passou sem issues; o
mesmo comando focado de testes passou com **447 testes**. Os bloqueios globais
preexistentes e a ausência de validação Maestro permanecem.

## API, Sessão E Segurança

Esta seção descreve o **código Flutter atual**, não o contrato PocketBase.
As regras e a autenticação do novo serviço estão em
[`backend/README.md`](backend/README.md#coleções).

O repository de Authentication envia JSON:API e persiste token opaco e ID do
usuário por `IStorageClient`, aguardando ambas as escritas antes de concluir.
Não há garantia transacional entre elas. Bloc e UI não recebem token nem DTO.
Falhas esperadas viram `AuthenticationException`; erros inesperados propagam,
e o Bloc fornece fallback seguro e `addError` sem conhecer SDKs de telemetria.

Session observa o token para entrada e redirecionamento global. Não há validação
remota ao abrir, refresh automático ou guard Modular. Um 401 protegido remove
somente o token enviado se ainda for o armazenado, preservando o ID.
Logout aceito remotamente aguarda a limpeza de todo o storage seguro.
Confirmação de e-mail usa o link assinado sem Bearer e não cria sessão.

O logger HTTP debug atual registra dados sensíveis; não use credenciais reais
em capturas compartilhadas. O logger não é instalado em release. Não adicione
segredos ao código ou fixtures. Valores financeiros são centavos inteiros de BRL,
e datas financeiras preservam seus componentes civis, sem conversão de fuso.

## Notificações E Release

Notificações locais possuem client no core. Não há integração de push remoto
ou crash reporting. O bootstrap não depende de configuração de serviços remotos.
O iOS usa Swift Package Manager para os plugins Flutter.

Verificação após remover a integração remota:

- `flutter pub get` e `flutter analyze`: concluídos, sem issues na análise.
- `flutter test`: 988 testes passaram e um falhou em
  `test/features/expense/presentation/screens/expense/expense_screen_test.dart:319`
  (`manual amount survives suggestion until explicit replacement`), por não
  encontrar `Usar descrição`. A repetição isolada reproduziu a falha; o fluxo
  de sugestões não foi alterado nesta remoção.
- `plutil -lint`: projeto Xcode, Info.plist e entitlements válidos.
- `flutter build ios --simulator --debug`: concluído.
- `flutter build apk --debug`: excedeu 120 segundos durante `assembleDebug`,
  sem resultado conclusivo para Android.

Build, assinatura e verificação Android:
[android/README.md](android/README.md).

## Contribuição

Siga [AGENTS.md](AGENTS.md). Migre cada fluxo com contratos, implementação,
Bloc, consumidores, bindings e testes na mesma mudança, sem ampliar o escopo
incidentalmente. Preserve alterações existentes e não faça commit/push sem pedido.
Não adicione comentários ao código; decisões ficam em Markdown.

Mudanças de arquitetura, testes ou estado do produto devem manter estes três
documentos coerentes e registrar limitações reais, sem declarar migrações ou
validações que ainda não ocorreram.
