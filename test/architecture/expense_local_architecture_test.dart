import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Expense and Settings no longer require remote identity', () {
    for (final directory in ['lib/features/expense', 'lib/features/settings']) {
      for (final file
          in Directory(directory)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();

        expect(
          source,
          isNot(
            matches(
              r'PocketBase|\bClientException\b|MissingAuthenticatedUserException|validateOwner|ownerId|features/(authentication|session)/',
            ),
          ),
          reason: file.path,
        );
      }
    }
  });

  test('Expense uses shared local repositories with existing Bloc ownership', () {
    final module = File('lib/features/expense/expense_module.dart')
        .readAsStringSync();
    final form = File(
      'lib/features/expense/presentation/screens/expense/expense_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/expense/infrastructure/repositories/expense_repository.dart',
    ).readAsStringSync();

    expect(module, isNot(contains("path: '/'")));
    expect(
      module,
      contains('addLazySingleton<IExpenseRepository>(ExpenseRepository.new)'),
    );
    expect(module, isNot(contains('IExportRepository')));
    expect(module, contains('expenseBloc: inject<ExpenseBloc>'));
    expect(module, contains('scope.addBloc<ExpenseSuggestionsBloc>'));
    expect(form, contains('ExpenseBloc Function()'));
    expect(repository, contains('DatabaseClient'));
    expect(repository, isNot(contains('Localstore')));
    expect(repository, isNot(contains('features/user/')));
    expect(module, contains('int id => id'));
    expect(repository, isNot(contains('.close(')));
    expect(module, contains('addLazySingleton<SuggestionsDao>'));
    final database = File(
      'lib/features/core/infrastructure/clients/database/database_client.dart',
    ).readAsStringSync();
    expect(database, isNot(contains('features/expense/')));
  });
}
