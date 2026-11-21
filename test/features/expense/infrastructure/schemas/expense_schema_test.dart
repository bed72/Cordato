import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/schemas/expense_schema.dart';

void main() {
  late Directory directory;
  late ToStore database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-expenses-');
    database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: [expenseSchema],
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  group('expense schema', () {
    test(
      'generates distinct string IDs and applies category default',
      () async {
        final firstExpense = await database.insert('expenses', {
          'amount': 1,
          'occurred_on': DateTime.utc(2026, 11, 21).toIso8601String(),
        });
        final secondExpense = await database.insert('expenses', {
          'amount': 500,
          'occurred_on': DateTime.utc(2026, 11, 22).toIso8601String(),
        });

        expect(firstExpense.hasErrors, isFalse);
        expect(secondExpense.hasErrors, isFalse);
        expect(firstExpense.firstPrimaryKey, isNotEmpty);
        expect(
          secondExpense.firstPrimaryKey,
          isNot(firstExpense.firstPrimaryKey),
        );
        final storedExpense = await database
            .query('expenses')
            .where('id', '=', firstExpense.firstPrimaryKey)
            .first();

        expect(storedExpense!['amount'], 1);
        expect(storedExpense['category'], 'other');
        expect(storedExpense['description'], isNull);
        expect(storedExpense.containsKey('owner'), isFalse);
      },
    );

    for (final amount in [0, -1]) {
      test('rejects amount $amount', () async {
        final rejectedExpense = await database.insert('expenses', {
          'amount': amount,
          'occurred_on': DateTime.utc(2026, 11, 21).toIso8601String(),
        });

        expect(rejectedExpense.hasErrors, isTrue);
        expect(await database.query('expenses').count(), 0);
      });
    }

    for (final missingField in ['amount', 'occurred_on']) {
      test('rejects missing $missingField', () async {
        final fields = <String, dynamic>{
          'amount': 100,
          'occurred_on': DateTime.utc(2026, 11, 21).toIso8601String(),
        }..remove(missingField);
        final rejectedExpense = await database.insert('expenses', fields);

        expect(rejectedExpense.hasErrors, isTrue);
        expect(await database.query('expenses').count(), 0);
      });
    }

    test('persists exact cents and UTC civil date across reopen', () async {
      final occurredOn = DateTime.utc(2026, 11, 21).toIso8601String();
      final createdExpense = await database.insert('expenses', {
        'amount': 1234567890123,
        'description': null,
        'occurred_on': occurredOn,
      });
      expect(createdExpense.hasErrors, isFalse);

      await database.close();
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: [expenseSchema],
      );
      final storedExpense = await database
          .query('expenses')
          .where('id', '=', createdExpense.firstPrimaryKey)
          .first();

      expect(storedExpense!['amount'], 1234567890123);
      expect(
        DateTime.parse(storedExpense['occurred_on'] as String),
        DateTime.utc(2026, 11, 21),
      );
      expect(storedExpense['description'], isNull);
    });

    test('supports every existing category', () async {
      for (final category in ExpenseCategoryEnum.values) {
        final createdExpense = await database.insert('expenses', {
          'amount': 100,
          'category': category.value,
          'description': 'Descrição',
          'occurred_on': DateTime.utc(2026, 11, 21).toIso8601String(),
        });

        expect(createdExpense.hasErrors, isFalse, reason: category.value);
        final storedExpense = await database
            .query('expenses')
            .where('id', '=', createdExpense.firstPrimaryKey)
            .first();
        expect(storedExpense!['category'], category.value);
      }
    });

    test('indexes dates without timestamp defaults, TTL or eviction', () {
      final occurredOn = expenseSchema.fields.singleWhere(
        (field) => field.name == 'occurred_on',
      );

      expect(occurredOn.createIndex, isTrue);
      expect(occurredOn.defaultValueType, DefaultValueType.none);
      expect(expenseSchema.ttlConfig, isNull);
      expect(expenseSchema.capacityConfig, isNull);
    });
  });
}
