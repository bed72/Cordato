# AGENTS.md

## Objetivo

Este arquivo orienta agentes e pessoas que alteram o aplicativo Flutter Cordato.
As regras abaixo descrevem o padrão que deve ser seguido ao criar features,
widgets, telas, estado, rotas e testes.

Documentação canônica: [ARCHITECTURE.md](ARCHITECTURE.md).

Use o código atual para descrever o que existe e este arquivo e a documentação
canônica para as convenções aprovadas. Há specs OpenSpec e skills locais com
referências antigas a Supabase; elas não representam a integração HTTP atual.
Não reintroduza esse fluxo para reproduzir uma descrição histórica.

Antes de alterar código, leia a feature afetada, os widgets compartilhados que
ela usa e os testes correspondentes. O projeto evolui por alterações pequenas;
não substitua uma convenção existente por uma abstração nova sem necessidade.

## Contexto Do Produto

Cordato é um aplicativo de finanças pessoais e familiares. Cada pessoa é dona
dos próprios dados financeiros; uma família é somente uma lente de leitura
compartilhada entre seus membros, não uma dona de dinheiro.

O produto possui o contexto de dados do usuário e os contextos financeiros:

- `user`: dados do usuário; possui entidade, contrato de repository, DTO e data
  source remoto, implementação de repository, módulos de dependências e rotas
  e apresentação para consulta, edição do nome e exclusão da conta.
- `expense`: fatos atômicos de gastos, pertencentes a uma pessoa.
- `budget`: tetos planejados por intervalo de datas; gasto e saldo são derivados.
- `family`: organização entre membros de uma família, com leitura combinada e sem escrita nos dados de outra pessoa.
- `insight`: análises derivadas, somente leitura e sem persistência própria.

O aplicativo integra sign-in e sign-up por e-mail e senha à API HTTP JSON:API;
também confirma e-mail por link e permite reenviar a verificação. O token opaco
do sign-in e o ID do usuário são persistidos em storage seguro. A feature
`session` lê e observa a presença do token. `AppScreen`, em
`features/root/presentation/`, usa essa leitura para
escolher a rota inicial em `/`; `AppWidget` observa mudanças e redireciona após
401 de requisição protegida e após logout confirmado em Settings. O logout
revoga remotamente o token antes de limpar todo o storage seguro pelo data
source local de Authentication. `LogoutCommand` pertence a `authentication` e depende do
contrato de repository; Settings recebe esse command. Não há validação da
sessão no backend na abertura, refresh automático ou guard do Modular.
O Kotlin legado é somente referência de domínio.
`expense` possui `ExpenseEntity` imutável e `ExpenseCategoryEnum` no domínio,
rótulos pt-BR em `ExpenseCategoryExtension` na apresentação, estrutura visual de
formulário, validators e estado de apresentação. Também possui
o contrato `IExpenseRepository.create`, `ExpenseResponse`
e data source HTTP de criação, além de `CreateExpenseCommand` em
`presentation/screens/expense/commands/`, e `ExpenseRepository` em `application/repositories/`.
O command recebe um record com `cents`, `description` e `occurredOn` e delega
esses parâmetros a `IExpenseRepository.create`, preserva `Either` e
implementa `ICommand`. `expenseDependenciesModule` registra data source e
repository pelos contratos, commands por factory e validators
e os injeta na tela. O formulário executa o cadastro pela API.
`IExpenseRepository.get({int pageSize = 30, String? pageLink, DateTime? from, DateTime? to, String? category})` e o data source
remoto oferecem consulta paginada, consumida pela seção de recentes da Dashboard.
`IExpenseRepository.update({required String id, int? cents, String? description, DateTime? occurredOn})`
e o data source remoto oferecem edição parcial de valor, descrição e data civil.
O PATCH serializa `occurredOn` não nulo como `occurred_on` em `yyyy-MM-dd`, sem
conversão de fuso ou default para atributos omitidos.
O repository delega os parâmetros sem normalização ou defaults, converte erros
remotos para `ErrorsEntity`, valida os centavos da resposta por
`ExpenseResponse.toEntity()` e traduz exceções em `ErrorsEntity.unknown()`.
`UpdateExpenseCommand`, em `screens/expense/commands/`, recebe o record
`({String id, int? cents, String? description, DateTime? occurredOn})`, delega a `update` sem normalização
e preserva `Either` em `UpdateRepositoryType?`, inicialmente nulo. Implementa
`ICommand` e é registrado por factory em `expenseDependenciesModule`; cada
consumidor deve descartar sua instância. `GetExpenseCommand`, no mesmo diretório,
consulta `IExpenseRepository.getById({required String id})`, preservando `Either`
em `GetByIdRepositoryType?`. O data source executa GET relativo `expenses/<id>`
com ID codificado e retorna `ExpenseResponse`; o repository valida centavos,
converte erros e traduz exceções como nas outras operações.
`ExpenseScreen`, em `screens/expense/`, compartilha cadastro e edição em `/expense`.
Sem ID abre criação; com argumento `String` busca a despesa por ID, apresenta
skeleton do formulário com anúncio “Carregando despesa” e preenche descrição,
centavos e data da API. Falhas de consulta apresentam “Tentar novamente”.
`ExpenseScreenStateMixin` coordena a consulta, ignora respostas obsoletas e descarta
os commands de criação, consulta e atualização, todos recebidos por factory.
Na edição, header, botão e toasts mudam para atualização; a data pode ser alterada
pelo mesmo picker do cadastro. Somente atributos alterados são enviados,
comparando a data civil por ano, mês e dia.
O botão habilita com alterações válidas e não possui hold. Sucesso retorna a
entidade à listagem, que substitui o item preservando paginação e rolagem e
reposiciona a despesa quando a data civil muda.
A listagem abre a edição por arraste da esquerda para a direita no mesmo
`ExpenseDismissibleWidget` da exclusão. O fundo usa `primaryContainer` e um lápis
`onPrimaryContainer`; limite, threshold e spring são compartilhados pelos dois
sentidos. Arrastes curtos ou cancelados retornam sem ação. A edição não abre por
toque simples e possui a ação de acessibilidade “Editar despesa”. O gesto oposto
mantém a confirmação de exclusão.
`ExpensePageEntity` e `ExpensePageResponse` copiam os itens para listas não
modificáveis e preservam `next` e `prev` como continuações opacas anuláveis.
O repository usa 30 quando o tamanho é omitido ou menor ou igual a zero e
preserva tamanhos positivos. Valida os centavos de todos os itens, sem
resultado parcial. O data source recebe o tamanho efetivo obrigatório e usa
GET relativo `expenses`, `page[size]` na
query e extrai a query do link de continuação, sem acessar seu destino absoluto.
O tamanho solicitado prevalece sobre o do link; ordem e datas da API são preservadas.
Repository e command delegam `from`/`to` sem defaults ou normalização, inclusive
pares incompletos. O data source serializa somente limites não nulos em
`filter[from]`/`filter[to]` pelo helper civil existente. Limites explícitos
prevalecem sobre o link e removem `filter[year]`, `filter[month]` e `filter[day]`
herdados quando ao menos um limite está presente, preservando a continuação e
os demais parâmetros. Sem intervalo explícito, os filtros do link são mantidos.
O recorte de seis despesas pertence ao consumidor Dashboard.
`GetExpensesCommand`, em `expense/presentation/screens/expenses/commands/`, recebe o record
`({int pageSize, String? pageLink, DateTime? from, DateTime? to, String? category})`, delega a `IExpenseRepository.get` e preserva
`Either` em `GetRepositoryType?`, inicialmente nulo. Não acumula páginas nem
define o limite da Dashboard. Implementa `ICommand` e é registrado por factory
em `expenseDependenciesModule`; cada consumidor deve descartar sua instância.
`ExpenseFormValidator` reúne os resultados de valor, descrição e data pelo padrão
`ValidationResult` do core. Reutiliza os validators existentes de descrição e
data, e `ExpenseCentsValidation` exige centavos positivos. Retorna um record
com resultado por campo, sem interromper na primeira falha. Os validators ficam
em `screens/expense/validators/`, são registrados no módulo de dependências de
Expense e consumidos pelo formulário.
`ExpenseFormWidgetStateMixin`, em `screens/expense/mixins/`,
concentra controller, campos, seleção de valor e
data, validação e listener do command, descartando os recursos que cria.
`CommandBuilder` controla loading e desabilita campos e envio. Erros da API são
mostrados nos campos pelo pointer ou por toast. `HoldButtonWidget` envia por toque
simples ou hold: após sucesso, ambos exibem toast; o toque simples chama o callback
de navegação injetado para Dashboard, e o hold limpa descrição, valor e erros,
redefine a data para hoje e permanece na tela. Falhas preservam os dados nos dois
modos; hold interrompido não envia. Cancelar pickers preserva a entrada.
A Dashboard abre `/expense` com `(returnToPrevious: true)`, record de tipo
`({bool returnToPrevious})`. Após sucesso por toque simples, a rota usa
`context.pop()` para preservar a instância da Dashboard e seu mês selecionado.
Cancelar também retorna à mesma instância. Voltar sem alterações não recarrega.
Após alterações confirmadas, as três seções
são recarregadas no mês preservado; se alguma consulta ainda estiver rodando,
a recarga aguarda o fim de todas. Troca de dependências invalida a recarga pendente
e descarte impede sua execução. Sem argumento ou com `returnToPrevious: false`,
o cadastro independente mantém a navegação para `/dashboard` após sucesso.
A data inicial do formulário continua sendo hoje e hold não fecha a rota.
Dashboard consulta nome e semente do avatar por `UserCommand` e as seis primeiras
despesas por uma instância própria de `GetExpensesCommand`, descartada pela tela.
`DashboardScreenStateMixin` concentra consulta inicial, atualização por gesto e
retorno assíncrono do formulário e da listagem completa, recarregando as despesas
recentes, insights e métricas somente após alterações confirmadas, quando a mesma instância permanece montada.
Os callbacks financeiros retornam `Future<bool>` e o módulo transporta
`VoidCallback onExpensesChanged` no record de argumentos junto a `returnToPrevious`
ou `from`/`to`. O formulário sinaliza criações confirmadas, inclusive hold, e
atualizações; a listagem sinaliza edições e exclusões confirmadas. O sinal é local
à navegação e independe do modo de voltar. Records sem callback continuam aceitos.
Os cards de categoria usam `BounceWidget` e abrem a mesma listagem de “Ver tudo”
com categoria opcional e mês selecionado. Metrics emite somente a string da
categoria por callback; Dashboard compõe a navegação. Expense delega `category`
sem normalização e envia `filter[category]`, com precedência sobre o link.
Listagem preserva ambas as lentes na paginação, refresh e retry e remove itens
editados que deixem de pertencer ao mês ou à categoria.
A Dashboard recebe instâncias próprias de `GetInsightsCommand` e
`GetExpenseMetricsCommand`, descartadas pela tela. `selectedMonth` é o contexto
compartilhado das três seções: intervalo civil para métricas e recentes, ano/mês
para insights. Consultas são paralelas na abertura, troca, refresh e retorno;
refresh preserva o mês. `DashboardMonthSelectorWidget` mantém mês/ano visíveis,
impede meses futuros e desabilita as setas enquanto qualquer seção carrega,
incluindo retry. Listeners de `isRunning` são removidos no lifecycle; retornos
obsoletos de navegação são ignorados. A troca ativa skeletons sem dados anteriores
sob o novo título. Cada seção oferece retry localizado no mês selecionado.
`InsightsSectionWidget` fica acima das
despesas, com skeleton, erro com retry e seção oculta quando vazia.
`ExpensesSectionWidget` usa `CommandBuilder`
para loading, erro com título, descrição e retry, vazio mensal e sucesso, sem paginação na UI.
Reutiliza `ExpenseItemWidget` de Expense, `IMoneyFormatter` e datas pt-BR sem
conversão de fuso. “Ver tudo” requer itens e callback de navegação disponível;
a rota fornece o destino `/expenses` para a listagem completa.
`ExpensesScreen`, em `expense/presentation/screens/expenses/`, usa uma instância
própria de `GetExpensesCommand` e reutiliza `ExpenseItemWidget` e os formatters
do core. `ExpensesScreenStateMixin` acumula páginas de 20 itens em ordem
decrescente pela data civil. A rota `/expenses` recebe o record opcional
`({DateTime from, DateTime to})` e o repassa como `period`; sem argumento mantém
a consulta geral. “Ver tudo” recebe o mês selecionado pelo callback
`Future<bool> Function(DateTime month)?` da Dashboard e transporta seu intervalo
civil completo. O título “Despesas” e a descrição “Acompanhe todas as suas
despesas.” são fixos. `ExpensesFiltersWidget` mostra categoria antes do período,
12 pixels abaixo da descrição, em `InputChip` com ícone de fechar, ação nativa
`onDeleted`, `BounceWidget` e `Wrap` com espaçamentos de 8 pixels. Os filtros
ficam fora de exclusões semânticas e possuem rótulos de remoção localizados.
Períodos mensais mostram mês e ano; outros intervalos mostram os limites civis.
Sem filtros, não há pílulas nem espaço adicional.
`ExpensesScreenStateMixin` inicializa `activeCategory` e `activePeriod` pelos
argumentos e usa esses valores em consultas, rótulos, vazio e retorno da edição.
Rebuilds e troca isolada do command preservam os filtros locais; mudanças reais
nas entradas reiniciam a lente e invalidam operações anteriores. Se a consulta
do mesmo command estiver em andamento, uma única recarga da combinação vigente
aguarda seu término. `removeCategoryFilter` e `removePeriodFilter` removem
somente o filtro correspondente, limpam itens, continuação e feedback, mantêm o
controller e voltam ao topo antes da primeira página. `canRemoveFilters` bloqueia
remoção durante loading, edição e confirmação/execução de exclusão, sem enfileirar
ações bloqueadas. Falha da nova lente mantém filtros novos e lista vazia; retry
solicita a primeira página. Refresh/paginação da mesma lente preservam itens em
falha e repetem a operação correspondente. Remover filtros não sinaliza alteração
financeira nem muda o mês da Dashboard. Abertura, paginação,
refresh e retry preservam os filtros ativos. Edição para fora do intervalo inclusivo
remove o item; dentro dele, atualiza ou reposiciona. Edição e exclusão preservam
controller de rolagem e continuação e verificam se é necessário carregar mais.
A ordenação permanece
decrescente pela data civil, preservando a ordem da API entre itens do mesmo dia,
repassa `next` sem interpretação e carrega ao se aproximar do fim da rolagem.
Atualização por gesto substitui os itens somente após sucesso. Falhas preservam
os itens e permitem repetir a operação que falhou por “Tentar novamente”. O mixin
descarta controller e command e ignora respostas obsoletas.
A tela mantém uma única lista lazy com cabeçalhos Hoje, Esta semana e Este mês
para o mês corrente, sem repetir despesas. A semana começa na segunda-feira e
exclui hoje e dias de outro mês. Os demais meses e datas futuras usam mês e ano.
Cada item compara seu período com o do item anterior, inclusive entre páginas,
sem reagrupar toda a lista durante o build. Grupos vazios não aparecem.
Cabeçalhos ficam fora do conteúdo arrastável; edição de data reposiciona o item
e exclusão do último item de um grupo remove o cabeçalho. A tela compõe
`ExpensesSkeletonWidget` de `expense/presentation/widgets/`,
compartilhado com a Dashboard. O skeleton reutiliza `ExpenseItemWidget` com
`Skeletonizer`: oito placeholders sem itens e três no rodapé com itens já
carregados. Os textos fictícios são excluídos da semântica, e a listagem anuncia
“Carregando despesas”. `expenseRoutesModule` registra a rota autenticada
`/expenses`, acessível por “Ver tudo” da Dashboard.
`insight` possui entidades imutáveis `InsightEntity`, `InsightPeriodEntity` e
`InsightDateRangeEntity` e o contrato somente leitura `IInsightRepository.get({int? year, int? month})`,
com `Either<ErrorsEntity, List<InsightEntity>>`. `type` e `group` preservam strings
da API, datas são civis e a comparação é opcional. `InsightEntity.period` e
`InsightResponse.period` são anuláveis para preservar `period: null` em insights
de onboarding como `insufficient_history`; esses itens exibem o título e a
descrição da API no card existente, sem datas fictícias. `InsightRepository`, em
`application/repositories/`, delega a consulta a `IInsightRemoteDataSource`,
converte DTOs em entidades preservando ordem e conteúdo e traduz erros remotos
e exceções em `ErrorsEntity`. O contrato remoto e os DTOs de conversão estão em
`infrastructure`. `InsightRemoteDataSource` executa GET relativo protegido
`insights` pelo HTTP do core e `response<T>`, convertendo a lista JSON:API em
DTOs com datas civis e comparação opcional. Parsing inválido invalida a lista
completa. Repository e command delegam ano e mês sem defaults ou normalização;
o data source envia somente valores não nulos em `filter[year]` e `filter[month]`.
Sem filtros, não envia query. Pares incompletos preservam erros remotos, incluindo
`source.parameter` e `source.pointer`. O mês é referência da análise: períodos
de vários meses e períodos nulos não são recortados ou substituídos.
`insightDependenciesModule` registra data source e repository como
lazy singletons pelos contratos e o command por factory, composto por `appModule`.
`GetInsightsCommand`, em `insight/presentation/commands/`, consulta
`IInsightRepository.get` com o record `({int? year, int? month})`, preserva `Either` em
`GetRepositoryType?`, inicialmente nulo, e implementa `ICommand`. Cada execução
substitui o resultado anterior; o consumidor deve descartar sua instância.
`InsightsListWidget` usa rolagem horizontal, cards com toda a largura disponível
descontando as margens laterais de 20 pixels,
espaçamento de 12 e altura pelo maior conteúdo sem truncamento.
`InsightCardWidget` compõe `IformationCardWidget` do core e seleciona ícone e
cor por tipo no mixin de apresentação, com fallback neutro para tipos novos.
Os cards são informativos, sem ação, e preservam textos e ordem da API.
`budget` e `family` não têm feature Flutter implementada.
Não descreva recursos planejados como código existente nem crie
um contexto `identity` para reproduzir o backend antigo. O contexto `chat` não
faz parte do escopo atual.

Regras de domínio que devem ser preservadas nas features financeiras:

- valores monetários são representados em centavos inteiros e somente em BRL;
- um gasto não referencia um orçamento; o pertencimento é derivado pela data;
- orçamentos vivos da mesma pessoa não podem se sobrepor;
- sair ou encerrar uma família não altera os dados individuais;
- participar de uma família nunca concede permissão de escrita sobre os dados de outro membro;
- visões combinadas e insights são recalculados a partir dos dados proprietários.

## Princípios De Trabalho

- Preserve alterações existentes do usuário, mesmo que estejam fora do escopo.
- Não reverta arquivos ou formate áreas não relacionadas à tarefa.
- Faça a menor alteração que resolva o problema.
- Não crie uma nova extensão, token, camada ou gerenciador de estado quando já
  existe uma solução no `core`.
- Não altere contratos públicos internos sem atualizar todos os consumidores e
  testes na mesma mudança.
- Não esconda falhas de análise ou testes. Registre a causa e se ela é anterior
  à alteração.
- Não faça commit, push ou alterações destrutivas sem solicitação explícita.
- Mudanças estruturais devem atualizar a documentação canônica na mesma alteração.

### Comentários No Código

- Não adicione comentários no código: comentários de linha, de bloco ou de
  documentação, incluindo `//`, `/* ... */`, `///` e `/** ... */`.
- Use nomes, tipos, testes e organização do código para expressar a intenção.
- Registre explicações, decisões e contratos nos arquivos Markdown apropriados,
  especialmente `ARCHITECTURE.md`, `README.md` e este arquivo.
- Não remova comentários existentes fora do escopo da tarefa.

## Stack Atual

- Flutter/Dart com constraint de SDK `^3.13.2` em `pubspec.yaml`.
- Material 3 através de `material_ui`.
- `flutter_modular` 7 para módulos, injeção de dependências e rotas.
- `command_it` para operações assíncronas observáveis pela apresentação.
- `listen_it` está declarado, mas não é usado diretamente no código atual.
- `dio` para integração HTTP JSON:API de Authentication, User, Expense e Insight.
- `flutter_secure_storage` para armazenamento seguro.
- `mocktail` e `flutter_test` para testes.
- Fonte de aplicação: `Inter-Variable.ttf`.

## Estrutura

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
      core_module.dart
      domain/
      infrastructure/
      presentation/
    user/
      user_module.dart
      domain/
        entities/user_entity.dart
        repositories/interface_user_repository.dart
      application/
        repositories/user_repository.dart
      infrastructure/
        local/user_local_data_source.dart
        remoto/user_remote_data_source.dart
        responses/user_response.dart
      presentation/
        screens/user/
        screens/edit_user/
    <feature>/
      <feature>_module.dart
      domain/
      application/
        data/
        repositories/
      infrastructure/
        local/
        remoto/
        responses/
        clients/          # quando a feature tiver um client próprio
      presentation/
        commands/          # commands da feature sem tela proprietária nela
        screens/
          <screen>/
            <screen>_screen.dart
            commands/
            mixins/         # quando a tela precisar de estado de UI extraído
            widgets/        # widgets específicos da tela
        widgets/

test/
  features/
    <feature>/
      ...
```

Feature code deve ficar dentro da própria feature. O `core` contém apenas
capacidades realmente compartilhadas, como tema, widgets básicos, animações,
imagens, storage e `Either`.
Também oferece o cliente HTTP, os responses de erro e a função `response<T>`
compartilhada pelos data sources.

Authentication, User, Session, Expense e Insight mantêm as implementações de repository
em `application/repositories/`. Tipos puros de entrada ficam em
`application/data/`, e contratos de repository permanecem em
`domain/repositories/`. Os testes espelham os caminhos de aplicação. Não crie
diretórios vazios para padronizar features sem esses tipos.

Os bounded contexts do produto devem ser refletidos em features próprias,
quando implementados. `dashboard` é uma feature de apresentação e composição,
não um bounded context de negócio. `authentication` encapsula sign-in e
sign-up por e-mail e senha via API; não deve assumir a responsabilidade de
modelar todo o ciclo de vida de `identity` do backend antigo. Na implementação
atual, `authentication` também reúne confirmação de e-mail e reenvio, sem criar
uma sessão nesses fluxos. `session` detém a leitura e observação da presença do
token, sem depender das camadas de `authentication`. A entrada e a observação
global são composição do app em `features/root/presentation/`, não telas de
`session`. `root` é uma feature de apresentação global, sem domínio, repository
ou módulo próprio no estado atual; `app_module.dart` registra sua rota `/`.
Não crie camadas vazias para features que hoje possuem somente apresentação.
Crie módulos e demais camadas apenas quando houver dependências, rotas ou
implementações reais a registrar. A feature `user` possui `userDependenciesModule`
em `user_module.dart`, sem `path`, registrando os data sources remoto e local e
`IUserRepository` como lazy singletons e `UserCommand` por factory, composto por
`appModule`. `userRoutesModule` registra `/user` e `/user/edit` e os commands de
exclusão e atualização do nome como lazy singletons.

### Contexto User

- `UserEntity` é imutável, com `id`, `name`, `email` e `status` como `String`.
  `avatar` é `String?`, preservando `avatar` ausente ou nulo da API.
  Não inclui datas, `type` ou `links`.
- `status` preserva o valor textual da API; não invente estados de enum sem
  contrato definido.
- `IUserRepository` define `getById()`, `delete()` e `update({String? name, String? avatar})`.
  As três operações leem o ID persistido por `IUserLocalDataSource.getId()`;
  ID ausente ou vazio retorna erro sem chamada remota. O data source remoto
  continua recebendo o ID explicitamente.
  Os resultados usam typedefs `Either<ErrorsEntity, UserEntity>` para consulta
  e atualização e `Either<ErrorsEntity, bool>` para exclusão.
- Atualização permite `name` e `avatar`, omitidos do payload quando nulos. Não
  inclua atualização de e-mail, status ou datas sem uma nova decisão.
- `IUserRemoteDataSource` e `UserRemoteDataSource` ficam no mesmo arquivo em
  `infrastructure/remoto/`, seguindo o padrão de Authentication. O DTO
  `UserResponse` faz parsing e oferece `UserResponseToEntity.toEntity()`.
- GET e PATCH retornam `Either<ErrorsResponse, UserResponse>`. DELETE retorna
  `Either<ErrorsResponse, bool>`, com `true` para 204 e `false` para outros 2xx.
- User não realiza autenticação ou leitura de sessão. `IUserLocalDataSource` e
  `UserLocalDataSource` ficam no mesmo arquivo em `infrastructure/local/`.
  A implementação recebe `IStorageClient` e delega `clear()`, propagando falhas.
  `UserRepository.delete` aguarda a exclusão remota e limpa o storage pelo data
  source local somente em `Right(true)` (status 204), antes de retornar sucesso.
  `Left` e `Right(false)` não acionam a limpeza; falha local retorna erro
  genérico. Dashboard consome `UserCommand` para preencher nome e semente do avatar.
- `UserRepository`, em `application/repositories/`, implementa `IUserRepository` por
  delegação a `IUserRemoteDataSource` e coordenação de `IUserLocalDataSource`, converte responses para entidades e
  traduz exceções inesperadas em `ErrorsEntity.unknown()`. Exclusão preserva
  o booleano devolvido pelo data source.
- `UserScreen` recebe `UserCommand`, em `presentation/screens/user/commands/`, para consultar
  `getById()` ao abrir e após atualizar o nome. Nome, e-mail e semente do avatar
  vêm da API. `CommandBuilder` renderiza skeleton, resultado e erro com tentativa
  de recarregamento. `UserScreenStateMixin` concentra carregamento e handlers de
  UI; a tela não acessa repository ou storage diretamente. `UserAvatarWidget`
  compõe `GeneratedUserAvatarWidget` com `flutter_boring_avatars`, estilo `marble`
  e paleta fixa dos tokens do tema claro. Dashboard reutiliza o mesmo desenho.
  Sem semente salva, use `cordato-user-<id>`, sem depender do nome.
- O refresh do avatar gera uma escolha temporária e reinicia um timer de dois
  segundos. Sem nova regeneração nesse prazo, a última seed é salva automaticamente
  por `UpdateAvatarCommand`, registrado por factory em `userRoutesModule` e descartado
  pela tela. Não há botão de salvamento. O timer é cancelado no descarte, na troca
  dos commands e ao confirmar exclusão. Falhas preservam a escolha e mostram erro,
  sem retries automáticos; regenerar agenda outra tentativa. Sucesso exige que a API devolva a semente
  enviada. O atributo HTTP é `avatar`; não simule
  persistência caso o atributo seja ignorado.
- User e Dashboard descartam `UserCommand`. Dashboard aguarda o retorno de User
  e Settings para recarregar nome e avatar, ignorando retornos obsoletos.

O sign-up aceita `name` e `avatar` opcionais nos contratos de repository e
data source. O repository delega sem normalização. O data source mantém
`Trocado` quando o nome é nulo e omite `avatar` quando nulo, preservando o
formulário atual de e-mail e senha. Não gere uma seed obrigatória para cadastro.
O atributo HTTP é `avatar`, e a confirmação da senha mantém o valor da senha.

## Imports

Para widgets Material, screens e temas, use:

```dart
import 'package:material_ui/material_ui.dart';
```

Não use `package:flutter/material.dart` em código novo de UI do projeto. O
`material_ui` é a superfície Material adotada pelo aplicativo e deve ser a
fonte de `Scaffold`, `Text`, `Theme`, botões, campos, ícones e similares.

Imports específicos do Flutter, como `package:flutter/physics.dart` para uma
simulação física, são permitidos quando o símbolo não é exportado por
`material_ui`.

Ordem preferida:

```dart
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/...';
```

Use imports explícitos e remova imports não utilizados. Não adicione barrel
files ou exports globais sem uma necessidade clara.

Imports de código da aplicação devem sempre usar o caminho completo com o
prefixo `package:cordato/`. Não use imports relativos entre arquivos de `lib/`.
Nos testes, imports de suporte em `test/support/` usam caminhos relativos
explícitos, pois esses arquivos não pertencem ao pacote de produção em `lib/`.

## Primary Constructors

O projeto exige Dart 3.13 ou superior e usa primary constructors sem experiment
flag ou dependência adicional. Essa é a forma padrão daqui para frente para todo
tipo novo que tenha um único construtor generativo principal e apenas armazene
parâmetros, derive campos a partir deles ou os encaminhe para `super`.

A migração base do projeto já foi concluída. Portanto, uma nova declaração
elegível deve nascer com primary constructor, e um construtor tradicional novo
ou mantido em código alterado precisa ter uma razão concreta de semântica,
lifecycle ou legibilidade. Não deixe boilerplate de campo mais atribuição para
uma conversão futura.

Estado imutável induzido pelo construtor deve usar tipo explícito e `final`.
Preserve `const` quando todos os campos permitirem construção constante e use
super parameters para encaminhamento direto:

```dart
final class const ExampleWidget({
  super.key,
  required final String label,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(label);
}
```

Parâmetros usados somente durante a inicialização devem manter o tipo explícito
sem `final` ou `var`, para não induzirem um campo:

```dart
final class NormalizedAmount(int amountInCents) {
  final int absoluteAmountInCents = amountInCents.abs();
}
```

Use esta matriz ao revisar uma declaração:

| Categoria | Exemplos | Decisão |
|---|---|---|
| Padrão obrigatório | Campos finais atribuídos diretamente, `super.key`, super parameters simples, payloads de enum, estado imutável e dependências apenas armazenadas | Use primary constructor |
| Revisão manual | Commands, initializer lists, asserts, corpos de construtor, construtores privados nomeados, campos `late`, subscriptions | Converta somente se semântica e legibilidade forem preservadas |
| Exceção sem benefício | Interfaces, mixins comuns, extensões, classes `State`, mocks e construtores explícitos ou implícitos vazios sem estado | Mantenha sem primary constructor explícito |

Factories e redirecting constructors permanecem no corpo da classe. Tipos com
múltiplos caminhos generativos não redirecionados e inicializações cuja ordem ou
lifecycle fique mais claro na forma tradicional devem manter o construtor
tradicional.

Widgets que apenas encaminham `super.key` também usam primary constructor. Em
commands, parâmetros usados somente para criar um `Command` devem continuar
transitórios, sem `final` ou `var`; não induza um campo de repository sem
necessidade. Construtores privados de entidades podem ser primary desde que nome,
visibilidade e factories validadoras permaneçam intactos.

Uma conversão deve preservar integralmente nome e visibilidade do construtor,
parâmetros nomeados e posicionais, ordem, tipos, nulabilidade, `required`, valores
padrão, constância, encaminhamento para `super`, factories, redirects, tear-offs
`Type.new` e comportamento observável. Não aproveite uma conversão sintática
para expor parâmetros, reescrever corpos ou alterar contratos.

Daqui para frente:

- use primary constructor em toda declaração nova elegível;
- preserve a sintaxe primary ao alterar declarações já migradas;
- converta qualquer construtor elegível que reapareça por merge ou código legado
  no arquivo já tocado;
- mantenha a forma tradicional somente com justificativa verificável pelas
  categorias acima;
- não combine a conversão sintática com mudanças de API ou comportamento.

## Widgets

### Convenções

- Widgets de apresentação devem ser pequenos e ter uma responsabilidade clara.
- Use `final class` para widgets novos que não foram feitos para herança.
- Use construtor `const` sempre que possível.
- Use `super.key` e parâmetros nomeados.
- Parâmetros obrigatórios devem ser `required`.
- Callbacks devem ser anuláveis quando `null` representa estado desabilitado.
- Use nomes com sufixo `Widget` para componentes compartilhados e widgets de
  feature, seguindo a convenção atual.
- Mantenha o nome do arquivo alinhado ao nome da classe. Arquivos antigos podem
  conter exceções, como `welcome_hero.dart` definindo `WelcomeIconWidget`; não
  replique essa inconsistência em código novo sem motivo.
- Não crie widgets privados, como `_AvatarWidget`, para extrair partes visuais.
  Quando uma parte visual precisar ser extraída, crie um widget público `final`
  com nome e arquivo próprios, seguindo o sufixo `Widget`.
- Prefira `build` curto e extraia métodos privados quando uma parte tiver uma
  responsabilidade visual ou comportamental própria.
- Não coloque acesso a clientes HTTP, storage ou regras de negócio dentro de um
  widget.

### Widgets compartilhados

Antes de criar um widget, procure em:

- `features/core/presentation/widgets/buttons`
- `features/core/presentation/widgets/fields`
- `features/core/presentation/widgets/images`
- `features/core/presentation/animations`
- `features/core/presentation/widgets/bounce_widget.dart`

Botões compartilhados atuais:

- `ElevatedButtonWidget`
- `OutlineButtonWidget`
- `DangerButtonWidget`
- `TextButtonWidget`
- `LinkButtonWidget`
- `IconButtonWidget`
- `HoldButtonWidget`

Use esses componentes em vez de estilizar `ElevatedButton`, `TextButton` ou
`IconButton` diretamente dentro de uma feature, salvo quando a tela realmente
precisar de uma variação específica.

Todos os botões que participam do padrão de interação devem reutilizar
`BounceWidget`. A animação compartilhada reproduz o hook RN
`use-press-bounce.ts`: escala `0.96` no press-in e retorna a `1.0` com spring,
preservando a velocidade atual.

### Imagens

Use `ImageWidget` quando a imagem precisar suportar asset, rede, fallback ou
loading. Informe `fit`, `alt`, tamanho e cor de forma explícita quando forem
relevantes para o layout.

Assets locais devem ser declarados no `pubspec.yaml`. O asset atual da marca é
`assets/images/logo.webp`.
Centralize caminhos e descrições de imagens locais em `AssetEnum`, em
`features/core/presentation/enums/asset_enum.dart`, usando `source` e `alt`.
O enum reúne a logo e as imagens de categorias. Features fazem a associação
dos seus dados ao enum na apresentação, sem montar ou repetir paths nos widgets.

## Widget Previews

Telas e widgets visuais podem ter previews usando o Widget Previewer nativo do
Flutter. Use sempre `@CordatoPreview`, definido em
`features/core/presentation/previews/preview.dart`, em vez de `@Preview`
diretamente. O wrapper compartilhado instala o tema real, localização `pt_BR` e
o provider de toast.

Previews de feature vivem em `presentation/previews/screens/` ou
`presentation/previews/widgets/`. Fakes exclusivos do catálogo ficam em
`presentation/previews/fakes/` e devem implementar contratos do domínio sem
acessar rede, storage ou plugins. Previews compartilhados ficam em
`features/core/presentation/previews/widgets/`.

- Use funções públicas top-level sem parâmetros, como exige o previewer.
- Informe `group`, `name` e um `size` adequado ao conteúdo.
- Use `cordatoPhonePreviewSize` para telas completas.
- Construa a estrutura real da tela ou widget, sem inicializar módulos ou o router.
- Use `PreviewResourceWidget` quando controllers ou commands precisarem de descarte.
- Não importe `mocktail` em previews; ele é dependência exclusiva de testes.
- Não crie dados financeiros com `double`; fixtures monetárias usam centavos inteiros.

Execute os previews com `dart run tool/widget_preview.dart` e abra a URL
impressa no navegador. O launcher contorna a descoberta inicial vazia observada
no Flutter 3.47.6 e 3.47.7, disparando uma atualização após a abertura do servidor.
Se o painel do editor abrir sem previews, use a ação de atualização do painel
após a análise inicial. O diretório gerado `.widget_preview/` é local e não deve
ser versionado.

## Screens

Screens são pontos de composição e integração da feature. Elas devem:

- Montar widgets de `presentation/widgets`.
- Receber callbacks de navegação ou dependências necessárias por construtor.
- Manter estado estritamente local quando ele pertence àquela tela.
- Criar e descartar controllers e subscriptions corretamente.
- Delegar operações assíncronas para commands.
- Não conhecer detalhes de clientes HTTP ou implementações de storage.

### Mixins De Estado De UI

Quando uma screen ou formulário `StatefulWidget` acumular estado efêmero,
lifecycle e handlers de UI suficientes para prejudicar a leitura do `build`,
extraia-os para um mixin restrito ao widget em `presentation/mixins/` ou no
diretório da tela. O mixin deve declarar `on State<Widget>` para tornar seu
acoplamento explícito.

O mixin pode possuir controllers, timers, listeners de commands, validação de
entrada, loading local, feedback visual e os métodos `initState` e `dispose`.
Ele deve descartar todo recurso que criar. A screen deve manter somente a
composição visual e repassar os membros públicos do mixin aos widgets.

Métodos auxiliares de `State` e mixins restritos a `State<Widget>` devem usar
o getter `context` do próprio estado, sem receber ou repassar `BuildContext`
redundante. Preserve parâmetros de contexto exigidos por overrides do Flutter,
callbacks de navegação e operações que precisem de um contexto de outro escopo,
como o contexto do Navigator ou de um builder descendente.

Não use mixins de estado em `StatelessWidget`; para lógica de apresentação sem
estado, siga o padrão abaixo. Não crie mixins genéricos, nem mova
regras de domínio, acesso a repositórios, data sources, storage ou SDKs para um
mixin de UI.

### Mixins De Lógica De Apresentação Sem Estado

Quando um `StatelessWidget` precisar isolar cálculos e decisões de apresentação,
extraia essa lógica para um mixin específico chamado `<Widget>Mixin`, em
`presentation/mixins/<widget>_mixin.dart` da feature. Declare `on StatelessWidget`
e aplique-o somente ao widget proprietário com `with <Widget>Mixin`.

- Mantenha o widget como `StatelessWidget`, com composição visual no `build` e
  nos métodos ou widgets de layout existentes.
- O mixin expõe métodos e getters necessários à composição; helpers internos
  permanecem privados. Receba os dados necessários por parâmetro ou use membros
  imutáveis declarados por contrato, sem duplicar os dados do widget.
- Não armazene estado mutável, controllers, subscriptions, timers ou recursos
  que precisem de descarte. Não implemente lifecycle nem operações assíncronas.
- Isole apenas lógica de apresentação, como iniciais, saudações, rótulos e
  condições visuais. Regras de negócio continuam no domínio; repositories,
  data sources, storage e SDKs não pertencem ao mixin.
- Não crie um mixin genérico para widgets não relacionados nem converta o
  widget para `StatefulWidget` apenas para extrair lógica.

Padrão de callback de navegação:

```dart
final ValueChanged<BuildContext> onContinueWithEmail;
```

Quando esse contrato já existir, preserve-o. A rota injeta a navegação usando o
`BuildContext` recebido; a screen não deve importar ou chamar o router global
diretamente para resolver navegação.

Uma screen normalmente usa `Scaffold` e `SafeArea`. Não defina manualmente uma
cor de fundo se o comportamento desejado for o tema do aplicativo; deixe o
`Scaffold` herdar `ThemeData.scaffoldBackgroundColor`.

## Tema

O tema é definido em:

- `lib/features/core/presentation/themes/themes.dart`
- `lib/features/core/presentation/themes/color_theme.dart`
- `lib/features/core/presentation/themes/radius_theme.dart`
- `lib/features/core/presentation/extensions/context_extension.dart`

Use as extensões existentes:

```dart
context.colors
context.typography
context.radius
context.isDark
```

### Cores

`context.colors` retorna o `ColorScheme` ativo. Prefira seus papéis semânticos:

- `primary` e `onPrimary`
- `onSurface` e `onSurfaceVariant`
- `surface` e containers semânticos
- `error` e `onError`
- `tertiaryContainer` e `onTertiaryContainer` quando apropriado

Não crie uma extensão paralela apenas para buscar cores já disponíveis em
`context.colors`. `AppColors` existe como `ThemeExtension` registrada no tema,
mas o acesso padrão atual da aplicação é `ColorScheme` através de
`context.colors`.

### Tipografia

Use `context.typography` como base. Quando uma tela precisa ser fiel a uma
especificação visual, derive o estilo existente com `copyWith`, sem criar uma
nova extensão:

```dart
style: context.typography.headlineMedium?.copyWith(
  color: context.colors.onSurface,
  fontSize: 32.0,
  fontWeight: .w600,
  height: 38.0 / 32.0,
  letterSpacing: -0.6,
),
```

Use a variante semântica mais próxima (`headlineMedium`, `headlineSmall`,
`bodySmall`, etc.) antes de sobrescrever propriedades.

### Raios e dimensões

Use `context.radius` para raios compartilhados. Essa extensão depende de
`CornerRadiusToken` estar registrado por `Themes.light` ou `Themes.dark`.
Widgets testados com `MaterialApp` puro podem falhar se não instalarem esse
tema; previews devem instalar o tema completo pelo wrapper compartilhado.
Não crie testes Flutter de widgets para esse fim.

Tokens de raio atuais incluem `cornerRadius050`, `100`, `300`, `500`, `700` e
`Full`. Dimensões que são específicas de uma tela podem permanecer locais, mas
tokens repetidos devem ser centralizados antes de serem copiados.

## Estado

### Estado local

Use `StatefulWidget` e `setState` para estado efêmero de uma tela ou widget:

- valor de campo e erro de validação;
- estado de animação;
- índice de uma apresentação local;
- controller pertencente ao widget.

Descarte `TextEditingController`, `AnimationController`, `Timer` e listeners em
`dispose`.

### Commands

Operações assíncronas da apresentação devem ser encapsuladas em commands usando
`command_it`. Commands implementam `ICommand` quando precisam ser descartados
pelo ciclo de vida do módulo.

Expense organiza commands, mixins e validators sob a tela proprietária em
`presentation/screens/expense/` ou `presentation/screens/expenses/`.
O uso de `GetExpensesCommand` pela Dashboard não muda sua localização em
`screens/expenses/commands/` nem seu registro por factory nas dependências de Expense.

Coloque cada command específico de uma tela em
`presentation/screens/<screen>/commands/<nome>_command.dart`; espelhe esse
caminho no teste. Quando o command representar o fluxo principal da tela, use o
mesmo nome-base: `CallbackScreen` → `callback/commands/callback_command.dart` →
`CallbackCommand`. Se representar uma operação específica, prefira o nome da
ação. Commands sem tela proprietária dentro da própria feature ficam em
`presentation/commands/`: `SessionCommand` em `session` e `LogoutCommand` em
`authentication`, ainda que Settings consuma o logout. `ResendEmailScreen` e
`ResendEmailCommand` ficam em `screens/resend_email/`; a rota permanece
`/authentication/confirm`. Ao renomear uma tela ou um command, atualize classe,
arquivo, imports, registro no módulo, testes e documentação na mesma alteração; preserve as
rotas e o comportamento quando a mudança for somente de nomenclatura.

O sign-in mantém `Either` no resultado do command para a apresentação decidir
como exibir erros da API:

```dart
final class SignInCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<
    ({String email, String password}),
    Either<ErrorsEntity, SessionEntity>?
  > execute = Command.createAsync<
    ({String email, String password}),
    Either<ErrorsEntity, SessionEntity>?
  >(
    initialValue: null,
    (credentials) => repository.signIn(
      email: credentials.email,
      password: credentials.password,
    ),
  );

  @override
  void dispose() => execute.dispose();
}
```

Na screen, use `CommandBuilder` para renderizar estados de execução e resultado;
trate `Left` como resultado quando o command retornar `Either`. Não faça
`try/catch` da operação diretamente no `build`.

### Gerenciamento global

O projeto não usa Bloc, Provider, Riverpod ou store global no código atual. Não
adicione um desses padrões por hábito. Primeiro verifique se o estado pertence
à screen, a um command ou a um repositório.

## Arquitetura Em Camadas

Novas features devem preferir:

```text
feature/
  domain/
  application/
    data/
    repositories/
  infrastructure/
  presentation/
```

Regras de dependência:

- `domain` define contratos, failures e regras independentes de framework.
- O contrato `IExpenseRepository` recebe parâmetros nomeados diretamente em
  `create({required int cents, required String description, DateTime? occurredOn})`.
  Centavos inteiros e descrição são obrigatórios e não nulos. A descrição de
  `ExpenseEntity` também é obrigatória e não nula. O repository delega os
  parâmetros sem normalização; o data source usa `DateTime.now()` quando a data
  civil é omitida ou nula. Não há wrapper de input de criação. O método retorna
  `Future<CreateRepositoryType>`, com `Either<ErrorsEntity, ExpenseEntity>`.
- `ExpenseEntity.cents` usa `AmountValueObject` de
  `expense/domain/value_objects/`. O VO pertence somente ao domínio;
  O parâmetro `cents` transporta centavos como `int`, sem validação de
  domínio. A criação do VO retorna `Either` com
  `ErrorsEntity` para centavos menores ou iguais a zero. Valores positivos são
  armazenados no campo imutável `cents`, sem conversão ou arredondamento, com
  igualdade por valor. O data source envia `cents` no atributo `amount`;
  `ExpenseResponse.toEntity()` retorna `Either<ErrorsEntity, ExpenseEntity>` e
  valida os centavos recebidos pelo VO antes de construir a entidade.
- `application/repositories` implementa contratos de repository do domínio e traduz respostas de
  data sources; na autenticação atual, consome as interfaces remota/local e os
  response DTOs definidos em `infrastructure`.
- `infrastructure` define as interfaces de data source e acessa rede, storage,
  plugins e APIs externas; o data source remoto de autenticação usa `IHttpClient`
  do core diretamente.
- `presentation` contém screens, widgets e commands; não acessa clientes
  externos diretamente.
- `presentation` depende de contratos de `domain`; o repository em `application/repositories`
  depende das interfaces de data source de `infrastructure`, sem acessar SDKs
  diretamente. O módulo liga as implementações concretas.
- A rota e o módulo pertencem à feature que possui a tela; a rota inicial `/`
  é composição do app em `app_module.dart`.

Direções aprovadas entre features:

- `authentication` e `session` não importam uma à outra; comunicam-se pela
  escrita e observação da mesma chave no storage do core.
- Settings consome `LogoutCommand` de Authentication; o command conhece apenas
  `IAuthenticationRepository`, sem adapters na UI de Settings.
- `expense` e `budget` não dependem de outros contextos financeiros.
- Quando implementadas, `family` lê `expense`/`budget` por contratos próprios,
  com adapters em infrastructure; `insight` pode ler os três pelo mesmo padrão.
- Contextos proprietários não dependem de `family` ou `insight`.

Fluxo esperado:

```text
Screen/Widget
    -> Command
    -> Domain repository interface
    -> Application repository
    -> Data source interface
    -> Data source (authentication: IHttpClient do core diretamente)
    -> External service
```

Na autenticação, `AuthenticationRemoteDataSource` monta as requisições JSON:API
e chama `IHttpClient` do core, sem `AuthenticationClient` intermediário. Os
responses de sign-in e sign-up convertem mapas com casts e `DateTime.parse` do
Dart; o data source traduz falhas de parsing em `ErrorsResponse` genérico.
Outras features podem ter clients próprios quando isso fizer sentido.

## API HTTP E Persistência

`coreDependenciesModule` registra `IStorageClient`, `IHttpClient` e o `Dio` compartilhado
com `BASE_URL` (padrão `https://app.cordato.cloud/api/`). O
`HeadersInterceptor` aplica os headers JSON:API. O `HttpClient` devolve
`Either<HttpResponse, HttpResponse>`, com status HTTP e corpo em mapa;
falhas de transporte recebem status `0`. `AuthenticationRemoteDataSource`
converte os corpos em respostas tipadas e erros JSON:API. Os endpoints
relativos à base preservam o prefixo `/api/`.

Data sources que retornam `Either<ErrorsResponse, T>` reutilizam `response<T>`
de `core/infrastructure/clients/http/responses/responses.dart`. Informe
`execute` para executar a requisição e `from` para converter o `HttpResponse`
de sucesso, usando seu corpo ou status. A função preserva erros JSON:API e
converte exceções inesperadas em erro genérico.

O sign-in usa e-mail e senha. No sucesso, `AuthenticationRepository` solicita a
`IAuthenticationLocalDataSource` que grave token e ID via `saveToken` e
`saveUserId`, usando `IStorageClient`. O repository aguarda ambas as gravações
com `Future.wait`; falha de gravação impede o retorno de sucesso. As chaves são
`StorageKeyEnum.opaqueToken` (`@trocado.opaque_token`) e `StorageKeyEnum.userId`
(`@trocado.user_id`). O token é usado também pelo `SessionInterceptor`.
O logout aceito remotamente chama `clear()` para limpar todo o storage seguro.
Um 401 de endpoint protegido remove somente o token enviado, preservando o ID.
`HttpPathEnum.authenticated` marca
endpoints protegidos. Os data sources usam `Requests(path: ...)`, com caminhos
obtidos do enum e ids interpolados com `Uri.encodeComponent`. Requests possui
somente `path`, `body`, `query` e `headers`. O interceptor identifica os endpoints
protegidos pelo caminho na origem/base da API e envia
`Authorization: Bearer <token>`. URLs absolutas não recebem token. O token é
opaco; `Bearer` é o esquema HTTP, e a validade do token é controlada pelo backend. Um 401 dessa
requisição remove somente o token enviado, se ainda for o valor armazenado;
requisições públicas não apagam a sessão. `expenses` está
no catálogo de caminhos protegidos e é usado pelo data source remoto de criação
de Expense, integrado ao formulário, e de consulta, consumido pela Dashboard
e pela listagem paginada.
O sucesso do sign-in notifica `SessionCommand` e conduz ao dashboard.

`Requests.path` é uma `String` obrigatória nomeada. Caminhos fixos usam
`Requests(path: HttpPathEnum.signIn.path)`; User usa
`Requests(path: '${HttpPathEnum.user.path}/${Uri.encodeComponent(id)}')`.
`HttpPathEnum.user.path` contém somente `users`, sem placeholder de ID.
Não adicione factory `forPath`, campo `route` ou flags `logRequest` e
`followRedirects` a Requests; autenticação e política de URLs absolutas são
responsabilidades do interceptor e do cliente HTTP.

Sign-up e reenvio usam endpoints públicos. Para confirmar e-mail, a URL
assinada recebida no deep link é enviada sem reconstrução por `IHttpClient.get`,
sem Bearer; uma URL ausente é tratada na
screen. O repository traduz os status 204, 403 e falha de transporte, sem
validar host, caminho ou assinatura localmente. O comando de confirmação
recebe uma `String` não nula; nenhum desses fluxos cria sessão.

O logger HTTP está ativo apenas em debug e atualmente registra headers e
payloads das requisições, inclusive dados de sign-in e URLs absolutas, como a
confirmação assinada. O cliente HTTP atual não configura uma política específica
de redirecionamentos ou logging para URLs absolutas.

O formulário de gastos executa criação por `CreateExpenseCommand`,
`ExpenseRepository` e data source remoto. Insight consulta a API e apresenta
cards somente leitura na Dashboard. `budget` e `family` não possuem integração Flutter. Não descreva
regras de autorização do backend como já aplicadas pelo aplicativo. Ao conectar
uma feature financeira, defina seu contexto proprietário, preserve as
invariantes no serviço responsável e adicione testes de autorização e domínio.

## Módulos, DI E Rotas

Use a API funcional do `flutter_modular` 7:

```dart
final featureDependenciesModule = createModule(
  register: (context) => context
    ..addLazySingleton<IRepository>(Repository.new),
);

final featureRoutesModule = createModule(
  path: '/feature',
  register: (context) {
    context
      ..route(
        '/',
        child: (_, _) => const FeatureScreen(),
      );
  },
);
```

Regras:

- Quando uma feature precisar de registros de DI ou rotas, declare seu módulo
  em `<feature>_module.dart`; não crie módulo vazio para padronizar a estrutura.
- Separe `<feature>DependenciesModule`, sem `path`, de
  `<feature>RoutesModule` quando houver dependências compartilhadas e rotas.
- `app_module.dart` compõe módulos de alto nível e registra `AppScreen` em `/`.
  Atualmente os módulos root de dependências são `core`, `user`, `session`, `expense`, `insight` e
  `authentication`; `welcome`, `expense`, `settings`, `dashboard` e
  `authentication` fornecem módulos de rotas.
- Dependências estritamente locais, como validators de Expense e o registro
  de `LogoutCommand` em Settings, podem ficar no módulo de rotas proprietário.
- Use `addInstance` para objetos já criados e `addSingleton` ou
  `addLazySingleton` conforme o ciclo de vida necessário.
- Registre interfaces apontando para implementações concretas.
- Resolva dependências por `inject<T>()` dentro do builder quando esse for o
  padrão da rota, ou injete-as explicitamente pelo construtor.
- Use extensões de `BuildContext` do Modular para navegação, principalmente
  `context.pushNamed`, `context.navigate`, `context.replace` e `context.pop`.
- Não use a API global antiga `Modular.to` no Modular 7.

Rotas atuais:

- `/` para `AppScreen`, leitura da sessão e rota inicial padrão; não há `/splash`.
- `/welcome` para a tela de boas-vindas quando não há token.
- `/authentication/sign-in` para entrada por e-mail e senha.
- `/authentication/sign-up` para cadastro.
- `/authentication/confirm` para espera e reenvio da verificação.
- `/authentication/confirm-email` para confirmação pelo link recebido.
- `/dashboard` para a tela inicial de dashboard, ainda sem guard de sessão.
- `/settings` para configurações.
- `/user` para consulta dos dados pessoais e exclusão da conta.
- `/user/edit` para atualização do nome.
- `/expense` para `ExpenseScreen`, cadastro sem ID e edição com ID por argumento.
- `/expenses` para `ExpensesScreen`, a listagem completa com rolagem infinita.

`RouteEnum.authenticatedPaths()` inclui Dashboard, Settings, User, edição de User,
cadastro de Expense e listagem de Expenses. A flag
`authenticated` classifica rotas; não instala um guard. `AppWidget` encaminha
uma abertura inicial nessas rotas para `/` e reage à perda de token enquanto
elas estiverem ativas. Não confunda isso com autorização do backend.

## Erros E Falhas

O padrão atual separa resultado de negócio de exceção:

- infraestrutura retorna resultado simples ou captura exceções externas;
- repository converte o resultado em `Either<Failure, R>`;
- presentation trata `Left` como resultado ou o transforma em erro observável
  quando necessário;
- `CommandBuilder` renderiza estados de execução e erro do command.

Use failures tipadas e mensagens localizadas no domínio. Não exponha exceções
de SDK diretamente na UI.

## Testes

Cada mudança nas camadas testadas deve incluir ou atualizar testes na camada
correspondente.

- `domain`: testes unitários puros para regras, `Either` e failures.
- `application`: testes de inputs puros em `data/` e testes de repositories com
  mocks de data source e mapeamento para `Either` em `repositories/`.
- `infrastructure`: mocks dos SDKs e testes de delegação/resultado.
- `presentation/commands`: sucesso, erro e descarte do command.
- `architecture`: dependências entre bounded contexts e isolamento das camadas.

Não crie nem mantenha testes Flutter automatizados para widgets, screens, tema
e seus derivados, ou módulos e rotas do `flutter_modular`. A validação visual,
de interação e de fluxos completos dessas camadas será feita com Maestro.

Use `mocktail`. Dê nomes aos testes pelo comportamento observável, não pelo
método privado.

Mocks, fakes e adapters de teste ficam em arquivos próprios sob
`test/support/<feature>/mocks/` ou `test/support/<feature>/fakes/`. Use tipos
públicos com nomes específicos do contrato, como `AuthenticationRepositoryMock`,
sem declarar classes auxiliares dentro de arquivos `*_test.dart`. Reutilize
o mesmo double para cada contrato; doubles de core podem servir várias features.
Não coloque suporte de testes em `lib/` nem importe `mocktail` na aplicação.

`HttpClientAdapterFake`, em `test/support/core/fakes/`, implementa o adapter de
Dio com o callback `respond`, permitindo controlar respostas e exceções sem
rede. Instâncias, stubs, fixtures de cenário e descarte continuam locais aos
testes, em `setUp`, `tearDown` ou no próprio cenário; não compartilhe mocks
mutáveis ou configurações globais entre suítes. Cada double ocupa um arquivo,
sem barrel file para agrupar exports.

Toda subscription criada em teste deve ser removida e todo command criado
manualmente deve ser descartado no `tearDown`.

## Verificação

Execute, nesta ordem, quando aplicável:

```bash
flutter pub get
flutter analyze
flutter test
```

Para validar rapidamente os limites arquiteturais:

```bash
flutter test test/architecture
```

Para executar o app, use `flutter run`. A URL base da API de autenticação pode
ser substituída quando necessário:

```bash
flutter run --dart-define=BASE_URL=https://api.exemplo.com/api/
```

O padrão de `BASE_URL` é `https://app.cordato.cloud/api/`. A configuração e
verificação de release Android estão em `android/README.md`.

## Checklist De Pull Request

- A feature respeita as camadas e não acessa SDK na apresentação.
- Novos widgets usam `material_ui` e os componentes compartilhados existentes.
- Cores, fontes e raios vêm do tema existente.
- Controllers, timers, animations e commands são descartados.
- Rotas e bindings estão no módulo correto.
- Testes foram adicionados ou atualizados na camada afetada.
- `flutter analyze` foi executado.
- `flutter test` foi executado e qualquer falha não relacionada foi registrada.
- Nenhuma extensão, token ou abstração duplicada foi criada.
- Nenhum comentário foi adicionado ao código; explicações e decisões ficam em Markdown.
- Mudanças em módulos, rotas, contratos ou comandos atualizaram `ARCHITECTURE.md`.
- Mudanças de integração HTTP ou contratos de autenticação atualizaram `ARCHITECTURE.md`.
- Mudanças de release Android atualizaram `android/README.md`.
- O `README.md` foi revisado quando o estado do produto, configuração ou início rápido mudou.

## Pendências Conhecidas

Estas situações existem hoje e não devem ser silenciosamente reinterpretadas
como padrão novo:

- Há imports antigos de `flutter/material.dart` em alguns widgets de imagem e
  infraestrutura de apresentação; código novo deve usar `material_ui`.
- `listen_it` está declarado sem uso direto na aplicação.
- Não existe suíte `integration_test`.
- Há um flow legado de Welcome/Authentication em `maestro/`, ainda com textos
  anteriores ao sign-in atual; a política de validação com Maestro não representa
  cobertura automatizada completa dos fluxos atuais.
- Expense ainda importa `AmountFieldWidget` e `DateFieldWidget` de
  `authentication/presentation/widgets/`; essa localização legada não é uma
  convenção para novos componentes compartilhados.
- O teste arquitetural ainda contém referências históricas a Supabase/RPC.
  Seu helper identifica apenas contextos financeiros, deixando a verificação
  de imports entre Authentication e Session sem cobertura efetiva.
  Não descreva esses checks como garantias completas da arquitetura atual.
  As listas de SDKs proibidos não incluem Dio.
- O teste de `ResendEmailCommand` ainda está no caminho antigo
  `screens/resend_email_verification/`, embora importe a implementação nova.
