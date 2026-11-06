# AGENTS.md

## Objetivo E Fonte De Verdade

Estas regras orientam alterações no aplicativo Flutter Cordato e em seus testes.
A arquitetura canônica está em [ARCHITECTURE.md](ARCHITECTURE.md); o início rápido
e o estado do produto estão em [README.md](README.md).

O serviço PocketBase independente está isolado em `backend/`, com orientações
próprias em [backend/AGENTS.md](backend/AGENTS.md). A presença do backend neste
repositório não significa que o aplicativo já consuma sua API. Não migrar o cliente
Flutter nem executar deploy como parte de manutenção localizada do backend.

PocketBase é o backend adotado. Sign-in, cadastro, solicitação e confirmação de verificação
usam os endpoints nativos `collections/users/auth-with-password`,
`collections/users/records`, `collections/users/request-verification` e
`collections/users/confirm-verification`.
Sign-out é local: aguarda `IStorageClient.clear()`, sem endpoint HTTP ou revogação
do JWT no servidor. Falhas do storage propagam e não confirmam sucesso.
Expense usa `collections/expenses/records` para CRUD e sugestões por histórico,
com JSON plano, paginação nativa e `owner` lido do storage somente na criação.
Novas despesas enviam a categoria selecionada pelo valor de `ExpenseCategoryEnum`,
com `other` como padrão quando não informada. Atualizações enviam categoria somente
quando fornecida, inclusive `other`, sem alterar o proprietário. A data civil é
representada como
meia-noite UTC sem conversão de fuso; filtros finais incluem todo o dia escolhido.
Sugestões consultam até 30 registros recentes e deduplicam descrições sem
diferenciar maiúsculas/minúsculas, sem endpoint customizado ou classificação.
Sugestões incluem a categoria tipada do registro mais recente para cada descrição;
aceitar uma sugestão aplica essa categoria no formulário, inclusive `other`,
preservando a data e o valor manual. A projeção consulta `id,description,amount,category`.
Não há migração de registros existentes nem fallback para categoria/data vazias.
Metrics consulta `collections/metrics/records`, uma view mensal
somente leitura com isolamento por proprietário. Totais em centavos e percentuais
são calculados no PocketBase, nunca no Flutter. O repository aceita meses civis
completos; sem datas usa o mês atual, mas rejeita intervalo parcial/incompleto.
Lista vazia representa mês sem despesas; resposta inválida ou falha HTTP não
vira sucesso com zero. UI, contratos de apresentação e navegação ficam preservados.
User também usa `collections/users/records/{id}` para consulta, PATCH com JSON
plano de nome/avatar e exclusão. Não há `status` em `UserEntity`; não o derive
de `verified`. Nome vazio é exibido como `Cordato` somente na apresentação.
Edição valida 2–32 caracteres Unicode após trim e mapeia erros 400 de `/name`
ao campo. Avatar vazio do PocketBase vira ausência de seed em infrastructure.
O JWT usa `StorageKeyEnum.token` (`@trocado.token`), sem migração automática das
sessões das chaves anteriores. Cadastro não cria sessão. Após criar a conta, a
tela de confirmação solicita automaticamente o primeiro e-mail de verificação.
Falha de envio não refaz o cadastro e permite reenvio manual imediato.
O cooldown de 60 segundos pertence ao ResendEmailBloc e começa somente após sucesso.
Callback recebe exatamente um `token` na query, nunca uma URL remota para GET.
Token de verificação não pertence ao estado do Bloc nem aos logs.
Recuperação de senha usa `collections/users/request-password-reset` e
`collections/users/confirm-password-reset`, públicos e com sucesso HTTP 204.
A confirmação do envio é neutra quanto à existência da conta. `EmailCooldown`
compartilha os 60 segundos com a verificação, iniciados somente após sucesso.
As duas etapas de solicitação compartilham o Bloc da rota. O callback de reset
recebe exatamente um token não vazio na query e aguarda `signOut()` antes de
habilitar o formulário; falha de storage bloqueia a ação. Senha segue as regras
do cadastro e a confirmação deve coincidir. Token e senhas não ficam nos estados
nem nos logs. O logger omite operações de reset e URLs com token. Sucesso e erro
400 em `/token` voltam ao sign-in com toast; falhas de rede e de campos preservam
a tela. Os novos Blocs de recuperação pertencem exclusivamente ao `provide` das
rotas; screens e previews recebem instâncias com proprietário externo explícito.
Senha usa regra única no app: 6–16 code points Unicode, com minúscula ASCII,
maiúscula ASCII e número ASCII, sem trim/normalização; espaços contam no limite.
Cadastro, sign-in, recuperação e troca usam `PasswordValidation` compartilhado.
Dados pessoais abre `/authentication/change-password`, rota autenticada com
`ChangePasswordBloc` pertencente exclusivamente ao `provide`. Authentication possui
o fluxo e o contrato `changePassword(oldPassword:, password:, passwordConfirm:)`;
User somente navega, sem importar sua apresentação. Senha atual é obrigatória,
mas não passa pela política de criação. Nova senha deve diferir exatamente da
atual; confirmação deve coincidir. PATCH nativo de users envia somente os três
campos, lê ID do storage, exige HTTP 200 e não faz logout internamente.
Após confirmação remota, o Bloc aguarda `signOut`; falha de limpeza permite
somente retry de logout, nunca novo PATCH. Controllers são limpos após o PATCH.
Sucesso leva ao sign-in com “Senha alterada. Entre novamente”. A composição root
possui `SessionRedirectDeferral`, não global, exposto por inherited widget do core:
a tela adia redirecionamentos somente da própria rota enquanto a operação está
pendente e libera ao falhar o PATCH, concluir a navegação ou ser descartada.
Authentication e Session continuam sem importar uma à outra. O logger omite
request/response/error de payloads com `oldPassword`, `password` ou
`passwordConfirm`, além dos filtros existentes de reset/token.
Descrições JSON:API e token opaco neste
documento referem-se aos fluxos Flutter não migrados, não a requisitos para recriar a API antiga
no PocketBase. Não trate troca de `BASE_URL` como integração. Diferenças e lacunas
estão em [ARCHITECTURE.md](ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração);
alterações de contrato exigem tarefa explícita com consumidores e testes.

Authentication/Sign-in é a implementação de referência para novas features e
migrações. O padrão obrigatório é:

```text
Screen/Widget -> Bloc -> contrato de repository em application
                           ^
                repository em infrastructure -> clients do core -> SDKs
```

O Bloc chama o contrato; o módulo injeta a implementação. Contratos retornam
dados por `Future<T>` e falhas esperadas por exceções de aplicação. Não use
`Either`, `Left`/`Right`, `response<T>`, CommandIt ou data sources como padrão
para código novo ou para um fluxo migrado.

Há código legado incompatível com esse desenho. Sua existência não constitui
uma exceção arquitetural aprovada. Não descreva a migração como concluída e não
amplie uma tarefa localizada para migrar o restante do aplicativo sem solicitação.
Specs OpenSpec arquivadas e registros de execução são históricos. Em conflitos,
prevalecem estas regras e `ARCHITECTURE.md`; consulte `openspec/README.md`.
Não restaure Supabase/RPC, commands ou ownership antigo por uma descrição histórica.

## Antes De Alterar

- Leia a feature afetada, os componentes compartilhados usados e seus testes.
- Confira `git status` e preserve alterações existentes, inclusive fora do escopo.
- Faça a menor alteração que satisfaça a tarefa; não reformate áreas não relacionadas.
- Não faça commit, push, reset ou exclusões destrutivas sem solicitação explícita.
- Atualize contratos, consumidores, bindings e testes na mesma mudança.
- Registre bloqueios reais de análise, compilação e testes, sem ocultá-los.
- Não adicione comentários de linha, bloco ou documentação ao código. Explicações
  ficam em Markdown; preserve comentários existentes fora do escopo.

## Produto E Limites

Cordato é um aplicativo de finanças pessoais e familiares. Cada pessoa é dona
dos próprios dados; família é uma lente autorizada de leitura, não dona do dinheiro.

| Feature/contexto | Responsabilidade                                                                 |
| ---------------- | -------------------------------------------------------------------------------- |
| `authentication` | Entrada, cadastro, confirmação de e-mail, reenvio e logout.                      |
| `session`        | Validação inicial via auth-refresh e observação da presença do token.            |
| `user`           | Dados pessoais, nome, avatar e exclusão da conta.                                |
| `expense`        | Fatos atômicos de gastos individuais.                                            |
| `metrics`        | Agregações financeiras somente leitura.                                          |
| `budget`         | Planejado: tetos por intervalo de datas.                                         |
| `family`         | Planejado: organização de membros e leitura combinada.                           |
| `dashboard`      | Apresentação e composição, não um bounded context financeiro.                    |
| `root`           | Composição visual global e entrada do app.                                       |
| `information`    | Termos, privacidade e ajuda públicos, com conteúdo local e sem camadas de dados. |

Não crie `identity` para reproduzir o backend legado. `chat` está fora do escopo.
O Kotlin legado é referência de domínio, não de estrutura Flutter.

Preserve as invariantes:

- Dinheiro em centavos inteiros de BRL; nunca use `double` para valores monetários.
- Gasto não referencia orçamento; pertencimento é derivado da data civil.
- Orçamentos vivos da mesma pessoa não podem se sobrepor.
- Família não concede escrita nos dados de outro membro.
- Sair ou encerrar família não altera os dados individuais.
- Visões combinadas são derivadas dos dados proprietários.
- Não apresente autorização do backend como garantia implementada pelo Flutter.

## Camadas E Arquivos

```text
lib/features/<feature>/
  <feature>_module.dart
  domain/
    entities/
    enums/
    value_objects/
  application/
    exceptions/
    repositories/interface_<feature>_repository.dart
  infrastructure/
    repositories/<feature>_repository.dart
    responses/
  presentation/
    screens/<screen>/
      <screen>_screen.dart
      bloc/
      mixins/
      widgets/
    validators/
    widgets/
    previews/
```

Crie somente diretórios necessários. Features exclusivamente visuais não precisam
de domínio ou repository. Não adicione use cases, inputs, outputs, services,
data sources, BaseBloc ou stores globais sem necessidade concreta aprovada.

- `domain`: tipos e regras puros, sem Flutter, Bloc, HTTP, storage ou application.
- `application`: contratos de operações e exceções esperadas, sem adapters ou UI.
  Contratos de repository ficam aqui, não em `domain/repositories/`.
- `infrastructure`: implementa os contratos e coordena HTTP, DTOs e persistência
  usando interfaces de clients do core. Não importe Dio no repository da feature.
- `presentation`: Bloc, estados, eventos, telas, validação e feedback. Conhece
  contratos e exceções de aplicação, nunca repositories concretos ou clients.
- Módulos fazem a composição e podem importar implementações concretas.
- `core` contém capacidades realmente compartilhadas; não mova regras de uma
  feature para ele apenas para contornar um limite de dependência.

Authentication e Session não importam uma à outra; comunicam-se pela chave de
token do storage. Expense e Budget não dependem de outros contextos financeiros.
Settings possui o Bloc da interação de logout e consome somente contrato e exceção
de aplicação de Authentication, nunca sua apresentação ou repository concreto.
Family deve consultar contextos proprietários por contratos próprios
com adapters em infrastructure, sem dependência reversa. Dashboard pode compor
contratos de aplicação dos contextos que consulta.

A feature Insight foi removida, incluindo composição, consulta remota, seção da
Dashboard, previews e testes próprios. Não restaurá-la a partir de specs históricas.

## Repositories, HTTP E Falhas

- Use parâmetros nomeados e tipos simples quando suficientes. Repository e Bloc
  não normalizam entradas que pertencem ao formulário.
- Retorne `Future<void>` quando o consumidor precisa somente da conclusão;
  não exponha token, DTO ou envelope JSON:API à apresentação.
- Parsing e montagem de payload pertencem a infrastructure. DTOs usam Dart puro
  e casts; não esconda `TypeError` ou `FormatException` como falhas de negócio.
- Repository chama `IHttpClient` e `IStorageClient` diretamente quando necessário,
  sem camadas de data source intermediárias para delegação simples.
- Trate `HttpResponseException` antes de `HttpClientException`: preserve os erros
  remotos convertidos para `ErrorsEntity`; use fallback nas demais falhas do client.
- Lance exceção específica de aplicação, como `AuthenticationException`.
  Não introduza `catch` genérico no repository para mascarar erros inesperados.
- Preserve ordem e metadados dos erros, incluindo `pointer` e `parameter`.
  Não converta exceções inesperadas ou falhas de storage em sucesso.
- Não exiba `title` ou `detail` remotos diretamente em campos, toasts ou telas.
  A apresentação usa mensagens locais em português, mapeadas por status, código,
  campo e contexto da operação, com fallback seguro. `ErrorMessageFormatter`
  contém somente mensagens compartilhadas; regras de campos pertencem aos
  formatadores de cada feature. Preserve o `ErrorsEntity` original nos contratos
  e estados. Testes de formatadores são unitários, sem montar UI.
- Aguarde toda persistência exigida antes de concluir. Sign-in aguarda token e ID
  por `Future.wait`; isso não garante transação ou rollback entre as gravações.
- Requests usa somente `path`, `body`, `query` e `headers`; endpoints relativos
  preservam `/api/`. Headers e Bearer pertencem aos interceptors.
- Não coloque credenciais, tokens ou segredos no código, fixtures reais ou logs novos.

## Bloc E Estado De Tela

- Use Bloc para operações assíncronas e estado de execução da apresentação.
  Não introduza commands nos fluxos novos ou migrados.
- Organize eventos e estados em `screens/<screen>/bloc/`, junto ao Bloc.
- Prefira eventos concretos e estados sealed, imutáveis, mutuamente exclusivos,
  como `SignInInitial`, `SignInSubmitting`, `SignInSuccess` e `SignInFailure`.
- Derive disponibilidade de ações do estado (`canSubmit`, `isSubmitting`);
  não mantenha flags locais espelhando loading, resultado ou erro do Bloc.
- Não armazene senha, token ou credenciais no estado. O evento de submissão pode
  transportar a entrada somente pelo tempo necessário à operação.
- Defina concorrência explicitamente. Submissões como sign-in usam `droppable`:
  eventos durante envio são descartados, não enfileirados; sucesso bloqueia
  novos envios e falha permite retry manual, sem retry automático.
- Falha esperada preserva a mesma `ErrorsEntity` no estado. Falha inesperada
  usa fallback seguro e `addError(error, stackTrace)`; não injete CrashClient
  ou callback de telemetry no Bloc.
- Antes de publicar após `await`, respeite `isClosed` e `emit.isDone`.
  Fechar Bloc ou invalidar handler não cancela HTTP nem persistência.
- Use o lifecycle nativo do Bloc, sem flags paralelas ou override de `close()`
  para reproduzir o fechamento da biblioteca.

## Screens, Formulários E Lifecycle

- Sign-in usa o escopo de página do Modular V7: registre o Bloc somente no
  `provide` da rota com `scope.addBloc<SignInBloc>(SignInBloc.new)`, usando a
  extension do core. A screen recebe a instância e não cria nem fecha o Bloc;
  Modular é o único dono do fechamento. Mantenha `BlocBuilder`/`BlocConsumer`
  e listeners com a instância explícita. Testes/previews fornecem um proprietário
  externo explícito. Não duplique o bind do Bloc no módulo.
- Os demais fluxos ainda não migrados recebem uma factory estável
  `Bloc Function()` por construtor, criam a instância e possuem seu fechamento.
  Não converta essas telas incidentalmente: migre rota, consumidores, previews
  e testes juntos quando a tarefa incluir a adoção do escopo Modular.
- `ExpenseSuggestionsBloc` também usa `provide` e `addBloc` na rota de Expense;
  screen/formulário recebem a instância e não a fecham. Isso não migra o
  `ExpenseBloc`, que continua com factory estável e ownership pela screen.
- Para os fluxos com ownership pela screen, crie em `initState`, feche em
  `dispose` e feche/substitua em `didUpdateWidget`
  somente quando a factory mudar. Rebuild comum não cria outro Bloc.
- Use `BlocBuilder` para renderização e `BlocListener`/`BlocConsumer` para efeitos
  únicos. Não mostre toast, navegue ou envie operações durante o build.
- Se usar `BlocProvider.value`, a propriedade do fechamento continua com a screen.
- Session é uma observação contínua com proprietário no nível da composição:
  `AppWidget` recebe a factory estável, inicia e fecha seu único SessionBloc.
  `AppScreen` é apenas visual; não cria, compartilha por singleton ou fecha outro
  Bloc. A leitura inicial não sobrescreve eventos de token/watch mais recentes;
  falha de storage não é ausência confirmada nem deve apagar o token.
- Session usa `IHttpClient` e `IStorageClient` em infrastructure para validar o
  token inicial por `collections/users/auth-refresh`. Sem token não há HTTP.
  Chamadas simultâneas compartilham a operação; não há retry automático.
  Resposta válida persiste ID e token antes de concluir. Erros HTTP esperados
  preservam `ErrorsEntity` em `SessionException`/`SessionFailure`; 403 ou falha de
  rede não apagam storage. O interceptor invalida somente o token enviado em 401.
  Respostas de refresh não devem sobrescrever um token mais recente observado
  antes da persistência. As gravações e a comparação do storage não são atômicas.
- Interceptor reconhece somente os endpoints protegidos conhecidos, relativos à
  mesma origem/base: auth-refresh, records de users/expenses e listagem da view
  metrics, além do legado
  ainda consumido. POST de cadastro em users/records permanece público; não
  autentique genericamente qualquer coleção nem faça refresh/retry no interceptor.
- Formulário mantém entrada, validação e erros por campo localmente. No sign-in,
  o validator remove espaços do e-mail, mas preserva a senha; Bloc e repository
  delegam os valores recebidos sem outra normalização.
- Quando `next` leva a outro campo de texto, a ação aponta explicitamente ao
  `FocusNode` desse campo por `onEditingComplete`, sem depender da ordem
  automática que também inclui botões auxiliares. O mixin do formulário possui
  e descarta esses nós; ações finais preservam a submissão existente.
- Desabilite campos e envio conforme o estado. No sign-in, mapeie erros PocketBase
  400 pelos pointers `/identity` (e-mail) e `/password`, preservando `code` e
  `parameter` na conversão HTTP. Erros 422 legados conhecidos por pointer continuam
  aceitos. Mostre somente os restantes em toast, com fallback seguro.
- No cadastro, erros PocketBase 400 com `/email` vão ao e-mail e `/password` ou
  `/passwordConfirm` à senha; preserve os erros 409/422 legados conhecidos.
- Preserve entrada após falha; editar limpa somente o erro do campo correspondente.
- No sign-in, sucesso não navega diretamente: a observação global da sessão
  continua responsável pelo redirecionamento.
- Ações de navegação novas usam as extensões de `BuildContext` do Modular no
  widget responsável, não callbacks transportados pela rota nem `Modular.to`.
  Preserve callbacks legados até migrar seus consumidores explicitamente.

Extraia lifecycle, controllers, timers e handlers substanciais para mixin
específico com `on State<Widget>`. A screen mantém composição visual. O mixin
não acessa repository, HTTP ou storage e descarta todo recurso que cria.
Helpers usam o `context` do próprio State, sem repasse redundante.
Lógica visual pura de StatelessWidget pode usar mixin próprio com
`on StatelessWidget`, sem recursos mutáveis ou operações assíncronas.

## Dart, Imports E Componentes

Strings nativas Android usam `<tipo>_<contexto>_<descricao>` em `snake_case`
inglês, separadas em `res/values/strings_<contexto>.xml`; `strings.xml` pertence
ao contexto `app`. Os prefixos são `failure_`, `success_`, `label_`, `action_`,
`cd_`, `msg_` e `config_`, conforme `android/README.md`. Não misture strings com
cores e estilos; agrupe tipos por linhas em branco, sem comentários no código.
Configurações técnicas usam `translatable="false"`. Renomeações atualizam XML,
Kotlin e testes de referências/app links na mesma mudança, preservando URLs e
placeholders posicionais.

### Legibilidade E Coesão

- Use nomes que expressem o significado do dado ou da operação. É proibido nomear
  variáveis, parâmetros, campos ou getters como `result`, inclusive em testes,
  previews e ferramentas. Prefira nomes como `passwordCheck`, `createdExpense`
  ou `confirmedDate`; não substitua por outro nome genérico sem significado.
- Métodos devem ter uma responsabilidade identificável. Separe validação,
  atualização de erros de campo, envio de eventos, feedback e navegação quando
  estiverem misturados em um handler extenso. O método coordenador deve deixar
  explícita a sequência da operação, sem esconder efeitos em getters.
- Separe etapas lógicas por linhas em branco. Use blocos com chaves em `if`,
  `else` e laços; não comprima guarda e ação na mesma linha.
- Prefira guard clauses para pré-condições e `switch` com pattern matching para
  estados ou alternativas mutuamente exclusivas. Evite cascatas de `if/else`
  e ternários aninhados; um `if` simples ou ternário simples continua permitido.
- Formatação e classificação de erros remotos pertencem a formatters puros da
  feature, com testes unitários, não a handlers de tela ou callbacks de build.
- Estados visuais alternativos não devem formar árvores de ternários. Use seleção
  explícita por estado e extraia blocos visuais substanciais em widgets públicos
  em arquivos próprios, preservando ownership, foco, controllers e acessibilidade.
- Não crie services, stores, flags espelhadas, hierarquias de mixins ou helpers
  genéricos apenas para reduzir linhas. Extrações precisam reduzir acoplamento
  ou nomear uma responsabilidade real, mantendo o comportamento e seus testes.
- Estas regras valem para todo o projeto. Ao alterar um fluxo, revise também seus
  consumidores; não mova complexidade para outro arquivo nem enfraqueça testes
  para apenas aparentar conformidade.

- SDK Dart `^3.13.2`; use primary constructors em declarações novas elegíveis.
  Campos induzidos imutáveis têm tipo explícito e `final`; preserve `const`.
- Parâmetros usados só para inicialização não induzem campos. Construtores com
  lifecycle ou múltiplos caminhos generativos exigem avaliação semântica.
- Não introduza construtor primary vazio em interfaces, mixins, States ou mocks.
- Widgets novos são públicos, `final`, com sufixo `Widget`, arquivo próprio,
  parâmetros nomeados, `required` e `super.key`; use `const` quando possível.
- Não extraia componentes visuais privados dentro do arquivo de outra tela.
- Imports da aplicação usam `package:cordato/`, nunca caminhos relativos de `lib/`.
- UI Material usa `package:material_ui/material_ui.dart`, não
  `package:flutter/material.dart`. Imports Flutter especializados são permitidos
  para símbolos não exportados. Remova imports não utilizados; não crie barrels.
- Reutilize botões, fields, `BounceWidget`, animações e imagens do core antes
  de criar componentes. Botões compartilhados incorporam o bounce de pressão.
- Ícones explícitos usam `Icons` e `IconData` do Material pelo `IconWidget`
  estático do core. Não adicione bibliotecas, controllers, scopes ou listeners
  para animar ícones. Preserve semântica, cores do tema e estado desabilitado.
- Use `context.colors`, `context.typography` e `context.radius`; não duplique
  extensões ou tokens. Scaffold herda o tema; não fixe fundo sem necessidade.
- Assets ficam em `AssetEnum` e `pubspec.yaml`; use `ImageWidget` para imagens.
- Reutilize `ErrorScreen` para erro de tela; preserve acessibilidade, rolagem,
  textos ampliados e exclusão semântica de imagens decorativas e skeletons.

## Módulos E Rotas

O widget externo de cadastro usa `home_widget` por `IHomeWidgetClient`, contrato
em `core/application/clients/`, com adapter em infrastructure. Esse client não
entra em widgets/mixins/Blocs: Root usa `HomeWidgetLaunchBloc` →
`IHomeWidgetLaunchRepository` para leitura inicial e observação de lançamentos;
o repository filtra URIs nativas antes de expor sinais à apresentação. AppWidget
recebe factories de Blocs, nunca o client nem streams nativos. Root possui o
intent pendente e aguarda Session antes de abrir Dashboard → Nova despesa.
Não importe o plugin na apresentação, não compartilhe JWT com o widget
e não faça cadastro em background. Preserve criações abertas sem confundir edição
por ID. No Modular 7, `routeState` representa a base e `Page.name` não identifica
as rotas empilhadas; use os estados reais de `popUntil` na coordenação do atalho.

O resumo mensal do widget usa somente o total do mês atual retornado por Metrics,
nunca somas locais ou filtros históricos da Dashboard. Expense sinaliza mutações
confirmadas pelo client compartilhado, sem importar Metrics/Root. Root compõe os
contratos em `HomeWidgetSyncRepository` e possui um único `HomeWidgetSyncBloc`
sob ownership do AppWidget. Não o registre como singleton nem o recrie em rebuild.
O próprio Bloc observa pedidos de atualização pelo repository com `emit.onEach`,
em handler contínuo distinto dos eventos restartable; não assine esse stream no
widget. Launch e Sync usam o lifecycle nativo para cancelar suas observações.
Preserve revisões e serialização de publicações/limpeza no client para bloquear
respostas antigas após mutação/logout. Snapshot nativo contém somente mês e
centavos, sem credenciais; mês incompatível mostra “Abra para atualizar”. iOS usa
o App Group `group.com.bed.cordato` nos dois targets. Não faça HTTP no widget nativo
nem converta dinheiro para double ao formatá-lo.

Use a API funcional `createModule` do `flutter_modular` 7. Registre contratos
apontando para implementações. Para estado de página novo ou explicitamente
migrado, prefira `provide: (scope) => scope.addBloc<MyBloc>(MyBloc.new)` com
`BlocScopedExtension` em `core/presentation/extensions/`. A rota lê a instância
por `context.read<MyBloc>()` e a entrega à screen. Não registre o mesmo Bloc
também no módulo nem feche na tela uma instância pertencente ao escopo.

Nos fluxos ainda com ownership pela screen, registre Bloc por factory e injete
o tear-off estável, como `bloc: inject<ExpensesBloc>`, sem closures novas a cada
rebuild. Nunca use singleton de Bloc compartilhado entre telas. Session continua
global sob ownership de `AppWidget`; não o transforme em estado de página.

Módulos com `path` possuem binds de feature, disponíveis somente enquanto uma
rota da feature estiver ativa. Dependências consumidas entre features precisam
de módulo compartilhado sem `path`; não dependa de ter visitado uma rota irmã.
Registro no catálogo não comprova resolução de DI: teste o consumidor isoladamente.

Módulos pertencem à feature. Authentication e Expense usam um único módulo por
feature, sem `path`, com binds root-owned e URLs completas de `RouteEnum`.
Não fragmente esses módulos em dependencies/form/list/routes nem use `path: '/'`
em features irmãs: no Modular 7.1.1 o mesmo path identifica o mesmo escopo e seus
binds podem ser sobrescritos. Sem path não significa singleton de Bloc: `add`
continua factory e o dono da instância continua responsável pelo fechamento.
`provide` mantém ownership de página independente do escopo do módulo.
Outras features com paths exclusivos permanecem como estão até migração explícita.
`app_module.dart` faz a composição global.

Navegação pertence ao widget/mixin responsável, por extensões de `BuildContext`.
Argumentos de rota transportam dados, não callbacks. Use resultados tipados de
`pushNamed<T>` e `pop(result)` quando a operação devolve dados confirmados.
`ExpensesScreen` abre edição diretamente e recebe `ExpenseEntity?` no retorno;
Dashboard e Metrics recarregam ao voltar da listagem, mesmo sem alteração, sem
interceptar botão do sistema ou gesto para transportar flags. Callbacks locais
de composição visual, como Metrics notificar Dashboard, continuam permitidos.

## Testes Obrigatórios

Os testes seguem a mesma arquitetura, não o padrão antigo de data sources ou
commands. Espelhe o caminho de produção em `test/features/<feature>/`.

Não adicionar Python ao projeto, inclusive em scripts, fakes e fixtures.
Não manter nem criar testes de UI: telas, widgets, goldens, integração visual
ou flows Maestro. Previews manuais permanecem disponíveis. Preserve testes
unitários de Bloc, validação, formatação, contratos, infraestrutura e arquitetura.

| Alvo                         | Cobertura mínima                                                                                                               |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Domain                       | Invariantes, imutabilidade e semântica dos valores, sem SDKs.                                                                  |
| Application                  | Contratos puros e preservação de erros nas exceções.                                                                           |
| Repository em infrastructure | Payload, DTO, clients mockados, erros HTTP, parsing inválido, ordem/espera de persistência e propagação de falhas inesperadas. |
| Bloc                         | Estado inicial, sequência de estados, delegação, falha esperada/inesperada, concorrência, retry e fechamento pendente.         |
| Modular/rotas                | Catálogo de rotas e resolução de dependências/factories sem montar UI.                                                         |
| Architecture                 | Imports, camadas, contextos e isolamento de contratos; DI/rotas exigem testes próprios.                                        |

- Use `mocktail`, `bloc_test` e `flutter_test`. Em teste de Bloc, mocke o contrato
  de repository, não o client HTTP. Em teste do repository, mocke os clients.
- Controle operações pendentes com `Completer` ou sinais observáveis; não dependa
  de sleeps arbitrários para provar concorrência.
- Organize suítes extensas em `group` por operação ou responsabilidade. Separe
  preparação, ação e verificações; extraia montagem repetida para helpers locais.
  Sucesso e falha com expectativas diferentes ficam em cenários próprios, não em
  condicionais dentro das asserções. Matrizes com o mesmo comportamento continuam
  parametrizadas e precisam de nomes que identifiquem cada cenário.
- Testes de tempo/debounce de lógica usam `fake_async`, sem `WidgetTester`
  nem montagem de widgets. Crie e descarte recursos na zona de tempo do cenário.
- Políticas puras dos widgets nativos usam JUnit em `android/app/src/test/` e
  XCTest em `test/native/ios/`, compilando os arquivos de produção sem UI.
  Execute `dart run tool/test_home_widget_native.dart`, com argumento opcional
  `android` ou `ios`. Swift exige macOS/Xcode; isso não substitui build iOS ou
  conferência manual de tamanhos, valores longos e acessibilidade. Não execute
  instâncias concorrentes de `dart run`, pois os build hooks compartilham arquivos.
- Mocks/fakes/adapters públicos ficam em arquivos próprios sob
  `test/support/<feature>/mocks/` ou `fakes/`, nunca dentro de `*_test.dart` ou `lib/`.
- Reutilize um double por contrato; instâncias, stubs e fixtures de cenário são
  locais a cada teste. Imports de suporte usam caminhos relativos explícitos.
- Cancele subscriptions, conclua Futures controlados e descarte recursos criados.

## Previews E Verificação

Previews usam `@CordatoPreview`, tema real, localização e toast compartilhados.
Ficam em `presentation/previews/`; fakes de catálogo não usam rede, storage ou
mocktail. Mantenha um único dono de cada recurso, inclusive Bloc. Sign-in e sugestões de Expense recebem
uma instância com ownership externo; a screen não fecha o Bloc. Use
`PreviewResourceWidget` quando o recurso não pertencer ao lifecycle da tela.
Execute `dart run tool/widget_preview.dart`; `.widget_preview/` não é versionado.

Quando aplicável, execute nesta ordem:

```bash
flutter pub get
flutter analyze
flutter test
```

Verificação focada: `flutter test test/architecture` e testes da feature afetada.
Registre os comandos executados, os resultados e os bloqueios anteriores à tarefa.
Mudança exclusivamente documental não exige executar o app ou a suíte Flutter.

## Revisão E Pendências

Mudanças estruturais atualizam `ARCHITECTURE.md`; convenções e testes atualizam
este arquivo; estado do produto/configuração atualizam `README.md`. Release
Android atualiza `android/README.md`.

Antes de concluir, confira: camadas corretas, contrato puro, Bloc sem SDKs,
efeitos fora do build, ownership único, testes nas camadas corretas, documentação
coerente e ausência de comentários novos no código.

O estado de transição está registrado em `ARCHITECTURE.md`. Não restaure
dependências removidas nem enfraqueça testes arquiteturais para tornar o legado
aparentemente compatível. Migre cada fluxo completo, com seus consumidores e
testes, quando isso fizer parte da tarefa solicitada.
