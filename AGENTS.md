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
  source remoto, implementação de repository e módulo de dependências, sem apresentação.
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
formulário, validators e estado de apresentação. Também possui `CreateExpenseInput`
em `application/data/`, o contrato `IExpenseRepository.create`, `ExpenseResponse`
e data source HTTP de criação, além de `CreateExpenseCommand` em
`presentation/screens/expense/commands/`, sem implementação de repository.
O command delega o input a `IExpenseRepository.create`, preserva `Either` e
implementa `ICommand`. Command e data source ainda não estão registrados em DI
nem conectados ao formulário.
Dashboard consulta nome e inicial do avatar por `UserCommand` e mantém conteúdo financeiro placeholder.
`budget`, `family` e `insight` não têm feature Flutter
implementada. Não descreva recursos planejados como código existente nem crie
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
- `dio` para integração HTTP JSON:API de Authentication, User e Expense.
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
      domain/
        entities/user_entity.dart
        repositories/interface_user_repository.dart
      infrastructure/
        remoto/user_remote_data_source.dart
        responses/user_response.dart
    <feature>/
      <feature>_module.dart
      domain/
      data/
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
`IUserRepository` como lazy singletons e composto por `appModule`.

### Contexto User

- `UserEntity` é imutável, com `id`, `name`, `email` e `status` como `String` e
  `createdAt` como `DateTime`. Não inclui `updatedAt`, `type` ou `links`.
- `status` preserva o valor textual da API; não invente estados de enum sem
  contrato definido.
- `IUserRepository` define `getById()`, `delete()` e `update({String? name})`.
  As três operações leem o ID persistido por `IUserLocalDataSource.getUserId()`;
  ID ausente ou vazio retorna erro sem chamada remota. O data source remoto
  continua recebendo o ID explicitamente.
  Os resultados usam typedefs `Either<ErrorsEntity, UserEntity>` para consulta
  e atualização e `Either<ErrorsEntity, bool>` para exclusão.
- Atualização permite somente `name`, omitido do payload quando nulo. Não
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
  genérico. Dashboard consome `UserCommand` para preencher nome e inicial do avatar.
- `UserRepository`, em `data/repositories/`, implementa `IUserRepository` por
  delegação a `IUserRemoteDataSource` e coordenação de `IUserLocalDataSource`, converte responses para entidades e
  traduz exceções inesperadas em `ErrorsEntity.unknown()`. Exclusão preserva
  o booleano devolvido pelo data source.
- `UserScreen` recebe `UserCommand`, em `user/commands/`, para consultar
  `getById()` ao abrir e após atualizar o nome. Nome, e-mail e inicial do avatar
  vêm da API. `CommandBuilder` renderiza skeleton, resultado e erro com tentativa
  de recarregamento. `UserScreenStateMixin` concentra carregamento e handlers de
  UI; a tela não acessa repository ou storage diretamente. `UserAvatarWidget`
  exibe somente a inicial, sem receber imagem externa.

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

Execute os previews com `flutter widget-preview start`. O diretório gerado
`.widget_preview/` é local e não deve ser versionado.

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
  data/
  infrastructure/
  presentation/
```

Regras de dependência:

- `domain` define contratos, failures e regras independentes de framework.
- O contrato `IExpenseRepository` pode importar `CreateExpenseInput` de
  `expense/application/data/`, por decisão arquitetural. O input é um tipo Dart
  puro, imutável, com `cents` como `int` em centavos e `description` como `String`,
  ambos obrigatórios e não nulos. A descrição de `ExpenseEntity` também é
  obrigatória e não nula.
  `occurredOn` é opcional na construção, com `DateTime.now()` quando omitido ou
  nulo, e o campo não nulo representa a data civil do gasto. O construtor não é
  `const`; o input não faz parsing ou serialização JSON.
  `create({required CreateExpenseInput input})` retorna
  `Future<CreateRepositoryType>`, com `Either<ErrorsEntity, ExpenseEntity>`.
- `ExpenseEntity.cents` usa `AmountValueObject` de
  `expense/domain/value_objects/`. O VO pertence somente ao domínio;
  `CreateExpenseInput.cents` transporta centavos como `int`, sem validação de
  domínio. A criação do VO retorna `Either` com
  `ErrorsEntity` para centavos menores ou iguais a zero. Valores positivos são
  armazenados no campo imutável `cents`, sem conversão ou arredondamento, com
  igualdade por valor. O data source envia `input.cents` no atributo `amount`;
  `ExpenseResponse.toEntity()` retorna `Either<ErrorsEntity, ExpenseEntity>` e
  valida os centavos recebidos pelo VO antes de construir a entidade.
- `data` implementa contratos de repository do domínio e traduz respostas de
  data sources; na autenticação atual, consome as interfaces remota/local e os
  response DTOs definidos em `infrastructure`.
- `infrastructure` define as interfaces de data source e acessa rede, storage,
  plugins e APIs externas; o data source remoto de autenticação usa `IHttpClient`
  do core diretamente.
- `presentation` contém screens, widgets e commands; não acessa clientes
  externos diretamente.
- `presentation` depende de contratos de `domain`; o repository em `data`
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
    -> Data repository
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
com `BASE_URL` (padrão `https://api.cordato.cloud/api/`). O
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
de Expense, ainda sem integração com o formulário.
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
sem Bearer, redirecionamentos ou logging da URL; uma URL ausente é tratada na
screen. O repository traduz os status 204, 403 e falha de transporte, sem
validar host, caminho ou assinatura localmente. O comando de confirmação
recebe uma `String` não nula; nenhum desses fluxos cria sessão.

O logger HTTP está ativo apenas em debug e atualmente registra headers e
payloads das requisições usuais, inclusive dados de sign-in. Para caminhos que
são URLs absolutas, como a confirmação assinada, o cliente HTTP desabilita
redirecionamentos e logging de request, response e error automaticamente.

O formulário de gastos ainda não executa criação: seus handlers são placeholders
e o botão está desabilitado em loading fixo. `budget`,
`family` e `insight` não possuem integração Flutter. Não descreva
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
  Atualmente os módulos root de dependências são `core`, `user`, `session` e
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
- `/expense` para o formulário de gasto.

`RouteEnum.authenticatedPaths()` lista Dashboard, Settings e Expense. A flag
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
- `data`: mocks de data source e testes de mapeamento para `Either`.
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

O padrão de `BASE_URL` é `https://api.cordato.cloud/api/`. A configuração e
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
- Não há flows Maestro versionados; a política de validação com Maestro não
  representa cobertura automatizada já implementada.
- `ExpenseFormWidget` cria um `TextEditingController` no `build`, sem descarte;
  o formulário atual é um placeholder, não um exemplo de lifecycle aprovado.
- Expense ainda importa `AmountFieldWidget` e `DateFieldWidget` de
  `authentication/presentation/widgets/`; essa localização legada não é uma
  convenção para novos componentes compartilhados.
- O teste arquitetural ainda contém referências históricas a Supabase/RPC.
  Seu helper identifica apenas contextos financeiros, deixando a verificação
  de imports entre Authentication e Session sem cobertura efetiva.
  Não descreva esses checks como garantias completas da arquitetura atual.
  O check de import de presentation em `data` também é ignorado pelo filtro
  atual, e as listas de SDKs proibidos não incluem Dio.
- O teste de `ResendEmailCommand` ainda está no caminho antigo
  `screens/resend_email_verification/`, embora importe a implementação nova.
