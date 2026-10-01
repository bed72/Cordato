# AGENTS.md

## Objetivo

Este arquivo orienta agentes e pessoas que alteram o aplicativo Flutter Cordato.
As regras abaixo descrevem o padrão que deve ser seguido ao criar features,
widgets, telas, estado, rotas e testes.

Documentação canônica: [ARCHITECTURE.md](ARCHITECTURE.md).

Antes de alterar código, leia a feature afetada, os widgets compartilhados que
ela usa e os testes correspondentes. O projeto evolui por alterações pequenas;
não substitua uma convenção existente por uma abstração nova sem necessidade.

## Contexto Do Produto

Cordato é um aplicativo de finanças pessoais e familiares. Cada pessoa é dona
dos próprios dados financeiros; uma família é somente uma lente de leitura
compartilhada entre seus membros, não uma dona de dinheiro.

O modelo de domínio validado possui estes bounded contexts:

- `expense`: fatos atômicos de gastos, pertencentes a uma pessoa.
- `budget`: tetos planejados por intervalo de datas; gasto e saldo são derivados.
- `family`: organização entre membros de uma família, com leitura combinada e sem escrita nos dados de outra pessoa.
- `insight`: análises derivadas, somente leitura e sem persistência própria.

O aplicativo integra sign-in e sign-up por e-mail e senha à API HTTP JSON:API;
o Kotlin legado é somente referência de domínio. `expense` possui formulário e
camadas de criação, mas seu client ainda não persiste dados. `budget`, `family`
e `insight` não têm feature Flutter implementada. Não descreva recursos
planejados como código existente nem crie um contexto `identity` para reproduzir
o backend antigo. O contexto `chat` não faz parte do escopo atual.

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

## Stack Atual

- Flutter/Dart com SDK definido em `pubspec.yaml`.
- Material 3 através de `material_ui`.
- `flutter_modular` 7 para módulos, injeção de dependências e rotas.
- `command_it` para operações assíncronas observáveis pela apresentação.
- `listen_it` está declarado, mas não é usado diretamente no código atual.
- `dio` para integração HTTP JSON:API de autenticação.
- `flutter_secure_storage` para armazenamento seguro.
- `mocktail` e `flutter_test` para testes.
- Fonte de aplicação: `Inter-Variable.ttf`.

## Estrutura

```text
lib/
  main.dart
  app_module.dart
  app_widget.dart
  features/
    core/
      core_module.dart
      domain/
      infrastructure/
      presentation/
    <feature>/
      <feature>_module.dart
      domain/
      data/
      infrastructure/
      presentation/
        commands/
        screens/
        widgets/

test/
  features/
    <feature>/
      ...
```

Feature code deve ficar dentro da própria feature. O `core` contém apenas
capacidades realmente compartilhadas, como tema, widgets básicos, animações,
imagens, storage e `Either`.

Os bounded contexts do produto devem ser refletidos em features próprias,
quando implementados. `dashboard` é uma feature de apresentação e composição,
não um bounded context de negócio. `authentication` encapsula sign-in e
sign-up por e-mail e senha via API; não deve assumir a responsabilidade de
modelar todo o ciclo de vida de `identity` do backend antigo.

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

Imports internos do projeto devem sempre usar o caminho completo com o prefixo
`package:cordato/`. Não use imports relativos como `import 'data/...';` ou
`import '../...';`.

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

Não use esse padrão em `StatelessWidget`: lógica visual pura deve permanecer em
métodos privados ou widgets de composição. Não crie mixins genéricos, nem mova
regras de domínio, acesso a repositórios, data sources, storage ou SDKs para um
mixin de UI.

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
tema; use o tema completo no harness.

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
- `data` implementa contratos do domínio e traduz dados vindos de data sources.
- `infrastructure` acessa rede, storage, plugins e APIs externas.
- `presentation` contém screens, widgets e commands; não acessa clientes
  externos diretamente.
- Dependências devem apontar para dentro: presentation usa interfaces de
  domain, e infrastructure implementa contratos consumidos por data.
- A rota e o módulo pertencem à feature que possui a tela.

Fluxo esperado:

```text
Screen/Widget
    -> Command
    -> Domain repository interface
    -> Data repository
    -> Data source interface
    -> Infrastructure client
    -> External service
```

## API HTTP E Persistência

`authenticationModule` configura `Dio` com `BASE_URL` (padrão
`https://api.cordato.cloud/api/`) e `HeadersInterceptor` para JSON:API. O
`HttpClient` do core devolve `Either` de mapas; `AuthenticationDataSource`
converte as respostas em objetos tipados e erros JSON:API. Endpoints relativos
à base preservam o prefixo `/api/`.

O sign-in usa e-mail e senha; o token recebido é salvo em storage seguro, mas
o sucesso não navega automaticamente. Chamadas protegidas optam pelo Bearer em
`HttpPathEnum.requiresAuth` e `Requests.forPath`; o backend controla a validade do token. Há command
para sign-up e tela de cadastro. `ExpenseClient.create` ainda retorna falha e não persiste gastos;
`budget`, `family` e `insight` não possuem integração Flutter. Não descreva
regras de autorização do backend como já aplicadas pelo aplicativo. Ao conectar
uma feature financeira, defina seu contexto proprietário, preserve as
invariantes no serviço responsável e adicione testes de autorização e domínio.

## Módulos, DI E Rotas

Use a API funcional do `flutter_modular` 7:

```dart
final featureModule = createModule(
  path: '/feature',
  register: (context) {
    context
      ..addLazySingleton<IRepository>(Repository.new)
      ..route(
        '/',
        child: (_, _) => const FeatureScreen(),
      );
  },
);
```

Regras:

- Cada feature declara seu módulo em `<feature>_module.dart`.
- `app_module.dart` apenas compõe módulos de alto nível.
- Use `addInstance` para objetos já criados e `addSingleton` ou
  `addLazySingleton` conforme o ciclo de vida necessário.
- Registre interfaces apontando para implementações concretas.
- Resolva dependências por `inject<T>()` dentro do builder quando esse for o
  padrão da rota, ou injete-as explicitamente pelo construtor.
- Use extensões de `BuildContext` do Modular para navegação, principalmente
  `context.pushNamed`, `context.navigate`, `context.replace` e `context.pop`.
- Não use a API global antiga `Modular.to` no Modular 7.

Rotas atuais:

- `/welcome` para a tela de boas-vindas e rota inicial.
- `/authentication/sign-in` para entrada por e-mail e senha.
- `/dashboard` para a tela inicial de dashboard, ainda sem guard de sessão.
- `/settings` para configurações.
- `/expense` para o formulário de gasto.

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
