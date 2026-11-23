import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';

void main() {
  test(
    'o CHECK SQL aceita exatamente as categorias do domínio de Expense',
    () async {
      final database = DatabaseClient(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final schema = await database
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'expenses'",
          )
          .getSingle();
      final categoryCheck = RegExp(r'category IN \(([^)]+)\)')
          .firstMatch(schema.read<String>('sql'))!;
      final values = RegExp("'([^']+)'")
          .allMatches(categoryCheck.group(1)!)
          .map((match) => match.group(1)!);

      expect(
        values,
        unorderedEquals(CategoryEnum.values.map((category) => category.value)),
      );

      final profileId = await database
          .into(database.profilesTable)
          .insert(ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'));
      for (final category in CategoryEnum.values) {
        await database.customStatement(
          'INSERT INTO expenses (profile_id, amount, category) VALUES (?, 100, ?)',
          [profileId, category.value],
        );
      }

      final expenses = await database.select(database.expensesTable).get();
      expect(
        expenses.map((expense) => expense.category),
        unorderedEquals(CategoryEnum.values.map((category) => category.value)),
      );
    },
  );
}
