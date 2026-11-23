import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-migration-');
    file = File('${directory.path}/cordato.sqlite');
    final legacy = sqlite.sqlite3.open(file.path);
    try {
      legacy.execute(
        await File('test/support/core/storage/schema_v1.sql').readAsString(),
      );
      legacy.execute(
        "INSERT INTO profiles (id, name, seed) VALUES (3, 'Gabriel', 'saved-seed')",
      );
    } finally {
      legacy.close();
    }
  });

  tearDown(() => directory.delete(recursive: true));

  void seedExpenses({bool keepExpense = true}) {
    final legacy = sqlite.sqlite3.open(file.path);
    try {
      legacy.execute(
        "INSERT INTO expenses (id, profile_id, amount, category, description, occurred_on) "
        "VALUES (7, 3, 9007199254740993, 'food', NULL, '2026-11-08'), "
        "(20, 3, 100, 'other', 'Removed', '2026-11-09')",
      );
      legacy.execute('DELETE FROM expenses WHERE id = 20');
      if (!keepExpense) {
        legacy.execute('DELETE FROM expenses');
      }
    } finally {
      legacy.close();
    }
  }

  DatabaseClient openDatabase() => DatabaseClient(
    executor: NativeDatabase(file, setup: DatabaseClient.configureConnection),
  );

  test(
    'migra v1 para v2 preservando dados, índices, cascade e sequências',
    () async {
      seedExpenses();
      final database = openDatabase();
      try {
        final profile = await database
            .select(database.profilesTable)
            .getSingle();
        final expense = await database
            .select(database.expensesTable)
            .getSingle();

        expect(profile.id, 3);
        expect(profile.name, 'Gabriel');
        expect(profile.seed, 'saved-seed');
        expect(expense.id, 7);
        expect(expense.profileId, 3);
        expect(expense.amount, 9007199254740993);
        expect(expense.category, 'food');
        expect(expense.description, isNull);
        expect(expense.occurredOn, '2026-11-08');
        final version = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 2);

        final created = await database
            .into(database.expensesTable)
            .insertReturning(
              ExpensesTableCompanion.insert(profileId: profile.id, amount: 100),
            );
        expect(created.id, greaterThan(20));
        expect(created.occurredOn, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
        final indexes = await database
            .customSelect('PRAGMA index_list(expenses)')
            .get();
        expect(
          indexes.map((index) => index.read<String>('name')),
          contains('expenses_profile_date'),
        );
        final violations = await database
            .customSelect('PRAGMA foreign_key_check')
            .get();
        expect(violations, isEmpty);

        await database.delete(database.profilesTable).go();
        expect(await database.select(database.expensesTable).get(), isEmpty);
        final newProfileId = await database
            .into(database.profilesTable)
            .insert(
              ProfilesTableCompanion.insert(name: 'Cordato', seed: 'new-seed'),
            );
        expect(newProfileId, greaterThan(profile.id));
      } finally {
        await database.close();
      }
    },
  );

  test(
    'preserva sequência mesmo quando todas as despesas foram excluídas',
    () async {
      seedExpenses(keepExpense: false);
      final database = openDatabase();
      try {
        final id = await database
            .into(database.expensesTable)
            .insert(ExpensesTableCompanion.insert(profileId: 3, amount: 100));
        expect(id, greaterThan(20));
      } finally {
        await database.close();
      }
    },
  );

  test('migra banco sem despesas nem sequência de expenses', () async {
    final database = openDatabase();
    try {
      final id = await database
          .into(database.expensesTable)
          .insert(ExpensesTableCompanion.insert(profileId: 3, amount: 100));
      expect(id, 1);
    } finally {
      await database.close();
    }
  });

  test(
    'falha de migração reverte schema sem apagar dados ou avançar versão',
    () async {
      final legacy = sqlite.sqlite3.open(file.path);
      try {
        legacy.execute('PRAGMA ignore_check_constraints = ON');
        legacy.execute(
          "INSERT INTO expenses (profile_id, amount, occurred_on) VALUES (3, 100, 'invalid')",
        );
      } finally {
        legacy.close();
      }

      final database = openDatabase();
      try {
        await expectLater(
          database.select(database.expensesTable).get(),
          throwsA(isA<SqliteException>()),
        );
      } finally {
        await database.close();
      }

      final preserved = sqlite.sqlite3.open(file.path);
      try {
        expect(
          preserved.select('PRAGMA user_version').single['user_version'],
          1,
        );
        expect(
          preserved
              .select('SELECT occurred_on FROM expenses')
              .single['occurred_on'],
          'invalid',
        );
        expect(
          preserved
              .select("SELECT seq FROM sqlite_sequence WHERE name = 'expenses'")
              .single['seq'],
          1,
        );
      } finally {
        preserved.close();
      }
    },
  );
}
