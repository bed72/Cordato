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

Cordato é um aplicativo de finanças pessoais. Cada pessoa é dona dos próprios
dados financeiros; um casal é somente uma lente de leitura compartilhada, não
um dono de dinheiro.

O modelo de domínio validado possui estes bounded contexts:

- `expense`: fatos atômicos de gastos, pertencentes a uma pessoa.
- `budget`: tetos planejados por intervalo de datas; gasto e saldo são derivados.
- `couple`: pareamento entre duas pessoas, com leitura combinada e sem escrita nos dados do outro.
- `insight`: análises derivadas, somente leitura e sem persistência própria.

O backend ativo está versionado em `supabase/`; o Kotlin legado é somente
referência de domínio. `expense` e `budget` estão implementados. `couple` e
`insight` são planejados e não devem ser descritos ou tratados como código
existente. A autenticação atual usa Supabase Auth com magic link; não crie um
contexto `identity` no app para reproduzir o backend antigo. O contexto `chat`
não faz parte do escopo atual.

Regras de domínio que devem ser preservadas nas features financeiras:

- valores monetários são representados em centavos inteiros e somente em BRL;
- um gasto não referencia um orçamento; o pertencimento é derivado pela data;
- orçamentos vivos da mesma pessoa não podem se sobrepor;
- dissolver um casal não altera os dados individuais;
- parear nunca concede permissão de escrita sobre os dados da outra pessoa;
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
- Supabase Auth e dados através de `supabase_flutter`.
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
não um bounded context de negócio. `authentication` encapsula o fluxo de
Supabase Auth e magic link; não deve assumir a responsabilidade de modelar
todo o ciclo de vida de `identity` do backend antigo.

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
- Não coloque acesso a Supabase, storage ou regras de negócio dentro de um
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

## Screens

Screens são pontos de composição e integração da feature. Elas devem:

- Montar widgets de `presentation/widgets`.
- Receber callbacks de navegação ou dependências necessárias por construtor.
- Manter estado estritamente local quando ele pertence àquela tela.
- Criar e descartar controllers e subscriptions corretamente.
- Delegar operações assíncronas para commands.
- Não conhecer detalhes de clientes Supabase ou implementações de storage.

### Mixins De Estado De UI

Quando uma screen `StatefulWidget` acumular estado efêmero, lifecycle e handlers
de UI suficientes para prejudicar a leitura do `build`, extraia-os para um mixin
restrito à própria screen em `presentation/mixins/`. O mixin deve declarar
`on State<Screen>` para tornar seu acoplamento explícito.

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

O padrão atual é:

```dart
final class ExampleCommand implements ICommand {
  final Command<String, void> execute;

  ExampleCommand({required IRepository repository})
      : execute = Command.createAsyncNoResult<String>((value) async {
          final result = await repository.run(value);
          result.fold((failure) => throw failure, (_) {});
        });

  @override
  void dispose() => execute.dispose();
}
```

Na screen, use `CommandBuilder` para renderizar estados de execução, sucesso e
erro. Não faça `try/catch` da operação diretamente no `build`.

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
- `infrastructure` acessa Supabase, storage, rede, plugins e APIs externas.
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

## Supabase

`supabase/` é a fonte de verdade para schema, migrations, RLS, grants, RPCs e
testes de banco. A UI Flutter não concede autoridade: a propriedade financeira
é aplicada por RLS e pelas RPCs transacionais, que derivam o ator de
`auth.uid()`. Clientes autenticados não devem escrever diretamente nas tabelas
financeiras.

Para uma feature financeira, identifique o contexto proprietário e altere a
migration/RPC e os testes de autorização ou invariantes aplicáveis. Não adicione
tabelas, políticas ou RPCs de `couple` ou `insight` antes de essas features
existirem. Consulte `supabase/README.md` para os artefatos e comandos de banco;
não replique SQL em documentação geral.

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

- `/welcome/` para a tela de boas-vindas.
- `/authentication/magic-link` para o magic link.
- `/callback` para o retorno do magic link.
- `/dashboard/` para a área autenticada inicial.

## Erros E Falhas

O padrão atual separa resultado de negócio de exceção:

- infraestrutura retorna resultado simples ou captura exceções externas;
- repository converte o resultado em `Either<Failure, R>`;
- presentation transforma `Left` em erro de command quando necessário;
- `CommandBuilder` renderiza o estado de erro.

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

Para executar o app, forneça as configurações obrigatórias:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

`SUPABASE_REDIRECT_URL` é opcional e possui valor padrão no módulo de
autenticação.

Para alterações de banco, com Docker Desktop e Supabase CLI instalados, execute
depois de um reset local limpo:

```bash
supabase start
supabase db reset
supabase migration list --local
supabase db lint --local
supabase test db
```

Esses são testes de integração locais de schema, RPC, RLS e invariantes, não
substitutos da suíte Flutter. A configuração e verificação de release Android
estão em `android/README.md`.

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
- Mudanças em migrations, RPCs, RLS ou testes de banco atualizaram `supabase/README.md`.
- Mudanças de release Android atualizaram `android/README.md`.
- O `README.md` foi revisado quando o estado do produto, configuração ou início rápido mudou.

## Pendências Conhecidas

Estas situações existem hoje e não devem ser silenciosamente reinterpretadas
como padrão novo:

- Há imports antigos de `flutter/material.dart` em alguns widgets de imagem e
  infraestrutura de apresentação; código novo deve usar `material_ui`.
- `listen_it` está declarado sem uso direto na aplicação.
- Não existe suíte `integration_test`.
- Há referências legadas a “Trocado” em um projeto chamado `cordato`; não
  normalize nomes sem uma decisão explícita de produto.
