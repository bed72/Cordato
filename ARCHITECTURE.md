# Arquitetura

## Visão Geral

Cordato é um aplicativo Flutter de finanças pessoais organizado por feature e
por camadas. Cada pessoa é dona dos próprios dados financeiros; o casal é uma
lente de leitura compartilhada, nunca um dono de dinheiro.

O backend Kotlin legado é uma referência de domínio. A implementação de banco,
autorização e mutações atual está versionada em `supabase/`; não há um backend
Kotlin em execução para o aplicativo. A apresentação permanece independente de
Supabase, storage e plugins.

```text
Flutter UI -> presentation -> domain -> data -> infrastructure -> Supabase
```

Uma screen conhece commands e contratos de repositório, nunca
`SupabaseClient`, `FlutterSecureStorage` ou clientes de rede diretamente.

## Produto E Contextos

Os contextos financeiros e seu estado atual são:

- `expense`: implementado. Registra gastos individuais por RPC Supabase.
- `budget`: implementado. Registra tetos individuais por intervalo de datas por RPC Supabase.
- `couple`: planejado. Será somente uma leitura combinada autorizada.
- `insight`: planejado. Será uma projeção derivada e somente leitura.

`dashboard` é uma feature de apresentação e composição. `settings` é uma tela
de apresentação. `authentication` encapsula Supabase Auth e magic link; não
recria o contexto `identity`. `chat` permanece fora de escopo.

Invariantes do produto:

- dinheiro é BRL em centavos inteiros positivos;
- gastos não referenciam orçamentos; o pertencimento é derivado pela data;
- orçamentos do mesmo dono não podem sobrepor dias;
- pareamento nunca concede escrita nos dados financeiros da outra pessoa;
- dissolver um casal preserva os dados individuais;
- visões de casal e insights são recalculados, não persistidos como dados-fonte.

Contextos proprietários não dependem de lentes. Quando implementados, `couple`
e `insight` só poderão ler contextos financeiros por contratos próprios, com
adapters concretos na borda de infrastructure. O teste
`test/architecture/bounded_context_dependencies_test.dart` protege essas
direções e proíbe escrita direta nas tabelas financeiras pelo Flutter.

## Estrutura E Camadas

```text
lib/
  main.dart
  app_module.dart
  app_widget.dart
  features/
    core/
    authentication/
    welcome/
    dashboard/
    expense/
    budget/
    settings/

supabase/
  migrations/
  tests/
```

Cada feature pode conter `domain`, `data`, `infrastructure` e `presentation`.
`core` contém capacidades compartilhadas, como tema, formatação monetária,
widgets, animações, imagens e estado de sessão; não deve receber regras de uma
feature.

- `domain` define entidades, failures e contratos sem Flutter ou SDKs.
- `data` implementa contratos e converte respostas em `Either<Failure, R>`.
- `infrastructure` chama SDKs, RPCs, storage ou plugins.
- `presentation` contém screens, widgets, validators, estado local e commands.

O fluxo de uma mutação é:

```text
Screen/widget -> Command -> repository do domínio -> data source -> client/RPC
```

Commands usam `command_it`; convertem um `Left` em erro observável por
`CommandBuilder` e implementam `ICommand` quando precisam de descarte. Estado
efêmero pertence à screen ou widget. Quando lifecycle, controllers e handlers
prejudicarem a leitura, use um mixin específico em `presentation/mixins/`,
restrito ao `State` correspondente e responsável por seu `dispose`.

## Inicialização, Módulos E Rotas

`main.dart` inicializa Flutter, exige `SUPABASE_URL` e `SUPABASE_ANON_KEY`,
inicializa `ExternalClient` e inicia `ModularApp` em `/welcome`. `AppWidget`
instala temas, router e `SessionGuardWidget`. O guard mostra loading durante a
restauração e navega para `/dashboard` com sessão autenticada; sessão ausente,
logout ou falha de restauração navegam para `/welcome`.

`app_module.dart` compõe os módulos existentes:

```text
coreModule
budgetModule
expenseModule
welcomeModule
settingsModule
dashboardModule
authenticationModule
```

Registros importantes:

- `coreModule`: `IMoneyFormatter` com `MoneyFormatter`.
- `authenticationModule`: cliente Supabase, URL de redirect, validators,
  data source, repository, client e commands do magic link e confirmação.
- `dashboardModule`: acesso ao perfil, `GetUserNameCommand` e tela inicial.
- `expenseModule` e `budgetModule`: validators, commands, repositories, data
  sources e clientes Supabase para criar registros financeiros.
- `welcomeModule` e `settingsModule`: apenas as telas e navegação associada.

Rotas registradas:

```text
/welcome
/authentication/magic-link
/authentication/confirmation-code
/callback
/dashboard
/expense
/budget
/settings
```

Os módulos financeiros, dashboard, welcome e settings registram sua tela em
`/`, compondo o caminho do módulo. A navegação usa extensões de `BuildContext`
do Modular 7, como `context.pushNamed`, `context.navigate`, `context.replace` e
`context.pop`; não use `Modular.to`.

O redirect de autenticação pode ser configurado com `SUPABASE_REDIRECT_URL`.
Na ausência dele, o valor de compatibilidade é
`trocado://authentication/callback`. Não altere esse esquema apenas para
uniformizar o nome do produto.

## Supabase

`supabase/` é a fonte de verdade para configuração local, migrations, schema,
RLS, grants, RPCs e testes de banco. Consulte
[`supabase/README.md`](supabase/README.md) para o inventário e os comandos;
não replique detalhes de SQL neste documento.

Hoje as migrations versionam `profiles`, `expenses` e `budgets`. As mutações
financeiras usam RPCs transacionais que derivam o dono de `auth.uid()`; clientes
autenticados não possuem grants de escrita direta nas tabelas. RLS e as RPCs,
não a UI Flutter, são a fronteira que aplica propriedade individual.

Toda mudança de schema, RLS, grants, triggers ou funções deve entrar em uma nova
migration. Uma feature financeira deve definir seu contexto proprietário,
atualizar a migration/RPC correspondente e cobrir autorização e invariantes nos
testes de banco. Couple e insight só ganham tabelas, RPCs ou políticas quando
forem implementados como features.

## Interface E Tema

Código novo de UI importa `package:material_ui/material_ui.dart`. Reutilize os
widgets compartilhados de `core`, especialmente os botões e `BounceWidget`, em
vez de estilizar botões Material diretamente.

Use os acessos de tema existentes:

```dart
context.colors
context.typography
context.radius
context.isDark
```

`Themes.light` e `Themes.dark` registram Material 3, Inter e
`CornerRadiusToken`. Widgets não devem introduzir cores, tipografia ou tokens
paralelos quando houver um papel semântico do tema.

## Testes E Verificação

Testes unitários cobrem domain, data, infrastructure, validators, formatters,
commands e limites arquiteturais. Use `mocktail` para doubles. A política atual
não mantém testes Flutter automatizados para widgets, screens, temas, módulos
ou rotas; esses fluxos serão validados com Maestro quando os cenários existirem.
Não há suíte `integration_test` Flutter registrada.

Execute para alterações Flutter:

```bash
flutter pub get
flutter analyze
flutter test
```

Para uma verificação rápida de limites:

```bash
flutter test test/architecture
```

As verificações de banco/RLS são testes de integração locais do Supabase, não
testes unitários Flutter. Com Docker Desktop e Supabase CLI instalados, execute
após um reset limpo:

```bash
supabase start
supabase db reset
supabase migration list --local
supabase db lint --local
supabase test db
```

Para executar o app contra qualquer projeto Supabase, forneça somente nomes de
configuração não secretos no comando:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

`SUPABASE_REDIRECT_URL` é opcional. Para build, assinatura e verificação de
release Android, consulte [`android/README.md`](android/README.md).

## Revisão De Documentação

Uma mudança que adicionar, remover ou mover módulo, rota, contrato, migration,
RPC, política RLS, comando de validação ou configuração de release deve atualizar
na mesma alteração o documento canônico afetado:

- `ARCHITECTURE.md` para camadas, módulos, rotas e fronteiras.
- `supabase/README.md` para artefatos e comandos do backend.
- `android/README.md` para release Android.
- `README.md` para estado do produto e início rápido.
- `AGENTS.md` para convenções de contribuição e checklist.

Revise esses documentos juntos quando uma mudança estrutural os afetar. Retenha
nomes legados, como o deep link `trocado`, somente enquanto forem requisitos de
compatibilidade ativos.
