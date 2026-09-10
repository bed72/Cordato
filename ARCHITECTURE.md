# Arquitetura

## Visão Geral

Cordato é um aplicativo Flutter de finanças pessoais organizado por feature e
por camadas. Cada pessoa é dona dos próprios dados financeiros; o casal é uma
lente de leitura compartilhada, nunca um dono de dinheiro.

O backend original em Kotlin definiu o modelo de domínio. Ele foi migrado para
o Supabase, mas suas regras de negócio continuam sendo a referência para as
features que serão implementadas no app. A apresentação permanece independente
de Supabase, storage e plugins, permitindo testar regras e integrações com
doubles.

```text
                 +----------------------+
                 |      Flutter UI       |
                 | screens / widgets     |
                 +-----------+----------+
                             |
                 +-----------v----------+
                 |      Presentation     |
                 | commands / state     |
                 +-----------+----------+
                             |
                 +-----------v----------+
                 |        Domain         |
                 | interfaces / Either  |
                 +-----------+----------+
                             |
                 +-----------v----------+
                 |          Data         |
                 | repositories / map    |
                 +-----------+----------+
                             |
                 +-----------v----------+
                 |   Infrastructure      |
                 | data sources / SDKs   |
                 +----------------------+
```

A regra principal é que a UI conhece contratos, não detalhes de integração.
Uma screen pode conhecer um command e um command pode conhecer uma interface de
repositório. Nenhuma screen deve chamar `SupabaseClient`, `FlutterSecureStorage`
ou um cliente de rede diretamente.

## Produto E Bounded Contexts

Os contextos financeiros são isolados e devem ser implementados em features
próprias:

- `expense`: registra fatos atômicos de gastos pertencentes a uma pessoa.
- `budget`: registra tetos planejados por intervalo de datas; gasto e saldo são derivados.
- `couple`: conecta duas pessoas e compõe leituras combinadas, sem conceder escrita nos dados do outro.
- `insight`: calcula análises derivadas, somente leitura e sem persistência própria.

`dashboard` é uma feature de apresentação e composição, não um bounded context
de negócio. `authentication` encapsula o Supabase Auth e o magic link. O
contexto `identity` do backend não deve ser recriado no app neste momento, e o
contexto `chat` está fora do escopo atual.

As regras transversais mais importantes são:

- dinheiro somente em centavos inteiros e BRL;
- um gasto nunca possui referência a um orçamento; a associação é derivada pela data;
- orçamentos vivos da mesma pessoa não podem compartilhar nenhum dia;
- visões de casal e insights são recompostas a partir dos dados proprietários, nunca persistidas;
- dissolver um casal preserva integralmente os dados individuais.

As dependências entre contextos apontam para quem possui os dados: `couple`
consome `budget` e `expense` para leitura, e `insight` consome `budget`,
`expense` e `couple`. Os contextos proprietários nunca dependem das lentes.

## Estrutura De Diretórios

```text
lib/
  main.dart
  app_module.dart
  app_widget.dart
  features/
    core/
      core_module.dart
      domain/
        either.dart
      infrastructure/
        clients/
      presentation/
        animations/
        commands/
        extensions/
        previews/
        themes/
        widgets/
    authentication/
      authentication_module.dart
      domain/
        failures/
        repositories/
      data/
        repositories/
      infrastructure/
        clients/
        remoto/
      presentation/
        commands/
        screens/
        widgets/
    welcome/
      welcome_module.dart
      presentation/
        screens/
        widgets/
    dashboard/
      dashboard_module.dart
      domain/
      data/
      infrastructure/
      presentation/
        commands/
        screens/
        widgets/
    expense/                  # bounded context futuro
    budget/                   # bounded context futuro
    couple/                   # bounded context futuro
    insight/                  # bounded context futuro
```

O diretório `core` é compartilhado. Ele não deve virar um depósito de código de
feature. Se uma classe só serve a uma feature, ela deve permanecer na feature.

## Inicialização Do Aplicativo

O fluxo de bootstrap é:

```text
main.dart
  -> WidgetsFlutterBinding.ensureInitialized()
  -> SupabaseClient.ensureInitialized()
  -> ModularApp(module: appModule, initialRoute: /welcome)
  -> AppWidget
  -> SessionGuardWidget(session do Supabase)
  -> MaterialApp.router
```

Arquivos envolvidos:

- `main.dart` inicializa Flutter e Supabase.
- `app_module.dart` registra os módulos de aplicação.
- `app_widget.dart` configura título, temas e `ModularApp.routerConfigOf`.
- `welcome_module.dart` fornece a tela inicial para pessoas sem sessão.
- `authentication_module.dart` fornece o fluxo de magic link.
- `dashboard_module.dart` fornece a tela inicial para pessoas autenticadas.

O startup falha com `StateError` quando `SUPABASE_URL` ou
`SUPABASE_ANON_KEY` não são fornecidos. Essa configuração é obrigatória no
runtime:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=...
```

O redirect pode ser substituído com `SUPABASE_REDIRECT_URL`; o módulo de
autenticação possui `trocado://authentication/callback` como default legado.

## Módulos E Injeção De Dependências

O projeto usa a API funcional do `flutter_modular` 7. Módulos declaram um
`path`, registram dependências e declaram suas rotas.

### Composição Da Aplicação

`app_module.dart` compõe:

```text
appModule
  +-- coreModule
  +-- welcomeModule
  +-- authenticationModule
  +-- dashboardModule
```

O módulo de aplicação não deve conter regras de uma feature. Ele apenas conecta
os módulos de alto nível.

### Core

`coreModule` registra:

- `IStorageClient` como singleton de `StorageClient`.
- `FlutterSecureStorage` como instância.

### Authentication

`authenticationModule` registra:

- redirect URL como `String`;
- `SupabaseClient` já inicializado;
- `LocalStorage` com `SupabaseStorageClient`;
- `IAuthenticationClient` com `SupabaseAuthenticationClient`;
- `IAuthenticationDataSource` com `AuthenticationDataSource`;
- `IAuthenticationRepository` com `AuthenticationRepository`;
- `MagicLinkCommand` como lazy singleton;
- rotas `/authentication/magic-link` e `/callback`.

### Dashboard

`dashboardModule` registra o acesso aos dados básicos do usuário, seu
repositório e `GetUserNameCommand`, além da rota `/dashboard/`. O dashboard
atual é apenas uma composição inicial; ele não deve concentrar regras dos
bounded contexts financeiros.

Use interfaces nos bindings sempre que a camada consumidora depender de uma
abstração:

```dart
context
  ..addLazySingleton<IAuthenticationRepository>(
    AuthenticationRepository.new,
  )
  ..addLazySingleton<MagicLinkCommand>(MagicLinkCommand.new);
```

O construtor precisa ter parâmetros que o injector consiga resolver. Para uma
dependência que não pertence ao container, use `addInstance`.

## Rotas E Navegação

As rotas atuais são:

```text
/welcome/
/authentication/magic-link
/callback
/dashboard/
```

O Modular 7 moveu a navegação para extensões de `BuildContext`:

```dart
context.pushNamed('/authentication/magic-link');
context.navigate('/welcome');
context.replace('/authentication/magic-link');
context.pop();
```

Uma screen não deve buscar o router global. A rota injeta um callback:

```dart
child: (_, _) => WelcomeScreen(
  onContinueWithEmail: (context) =>
      context.pushNamed('/authentication/magic-link'),
),
```

O callback `ValueChanged<BuildContext>` é deliberado: a screen continua
testável e não fica acoplada ao Modular.

`main.dart` inicia em `/welcome`, sempre com `TransitionType.none`. Antes de
expor o router, `SessionGuardWidget` aguarda o estado reativo de sessão: uma
sessão autenticada entra em `/dashboard`; ausência, expiração ou logout levam a
`/welcome` por `context.navigate`, removendo o histórico protegido. Enquanto a
restauração está pendente, o guard mostra uma tela neutra de carregamento. A
diferença entre as rotas base e as rotas filhas (`/welcome/` e `/dashboard/`)
deve ser mantida consistente e testada antes de alterar a convenção.

## Camadas

### Domain

O domínio contém contratos e tipos que expressam o comportamento da aplicação.
Não deve importar Supabase, Flutter UI ou widgets.

Em features financeiras, o domínio deve manter a posse individual dos dados e
as regras de derivação. Por exemplo, `expense` não conhece `budget`, e uma
visão combinada pertence à feature que a consulta, não aos dados proprietários.

Exemplos atuais e futuros:

- `IAuthenticationRepository` define sessão, logout, solicitação e confirmação do magic link.
- Repositórios de `expense` e `budget` devem expor contratos dos próprios dados,
  sem referências cruzadas artificiais.
- `Failure` e suas subclasses representam falhas conhecidas.
- `Either<L, R>` representa sucesso (`Right`) ou falha (`Left`).

Uso típico:

```dart
final Either<Failure, void> result = await repository.requestMagicLink(
  email: email,
);

result.fold(
  (failure) => throw failure,
  (_) {},
);
```

`Either` oferece `fold`, `mapRight`, `mapLeft`, `flatMap`, `either`, `swap`,
`tryCatch`, `tryExcept`, `cond` e `condLazy`. Use `fold` para consumir o
resultado sem lançar exceções de domínio desnecessariamente.

### Data

Data implementa interfaces do domínio e traduz resultados da fonte de dados
para `Either<Failure, R>`.

Esta camada é uma convenção do cliente Flutter. Ela não altera a separação de
bounded contexts: cada repositório pertence à feature que possui seu contrato.

Fluxo de autenticação:

```text
IAuthenticationRepository
  <- AuthenticationRepository
       -> IAuthenticationDataSource
            -> AuthenticationDataSource
                  -> IAuthenticationClient
                       -> SupabaseAuthenticationClient
```

O repository converte booleanos da fonte em failures tipadas:

- `false` em `UnknownFailure` para sessão ausente;
- `false` em `LogoutFailure` para logout rejeitado;
- `false` em `MagicLinkRequestFailure` para request rejeitado;
- `false` em `MagicLinkConfirmationFailure` para confirmação rejeitada.

### Infrastructure

Infrastructure é a única camada que conhece SDKs e plugins externos. O cliente
Supabase encapsula:

- `currentSession` para verificar sessão;
- `signInWithOtp` para solicitar magic link;
- `exchangeCodeForSession` para confirmar código;
- `signOut` para encerrar sessão.

Exceções do SDK são capturadas no cliente e convertidas em `false`. O repository
é responsável por dar significado de domínio ao resultado.

O diretório atual é `infrastructure/remoto`. Preserve esse nome em alterações
locais, a menos que a renomeação seja planejada para toda a base.

### Presentation

Presentation contém:

- `screens`: composição da página e estado local de tela;
- `widgets`: componentes visuais reutilizáveis;
- `commands`: operações assíncronas ligadas à UI;
- `animations`: comportamentos visuais compartilhados;
- `themes`: tema e tokens visuais;
- `extensions`: acesso conveniente ao tema e à mídia.

## Construção De Widgets

### Composição

Screens devem compor widgets de feature, e widgets complexos devem compor
widgets core. Um exemplo conceitual do Welcome é:

```text
WelcomeScreen
  +-- SafeArea
  +-- WelcomeIconWidget
  +-- WelcomeSloganWidget
  |     +-- WelcomeTypewriterWidget
  +-- WelcomeFooterWidget
        +-- ElevatedButtonWidget
        +-- LinkButtonWidget
```

A tela de boas-vindas recebe `ValueChanged<BuildContext>` e repassa o callback ao
footer. A navegação continua fora do widget visual.

### Widgets De Botão

Os botões estão separados por responsabilidade:

- `ElevatedButtonWidget`: ação primária preenchida.
- `OutlineButtonWidget`: ação contornada.
- `DangerButtonWidget`: ação destrutiva com cor de erro.
- `TextButtonWidget`: ação textual compacta.
- `LinkButtonWidget`: ação textual sublinhada, baseada em `TextButtonWidget`.
- `IconButtonWidget`: ação de ícone com dimensões e fundo configuráveis.
- `HoldButtonWidget`: ação que exige pressionamento prolongado.

Os botões de ação usam `BounceWidget`, `SwitcherAnimation` e
`CircularProgressIndicatorWidget` quando aplicável. O padrão de propriedades é
`label`, `child`, `isLoading` e `onTap`, com callback anulável para representar
desabilitado.

Não crie um novo `ButtonWidget` genérico com enum para acumular variantes. Uma
variante nova deve ter arquivo e contrato próprios se tiver estilo ou semântica
próprios.

### Bounce

`BounceWidget` centraliza a interação de pressão para todos os botões:

```text
pointer down -> spring para 0.96
pointer up   -> spring para 1.0
cancel       -> spring para 1.0
```

Parâmetros atuais equivalentes ao hook RN:

- press-in: `mass 0.5`, `damping 16`, `stiffness 320`;
- press-out: `mass 0.5`, `damping 14`, `stiffness 280`.

A implementação Flutter usa `AnimationController.unbounded` e
`SpringSimulation`, reaproveitando a velocidade atual para evitar saltos ao
interromper uma animação.

### Imagens

`ImageWidget` escolhe uma strategy conforme a fonte:

```text
null       -> EmptyImageStrategy
sem http   -> AssetImageStrategy
com http   -> NetworkImageStrategy
```

As strategies centralizam `fit`, dimensões, label semântico, fallback, loading e
qualidade de filtro. Um widget de feature não deve repetir essa decisão.

## Tema E Material UI

### Aplicação

`AppWidget` aplica:

```dart
theme: Themes.light,
darkTheme: Themes.dark,
themeMode: ThemeMode.system,
```

`Themes._build` configura Material 3, fonte Inter, `ColorScheme`, splash,
background do Scaffold, temas de botões, campos, cards, app bar e extensões.

### Acesso

Use:

```dart
context.colors       // Theme.of(context).colorScheme
context.typography   // Theme.of(context).textTheme
context.radius       // CornerRadiusToken
context.isDark       // brilho atual
```

O `ColorScheme` é a API normal para cores de UI. O `AppColors` é uma extensão
registrada, mas a extensão de `BuildContext` atual não fornece um getter para
ele; não introduza outro getter ou outra fonte de cores sem decisão explícita.

### Valores De Referência

O tema claro usa, entre outros:

- background: `#F6FBF4`;
- surface: `#FFFFFF`;
- text: `#181D19`;
- muted text: `#414942`;
- primary: `#2B6A46`;
- primary soft: `#AFF2C4`.

O tema escuro possui papéis equivalentes, com `primary: #93D5A9` e background
`#0F1511`.

Não use valores hexadecimais diretamente em widgets quando houver papel
semântico equivalente no `ColorScheme`.

### Tipografia

O tema registra `Inter` como família global e carrega
`assets/fonts/Inter-Variable.ttf`. Use a variante existente de `TextTheme` como
base e aplique `copyWith` somente quando a especificação visual exigir valores
fora do preset.

Exemplo para um headline da Welcome:

```dart
context.typography.headlineMedium?.copyWith(
  color: context.colors.onSurface,
  fontSize: 32.0,
  fontWeight: .w600,
  height: 38.0 / 32.0,
  letterSpacing: -0.6,
)
```

O objetivo é preservar família, estilo e herança do tema, não criar um sistema
paralelo de tipografia.

## Estado E Ciclo De Vida

### Estado Local De Tela

`MagicLinkScreen` é o exemplo atual de estado local:

- possui `TextEditingController`;
- mantém `_emailFailure`;
- valida antes de executar o command;
- limpa a falha quando o usuário altera o campo;
- descarta o controller em `dispose`.

Esse padrão é adequado quando o estado não precisa sobreviver à tela nem ser
compartilhado por múltiplas rotas.

### Mixins De Estado De UI

Uma `StatefulWidget` cuja lógica local de UI torne o `build` difícil de ler deve
delegar esse estado a um mixin específico da mesma screen, localizado em
`presentation/mixins/`. O mixin declara `on State<Screen>`, mantendo explícito
que ele não é reutilizável fora daquela tela.

O mixin encapsula controllers, timers, subscriptions, validação de entrada,
handlers de interação e feedback visual, incluindo `initState` e `dispose`. A
screen consome seus membros públicos para compor os widgets. Esse padrão não se
aplica a `StatelessWidget`, que deve resolver lógica visual pura com composição
ou métodos privados.

Mixins de UI continuam na camada presentation: podem observar commands, mas não
acessam repositórios concretos, data sources, storage ou SDKs. Não crie mixins
genéricos para concentrar estados de telas distintas.

### Commands E Resultados

`MagicLinkCommand` cria um `Command<String, void>` assíncrono. Ele chama o
repository, converte `Left` em exceção e expõe estados para `CommandBuilder`.

```text
MagicLinkScreen
  -> CommandBuilder
       -> MagicLinkCommand.send
            -> IAuthenticationRepository.requestMagicLink
                 -> Either<Failure, void>
```

`CommandBuilder` renderiza `whileRunning`, `onSuccess` e `onError`. Isso mantém
loading e feedback fora do método de negócio da screen.

Commands implementam `ICommand`, que exige `dispose`. Quando o command é
instanciado fora do Modular em um teste, o teste deve descartá-lo no `tearDown`.

## Tratamento De Erros

O sistema atual usa um caminho explícito:

```text
SDK exception
  -> infrastructure: false
  -> repository: Left(typed Failure)
  -> command: throw Failure
  -> CommandBuilder.onError
  -> presentation feedback
```

Failures atuais de autenticação:

- `UnknownFailure`;
- `LogoutFailure`;
- `MagicLinkRequestFailure`;
- `MagicLinkConfirmationFailure`.

Failures carregam mensagem em português e `toString()` retorna essa mensagem.
Não mostre stack trace ou erro bruto do SDK ao usuário.

Ainda não existe logging, telemetria, retry automático ou boundary global de
erro. Uma mudança que introduza esses recursos deve definir primeiro o contrato
e os testes.

## Estratégia De Testes

### Pirâmide Atual

```text
muitos testes unitários de domínio/data/infrastructure
alguns testes de command e widgets/screens
nenhum integration_test registrado
```

### Organização

O teste deve espelhar a camada do código:

```text
test/features/
  core/domain/either_test.dart
  core/infrastructure/clients/storage_client_test.dart
  authentication/infrastructure/...
  authentication/data/...
  authentication/presentation/commands/...
  authentication/presentation/screens/...

test/architecture/
  bounded_context_dependencies_test.dart
```

O teste de `MagicLinkCommand` está atualmente em um diretório chamado
`presentation/screens`, embora teste um command; ao criar testes novos, use o
diretório da camada correta.

### Testes De Widget

Um widget que usa `context.radius` precisa do tema que registra
`CornerRadiusToken`. Um harness mínimo correto deve usar `Themes.light` ou
`MaterialPreviewWidget`; `MaterialApp` puro não reproduz o runtime e pode causar
`Null check operator used on a null value`.

Teste comportamentos observáveis:

- texto e semântica;
- callbacks;
- estados de loading;
- erros e feedback;
- disposição de controllers e commands quando aplicável.

O teste em `test/architecture/bounded_context_dependencies_test.dart` faz uma
verificação estática dos imports em `lib/`. Ele protege as direções entre
bounded contexts e a separação entre domínio, apresentação e infraestrutura.

### Comandos De Verificação

```bash
flutter pub get
flutter analyze
flutter test
```

Os testes de widget que dependem de extensões do tema devem usar
`MaterialPreviewWidget` ou configurar explicitamente `Themes.light`/`Themes.dark`.

## Convenções De Alteração

### Nova Feature

1. Crie o módulo da feature.
2. Defina contratos e failures no domínio.
3. Implemente repository na camada data.
4. Encapsule SDKs em data sources/clients de infrastructure.
5. Registre bindings no módulo.
6. Crie commands para operações assíncronas de apresentação.
7. Componha screens usando widgets pequenos.
8. Adicione testes por camada.

### Novo Widget

1. Procure um widget core equivalente.
2. Use `material_ui`.
3. Use `context.colors`, `context.typography` e `context.radius`.
4. Preserve acessibilidade e callbacks.
5. Faça o construtor `const` quando possível.
6. Adicione teste de comportamento se o widget for compartilhado.

### Alteração Visual

1. Compare a implementação RN ou especificação visual.
2. Reuse o preset de tema mais próximo.
3. Sobrescreva somente propriedades necessárias com `copyWith`.
4. Não crie tokens locais que duplicam o tema.
5. Valide light/dark quando o componente usa cores semânticas.

## Dívida Técnica Registrada

Os itens abaixo são fatos do estado atual, não instruções para replicá-los:

- Há mistura histórica de imports `flutter/material.dart` e `material_ui` em
  alguns arquivos.
- O nome `remoto` é uma convenção existente, apesar de não ser o nome usual em
  inglês.
- Existem referências de produto “Trocado” dentro do projeto `cordato`.
- `completeMagicLink` recebe `flowId` no contrato do repository, mas a camada
  data atual não o encaminha ao data source.
- `listen_it` está declarado sem uso direto.
- O cliente de infraestrutura captura exceções sem logging.
- A inicialização usa `SUPABASE_ANON_KEY` como `publishableKey`; a nomenclatura
  deve ser tratada como decisão de configuração, não alterada incidentalmente.
- Alguns arquivos `.DS_Store` existem na árvore de trabalho e não são código.
