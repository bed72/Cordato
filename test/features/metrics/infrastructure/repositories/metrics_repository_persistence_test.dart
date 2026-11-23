import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/metrics/infrastructure/daos/metrics_dao.dart';
import 'package:cordato/features/metrics/infrastructure/repositories/metrics_repository.dart';

import '../../../../support/core/mocks/widget_client_mock.dart';

void main() {
  late Directory directory;
  late DatabaseClient database;
  late MetricsRepository repository;

  void open() {
    database = DatabaseClient(
      executor: NativeDatabase.createInBackground(
        File('${directory.path}/cordato.sqlite'),
      ),
    );
    repository = MetricsRepository(
      dao: MetricsDao(client: database),
      client: WidgetClientMock(),
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-metrics-');
    open();
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'preserves monthly groups after reopening a file in an isolate',
    () async {
      final profileId = await database
          .into(database.profilesTable)
          .insert(ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'));
      await database
          .into(database.expensesTable)
          .insert(
            ExpensesTableCompanion.insert(
              profileId: profileId,
              amount: 123,
              category: const Value('food'),
              occurredOn: const Value('2026-10-31'),
            ),
          );
      await database.close();
      open();

      final metrics = await repository.getExpenses(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
        groupBy: .category,
      );

      expect(metrics.total, 123);
      expect(metrics.categories!.single.category, 'food');
      expect(metrics.categories!.single.total, metrics.total);
      expect(metrics.categories!.single.percentage, 100);
    },
  );

  test('unwraps real remote SQL failure without resetting storage', () async {
    await database.customStatement('DROP TABLE expenses');

    await expectLater(
      repository.getExpenses(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
      ),
      throwsA(
        isA<SqliteException>().having(
          (error) => error.resultCode,
          'resultCode',
          SqlError.SQLITE_ERROR,
        ),
      ),
    );

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'expenses'",
        )
        .get();
    expect(tables, isEmpty);
  });
}
