# AGENTS.md

## Fonte de verdade e escopo atual

Estas regras orientam alterações no aplicativo Flutter Cordato e em seus testes.
A arquitetura canônica está em [ARCHITECTURE.md](ARCHITECTURE.md); execução,
estado do produto e pendências estão em [README.md](README.md).
Resultados anteriores estão no [histórico](docs/history/local-transition.md).

A branch `tostore` é exclusivamente local por decisão explícita.
Authentication, Session, Welcome, PocketBase, backend, worker, áudio, IA e Insight foram
removidos pelo usuário. CSV e compartilhamento sem consumidores também foram
removidos. Não restaure código, dependências, testes ou doubles desses fluxos
para satisfazer specs históricas ou sanar referências legadas.

O app usa ToStore compartilhado por DI. Não há identidade autenticada, `owner`,
sessão, backend, exportação ou backup/restauração pelo aplicativo.
Budget e Family são planejados. Não crie `identity` para reproduzir o backend
legado; `chat` está fora do escopo. Kotlin legado é referência de domínio,
não de estrutura Flutter.

Specs arquivadas e registros de execução são históricos. Em conflitos prevalecem
estas regras e ARCHITECTURE.md; consulte [openspec/README.md](openspec/README.md).
Não restaure Supabase/RPC, CommandIt, Either, data sources ou ownership antigo.
Pendências documentadas não autorizam mudanças incidentais de comportamento.

## Antes de alterar

- Leia a feature afetada, os componentes compartilhados usados e seus testes.
- Confira `git status` e preserve alterações existentes, inclusive fora do escopo.
- Faça a menor alteração que satisfaça a tarefa; não reformate áreas não relacionadas.
- Não faça commit, push, reset ou exclusões destrutivas sem solicitação explícita.
- Atualize contratos, consumidores, bindings e testes na mesma mudança.
- Registre bloqueios reais de análise, compilação e testes, sem ocultá-los.
- Não adicione comentários de linha, bloco ou documentação ao código. Explicações
  ficam em Markdown; preserve comentários existentes fora do escopo.
- Não amplie uma tarefa localizada para migrar outras features ou ownerships.

## Bootstrap e ToStore

`main` aguarda `createDependencies` antes de `runApp`.
`ToStoreFactory.create` recebe diretório persistente e schemas fornecidos pela
composição, usa `RecoveryDurability.durable` e desativa logs diagnósticos.
A factory não importa regras das features.

Somente `createAppModule` recebe o ToStore pronto e registra
`addInstance<ToStore>(database)` no módulo raiz. Não repasse o banco entre módulos.
`coreModule` não recebe o banco; repositories recebem a mesma instância pela DI.
Não crie singleton global manual, wrapper genérico de CRUD, Future de abertura
na DI ou service locator dentro dos repositories.

O bootstrap inicializa o perfil antes de montar o app. Falhas propagam, sem
reset, retry ou fallback para banco vazio; falha após abertura tenta fechar
o banco e preserva a falha original. A instância pertence ao bootstrap, não a
rotas ou telas; descartar a DI não deve fechá-la.
Não prometa durabilidade auditada, criptografia, backup ou app funcional com
base apenas em testes focados.

## Contratos locais das features

### User

UserEntity não possui ID/e-mail. IUserRepository expõe `get` e `update`,
sem exclusão de conta. UserRepository usa KV `profile.name` e `profile.avatar`
com o ToStore pronto. O perfil inicial é `Cordato` com seed aleatória persistida.

O inicializador preenche somente chaves ausentes, preserva valores válidos e
rejeita valores presentes malformados. Não crie identidade, sessão, cache ou
inicialização silenciosa no repository. O objeto KV antigo `profile` não é migrado.

Escritas verificam `hasErrors` e incluem somente campos fornecidos, sem fila de
Futures, transação ou estado pendente. Atualizações concorrentes de campos
diferentes não se sobrescrevem; atualizar ambos não é atômico.
Ausência de perfil e falhas esperadas geram UserException; parsing e erros de
programação propagam. Mensagens nativas do banco não chegam à UI.

User/Edit mantêm factories estáveis e ownership dos Blocs pela screen.
Dashboard consulta somente o contrato atualizado. Rotas User não exigem sessão.
User possui um único `userModule`, sem path, com binds e rotas completas.
Não separe dependências em outro módulo nem restrinja o repository ao lifecycle
da rota: Dashboard o consome sem visitar User.
Nome é validado na apresentação com 2–32 code points Unicode após trim;
Bloc/repository não normalizam a entrada.

### Expense

Expense usa schema próprio sem `owner`: ID automático, centavos inteiros
positivos, categoria padrão `other`, descrição anulável e data civil obrigatória.
Default hoje e validação de categoria pertencem ao repository; schema não
normaliza datas nem restringe o enum.

Use CRUD/queries nativos, datas ISO UTC pelos componentes civis, paginação por
offset/limite mais um e ordem determinística por data/ID. Descrição nula vira
texto vazio na projeção; SDK aplica trim nativo nos campos textuais, sem
normalização extra no repository.

Sugestões percorrem lotes de 100 até 30 correspondências literais case-insensitive
antes de deduplicar; preservam categoria/valor da ocorrência mais recente.
Aceitar sugestão aplica categoria, inclusive `other`, preservando data/valor manual.

Escritas verificam `hasErrors` e registros afetados; ID ausente gera
ExpenseException. Updates enviam somente campos fornecidos; sem campos apenas
leem, sem refresh. Mutações reconhecidas solicitam refresh nativo, sem alterar
formato do widget. Expense/Expenses preservam ownership pela screen e sugestões
pelo provide. Não restaure CSV, modelos de exportação ou compartilhamento.

### Metrics

Metrics é projeção local somente leitura de `expenses`, sem tabela própria,
cache, triggers ou escritas em Expense. Recebe o ToStore compartilhado e usa
`Agg.sum` por categoria em uma única consulta mensal: início inclusivo e próximo
mês exclusivo, ISO UTC pelos componentes civis. Sem datas usa o mês atual;
intervalos incompletos ou não mensais geram MetricsException antes da leitura.

Total e distribuição vêm dos mesmos grupos; centavos são inteiros e percentuais
são calculados em Metrics sem arredondamento antecipado. Categorias têm ordem
textual determinística; ID sintético `monthly-yyyy-MM` é estável.
Grupos usam `ExpenseCategoryMetricsResponse` em `infrastructure/responses/`;
repository monta o resumo mensal, sem camada `projections/`.
Sem agrupamento categories é null; mês vazio agrupado tem lista vazia imutável.

Infrastructure valida categorias pelo enum puro de Expense, sem importar sua
implementação ou criar dependência reversa. Parsing inválido, categorias
desconhecidas, grupos duplicados, somas inválidas e overflow projetado são
inesperados. Schema garante inteiro positivo; agregação não audita corrupção
dos registros que o motor ignora.

Queries verificam `hasErrors`; falhas esperadas de banco/filesystem viram
MetricsException com códigos, sem mensagens nativas na UI. Erros de programação
propagam; não há fallback para zero nem retry automático. Só o mês atual captura
revisão antes da leitura e aguarda publicação nativa, inclusive zero válido.
Preserve IMetricsRepository, UI, ownership, módulo único sem path, formatos e
revisões nativas.

### Dashboard, Settings e Information

Dashboard não contém áudio, speech, gravação, toque longo ou dependências de
microfone, inclusive em previews. O botão manual usa IconButtonWidget do core,
sem controller/lifecycle de captura.
ActionButtonDashboardWidget abre Expense por BuildContext com retorno tipado e
`returnToPrevious`; só solicita DashboardExpensesChanged após retornar despesa
confirmada, com contexto montado e mesma instância viva do DashboardBloc.

Settings usa módulo único sem path e rotas completas, sem autenticação.
SettingsScreen é StatelessWidget, sem Bloc ou provide, e navega por BuildContext.
Não restaure LogoutBloc, confirmação de saída, seção Dados, exportação ou
callbacks de navegação na rota.

Information é somente apresentação. Os documentos 2.1 de 21/11/2026 descrevem
perfil/dados locais, sem cadastro, backend, e-mails transacionais ou IA.
Distinga arquivos exportados anteriormente de backup restaurável, suporte de
acesso remoto ao banco, cópias do sistema de backup próprio e apoio Pix de
processamento de pagamentos. Não prometa criptografia, recuperação ou
conformidade jurídica já verificadas. Backup/restore nativo será tarefa posterior.

### Root e widgets nativos

Root não depende de Session/Authentication. `main` abre Dashboard após aguardar
dependências locais; `/` é fallback visual e sua política pura aponta à Dashboard.
AppWidget possui somente HomeWidgetLaunchBloc e HomeWidgetSyncBloc por factories
estáveis, com fechamento no lifecycle.

O atalho fica pendente até Navigator estar disponível e abre Dashboard → criação,
preservando criações sem confundi-las com edição. Use RouteStates reais de
`popUntil`: no Modular 7, `routeState` representa a base e Page.name não identifica
rotas empilhadas. Não restaure políticas de sessão ou redirect deferral.

Launch usa IHomeWidgetLaunchRepository para leitura/observação; infrastructure
filtra URIs antes de expor sinais. AppWidget não recebe client/streams nativos;
plugin não entra na apresentação.

HomeWidgetSyncStartedEvent observa pedidos de atualização com `emit.onEach` em
handler contínuo e solicita o resumo inicial. Refreshes restartable habilitam a
publicação por IHomeWidgetSyncRepository.enable antes de consultar Metrics.
O adapter usa `setMonthlySessionActive(active: true)` apenas como habilitação do
client, não identidade ou sessão. Não há refresh periódico ou retry automático.

Expense sinaliza mutações pelo client compartilhado sem importar Metrics/Root.
Root compõe os contratos em HomeWidgetSyncRepository. Preserve revisões e
serialização para bloquear respostas obsoletas. Snapshot contém somente mês e
centavos, sem credenciais; mês incompatível mostra “Abra para atualizar”.
iOS usa `group.com.bed.cordato` nos dois targets. Não faça HTTP ou cadastro em
background no widget nem converta dinheiro para double ao formatá-lo.
Não altere formatos/implementações nativas incidentalmente.

## Camadas e arquivos

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

- Crie somente diretórios necessários; features visuais não precisam de domínio
  ou repository. Não adicione use cases, inputs, outputs, services, data sources,
  BaseBloc ou stores globais sem necessidade concreta aprovada.
- Domain é puro: sem Flutter, Bloc, SDK, storage ou application.
- Application contém contratos e exceções, sem adapters/UI. Contratos de
  repository não ficam em `domain/repositories/`.
- Infrastructure implementa contratos, usa ToStore diretamente e converte
  payloads em tipos próprios. Capacidades nativas usam clients do core.
- Presentation conhece contratos/exceções, nunca repositories concretos ou clients.
- Módulos fazem composição e podem importar implementações concretas.
- Core contém capacidades compartilhadas; não mova regras para contornar limites.
- Dashboard pode compor contratos consultados. Expense não depende de outros
  contextos financeiros. Family futura consulta contextos por contratos/adapters,
  sem dependência reversa.

Dinheiro é inteiro em centavos de BRL, nunca double. Gasto não referencia
orçamento; pertencimento deriva da data civil. Orçamentos vivos da mesma pessoa
não podem se sobrepor. Família não concede escrita nos dados de outro membro;
sair/encerrar família não altera dados individuais. Visões combinadas são derivadas.
Essas invariantes futuras não comprovam funcionalidades implementadas.

## Repositories e falhas

- Use parâmetros nomeados e tipos simples. Repository/Bloc não normalizam
  entradas que pertencem ao formulário.
- Retorne Future<void> quando somente a conclusão importa; não exponha DTO,
  envelope ou tipo do SDK na apresentação/application.
- Parsing e payload pertencem a infrastructure, com casts estritos. Não esconda
  TypeError/FormatException como falhas de negócio.
- Converta somente falhas esperadas para exceções específicas de aplicação.
  Não introduza catch genérico para mascarar erros inesperados.
- Preserve ordem e metadados dos erros em ErrorsEntity, incluindo code, pointer
  e parameter quando presentes. Não converta falhas de storage em sucesso.
- UI usa mensagens locais em português, nunca diagnósticos nativos diretamente.
  Formatação por campo/operação pertence a formatters puros da feature.
  ErrorMessageFormatter contém somente mensagens compartilhadas.
- Preserve ErrorsEntity original nos contratos/estados e teste formatters sem UI.
- Não coloque segredos, tokens ou credenciais em código, fixtures reais ou logs.

## Bloc, screens e lifecycle

- Use Bloc para operações assíncronas, sem commands. Eventos/estados ficam junto
  ao Bloc da screen; prefira eventos concretos e estados sealed imutáveis.
- Derive disponibilidade das ações do estado; não espelhe loading/erro/resultado
  em flags locais. Defina concorrência explicitamente.
- Submissões droppable descartam eventos durante envio; sucesso bloqueia novos
  envios e falha permite retry manual, sem retry automático.
- Falha esperada preserva ErrorsEntity. Inesperada usa fallback seguro e
  `addError(error, stackTrace)`, sem client/callback de telemetry no Bloc.
- Após await respeite `isClosed` e `emit.isDone`. Fechamento não cancela storage.
  Use lifecycle nativo, sem flags paralelas ou override de close para imitá-lo.
- Blocs de página novos/explicitamente migrados usam `provide` e
  `scope.addBloc<MyBloc>(MyBloc.new)` pela BlocScopedExtension. Rota lê com
  `context.read` e entrega à screen; Modular é o único dono do fechamento.
  Não duplique bind no módulo. Testes/previews têm owner externo explícito.
- Fluxos ainda com ownership pela screen recebem factory estável, criam em
  initState, fecham em dispose e substituem em didUpdateWidget somente se a
  factory mudar. Rebuild não cria outro Bloc. BlocProvider.value não muda o owner.
- Use BlocBuilder para renderizar e listeners/consumers para efeitos únicos.
  Não navegue, envie operação ou mostre toast durante build.
- Formulário mantém entrada, validação e erros por campo; preserve entrada na
  falha e limpe somente o erro do campo editado. Desabilite conforme o estado.
- Ação next aponta explicitamente ao FocusNode do próximo campo por
  onEditingComplete. Mixin possui/descarta nós; ação final preserva submissão.
- Extraia lifecycle, controllers, timers e handlers substanciais para mixin
  específico com `on State<Widget>`. Screen mantém composição visual.
  Mixin não acessa repository/storage e descarta recursos que cria.
- Helpers usam context do próprio State, sem repasse redundante. Lógica pura
  de StatelessWidget pode usar mixin `on StatelessWidget`, sem recursos mutáveis
  ou operações assíncronas.

## Dart, imports e componentes

- Não use `var`, inclusive em testes/previews/ferramentas. Use final quando
  não há reatribuição e tipo explícito para variáveis mutáveis.
- Não nomeie variáveis, parâmetros, campos ou getters como `result`.
  Use nomes que expressem o dado/operação, não outro nome genérico.
- Métodos têm responsabilidade identificável. Separe validação, erros de campo,
  envio de eventos, feedback e navegação em handlers extensos.
- Separe etapas por linhas em branco. Use chaves em if/else/laços; prefira guard
  clauses e switch/pattern matching. Evite ternários aninhados e cascatas de if.
- Extraia alternativas visuais substanciais em widgets públicos em arquivos
  próprios, sem árvores de ternários; preserve foco/controllers/acessibilidade.
- Não crie services/stores/flags/hierarquias de mixins/helpers genéricos apenas
  para reduzir linhas. Revise consumidores sem deslocar complexidade.
- Flutter >=3.50.0, Dart ^3.14.0. Use primary constructors em declarações novas
  elegíveis, campos imutáveis explícitos e final; preserve const.
  Parâmetros só de inicialização não induzem campos. Avalie semanticamente
  construtores com lifecycle/múltiplos caminhos generativos.
- Não introduza primary constructor vazio em interfaces, mixins, States ou mocks.
- Widgets novos são públicos, final, sufixo Widget, arquivo próprio, parâmetros
  nomeados, required e super.key; const quando possível.
- Imports da aplicação usam `package:cordato/`, não relativos de lib.
- UI Material usa `package:material_ui/material_ui.dart`, não flutter/material.
  Imports Flutter especializados são permitidos para símbolos não exportados.
  Remova imports sem uso; não crie barrels.
- Reutilize botões, fields, BounceWidget, animações/imagens do core.
  Botões compartilhados incorporam bounce.
- Ícones usam Icons/IconData Material pelo IconWidget estático do core; não
  adicione bibliotecas/controllers/scopes/listeners para animá-los.
  Preserve semântica, tema e estado desabilitado.
- Use context.colors, context.typography e context.radius; sem tokens/extensões
  duplicados ou fundo fixo de Scaffold sem necessidade.
- Recuos externos de telas/bottom sheets são 16 pixels além de áreas seguras e
  teclado. Voltar de 48 ocupa leading de 80 com simetria horizontal de 16.
  Cabeçalho expandido começa 16 abaixo da toolbar. Preserve espaçamentos internos,
  reservas para ações flutuantes e largura de leitura.
- Animações respeitam MediaQuery.disableAnimationsOf (Android) ou reduceMotionOf
  (iOS), sem substituir uma preferência pela outra.
- Assets ficam em AssetEnum/pubspec.yaml; use ImageWidget.
- Reutilize ErrorScreen; preserve rolagem, fonte ampliada e exclusão semântica
  de imagens decorativas/skeletons.

## Módulos e navegação

Use `createModule` do Modular 7. Registre contratos apontando a implementações.
Blocs screen-owned usam factory/tear-off estável como `inject<ExpensesBloc>`,
sem closures novas por rebuild nem singleton compartilhado entre telas.

Dependências entre features exigem binds disponíveis sem visitar rotas irmãs.
User, Expense, Metrics e Settings têm módulo único sem path; não fragmente nem
use path `/` em features irmãs. Módulos com paths exclusivos permanecem até
migração explícita. Teste resolução, não apenas catálogo.

Navegação nova pertence ao widget/mixin por BuildContext, não callbacks de rota
ou Modular.to. Preserve callbacks legados fora do escopo até migrar consumidores.
Argumentos transportam dados. Use `pushNamed<T>` e `pop` com retorno tipado
para dados confirmados. ExpensesScreen recebe ExpenseEntity? da edição.
Dashboard/Metrics recarregam ao voltar da listagem, mesmo sem alteração, sem
interceptar voltar/gesto para transportar flags. Callbacks visuais locais são permitidos.

Strings Android usam `<tipo>_<contexto>_<descricao>` em snake_case inglês,
`res/values/strings_<contexto>.xml`; strings.xml pertence a app.
Prefixos: failure_, success_, label_, action_, cd_, msg_, config_.
Agrupe tipos por linhas em branco sem comentários; não misture cores/estilos.
Configuração técnica usa translatable=false. Preserve placeholders posicionais,
URLs e referências XML/Kotlin/testes ao renomear. Consulte android/README.md.

## Testes obrigatórios

Espelhe produção em `test/features/<feature>/`. Não adicione Python.
Não mantenha/crie testes de UI, goldens, integração visual ou flows Maestro.
Previews manuais permanecem; preserve testes unitários e arquiteturais.

| Alvo | Cobertura mínima |
| --- | --- |
| Domain | Invariantes, imutabilidade e semântica, sem SDKs. |
| Application | Contratos puros e preservação de erros nas exceções. |
| Repository | SDK real, conversão, operações, parsing, falhas esperadas/inesperadas e persistência. |
| Bloc | Estado inicial, sequência, delegação, erros, concorrência, retry e fechamento pendente. |
| Modular/rotas | Catálogo, resolução e factories sem UI. |
| Architecture | Imports, camadas, contextos e contratos; DI/rotas têm testes próprios. |

- Use mocktail, bloc_test e flutter_test. Blocs mockam contrato de repository.
- ToStore usa SDK real, diretórios temporários e fechamento explícito, sem UI.
  Mocks do SDK somente para falhas/operações pendentes do inicializador e
  repositories User/Expense/Metrics, em `test/support/core/mocks/`.
- Composição global não simula módulos inteiros; pode simular canal nativo,
  sem montar UI. Preserve cobertura real de Metrics/composição.
- Testes do core verificam formatadores/client nativo sem ToStore.
  Teste do app verifica instância única no root e ausência de fechamento pela DI.
- Não restaure testes/doubles exclusivos de PocketBase, sessão/identidade,
  HTTP/Dio, recording, áudio, CSV ou compartilhamento removidos.
- Testes de acessibilidade não enumeram telas removidas, não fazem skip por
  existência nem relaxam asserções dos componentes atuais.
- Use Completer/sinais observáveis, não sleeps arbitrários para concorrência.
- Suítes extensas usam groups por responsabilidade. Separe preparo/ação/asserts;
  helpers locais reduzem montagem repetida. Cenários com expectativas distintas
  não usam condicionais nas asserções. Matrizes homogêneas têm nomes claros.
- Tempo/debounce usa fake_async sem WidgetTester; crie/descarte recursos na zona.
- Mocks/fakes/adapters públicos ficam em arquivo próprio em
  `test/support/<feature>/mocks/` ou `fakes/`, nunca em *_test.dart ou lib.
  Reutilize double por contrato; stubs/fixtures são locais. Imports de suporte
  usam relativos explícitos.
- Cancele subscriptions, conclua Futures controlados e descarte recursos.
- Políticas nativas usam JUnit em android/app/src/test e XCTest em test/native/ios,
  compilando produção sem UI. Execute `dart run tool/test_home_widget_native.dart`
  com argumento opcional android/ios. Swift exige macOS/Xcode.
  Não execute instâncias concorrentes de dart run: build hooks compartilham arquivos.

## Previews e verificação

Previews usam @CordatoPreview, tema real, localização e toast compartilhados em
presentation/previews. Fakes não usam rede/storage/mocktail. Cada recurso tem
owner único; sugestões de Expense recebem owner externo. Use PreviewResourceWidget
quando o recurso não pertence à tela. `dart run tool/widget_preview.dart` serve
o catálogo; `.widget_preview/` não é versionado.

Quando aplicável execute, nesta ordem:

```bash
flutter pub get
flutter analyze
flutter test --reporter failures-only
```

Verificação focada inclui test/architecture e a feature. Registre comandos,
resultados e bloqueios prévios. Não anuncie homologação nativa por testes
unitários. Mudança exclusivamente documental não exige app/suíte Flutter.

Release Android usa `.github/workflows/android-release.yml`, manual e somente
main, sem publicar no Play ou commits de versão. Versão visível vem do pubspec;
tool/android_release_version.sh define código por GITHUB_RUN_NUMBER + 5.
Reexecuções mantêm código; novo código exige novo dispatch. Não altere offset
ou recrie workflow sem considerar maior código já usado no Play.
Secrets pertencem a android-release. Mudanças de workflow exigem actionlint;
script exige shellcheck, além das verificações Flutter aplicáveis.
Setup e limites estão em android/README.md. O BASE_URL legado do workflow não
configura o banco local e não autoriza restaurar integração remota.

## Revisão e documentação

Mudanças estruturais atualizam ARCHITECTURE.md; convenções/testes atualizam este
arquivo; produto/configuração atualizam README.md; release atualiza android/README.md.
Preserve specs/changes históricas; identifique precedência em openspec/README.md.
Resultados anteriores ficam em docs/history, sem se tornarem instruções vigentes.

Antes de concluir confira camadas, contrato puro, Bloc sem SDK, efeitos fora do
build, ownership único, testes corretos, documentação coerente e ausência de
comentários novos no código. Não enfraqueça arquitetura para aparentar conformidade.

Pendências conhecidas incluem constantes/consumidores após remoção de Welcome,
associações de autenticação legadas, permissões nativas remanescentes e BASE_URL no workflow.
Documentá-las não autoriza removê-las/restaurar fluxos incidentalmente.
