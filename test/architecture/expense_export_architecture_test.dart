import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'export reads SQLite directly without remote identity or pagination',
    () {
      final repository = File(
        'lib/features/expense/infrastructure/repositories/expense_export_repository.dart',
      ).readAsStringSync();

      expect(repository, contains('DatabaseClient'));
      expect(repository, contains('ExpenseCsvSerializer'));
      expect(repository, contains('runDatabaseOperation'));
      expect(repository, contains('.asc(row.occurredOn)'));
      expect(repository, contains('.asc(row.id)'));
      expect(repository, isNot(contains('transaction(')));
      expect(repository, isNot(contains('.limit(')));
      expect(repository, isNot(contains('IExpenseRepository')));
      expect(repository, isNot(contains('features/user/')));
      expect(repository, isNot(contains('share_plus')));
      expect(repository, isNot(contains('ownerId')));
    },
  );

  test('native sharing SDK stays inside its core infrastructure client', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      if (source.contains('package:share_plus/') &&
          file.path !=
              'lib/features/core/infrastructure/clients/share/share_client.dart') {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty);
  });

  test('export Bloc does not own clients or financial storage', () {
    final source = File(
      'lib/features/settings/presentation/screens/settings/bloc/export_bloc.dart',
    ).readAsStringSync();

    expect(source, contains('IExportRepository'));
    expect(source, contains('transformer: droppable()'));
    expect(source, contains('isClosed || emit.isDone'));
    expect(source, contains('_repository.discard('));
    expect(source, isNot(contains('/infrastructure/')));
    expect(source, isNot(contains('dart:io')));
    expect(source, isNot(contains('share_plus')));
    expect(source, isNot(contains('Future<void> close(')));
  });
}
