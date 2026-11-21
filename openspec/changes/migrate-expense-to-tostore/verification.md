# Verificação

## Comandos

`flutter pub get`: concluído, sem alteração de dependências.

`flutter analyze`: baseline de 559 ocorrências antes da implementação.

```sh
flutter analyze --no-pub lib/features/expense lib/features/settings lib/features/core/presentation/enums/route_enum.dart test/features/expense test/features/settings test/architecture/expense_local_architecture_test.dart test/architecture/expense_export_architecture_test.dart test/architecture/expense_presentation_test.dart test/support/core/mocks/query_builder_mock.dart
```

Sem problemas, incluindo catálogo de rotas e novos testes arquiteturais.

```sh
flutter test --no-pub test/features/expense test/features/settings --reporter failures-only
```

371 aprovados antes dos testes adicionais de mapper/arquitetura.

```sh
flutter test --no-pub test/features/expense test/features/settings test/features/user test/features/root test/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc_test.dart test/features/core/infrastructure/clients/tostore test/features/core/tostore_module_test.dart test/architecture/expense_local_architecture_test.dart test/architecture/expense_export_architecture_test.dart test/architecture/expense_presentation_test.dart --reporter failures-only
```

637 aprovados.

`flutter analyze --no-pub`: 515 ocorrências restantes, incluindo referências
legadas a dependências removidas, Metrics, áudio, apresentação da Dashboard,
testes antigos do core e composição global. Não foram restauradas dependências
removidas nem apagados testes para ocultar esses bloqueios.

`flutter test --no-pub test/architecture --reporter failures-only`:
88 aprovados e 4 falhas:

- verification_app_links_test: rotas de autenticação removidas.
- reduced_motion_test: arquivos Sign-in e Sign-up removidos (dois cenários).
- android_release_version_test: encerramento do compilador em cascata.

`flutter test --no-pub --reporter failures-only`: 985 aprovados e 15 falhas.
Treze falhas de carregamento em Metrics (módulo/repository), core (módulo,
exceção de identidade, recording, PocketBase factory/mapper/extension,
observer), Dashboard (repository/Bloc de áudio), app links e app_module;
dois cenários de reduced_motion por arquivos de autenticação ausentes.
O compilador também relata encerramentos em cascata. Nenhum teste de Expense
ou Settings falhou nessa execução.

`openspec validate migrate-expense-to-tostore --strict`: válido.

`git diff --check`: sem problemas.

## Limites

Testes sem UI, com ToStore real em disco e fechamento explícito. Doubles do
SDK são usados somente para falhas e controle de operações pendentes.
Não houve build nativo, deploy, commit, push ou conferência visual.
Não se comprova funcionamento global do app, snapshot transacional de CSV,
backup restaurável, criptografia ou recuperação de dados.
