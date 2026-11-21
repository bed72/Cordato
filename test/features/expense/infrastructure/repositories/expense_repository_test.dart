import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/schemas/expense_schema.dart';

import '../../../../support/core/mocks/home_widget_client_mock.dart';
import '../../../../support/core/mocks/tostore_mock.dart';

void main() {
  late Directory directory;
  late ToStore database;
  late ExpenseRepository repository;
  late HomeWidgetClientMock homeWidgetClient;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-expense-repo-');
    database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: [expenseSchema],
    );
    homeWidgetClient = HomeWidgetClientMock();
    repository = ExpenseRepository(
      database: database,
      client: homeWidgetClient,
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  group('Local records and mutations', () {
    test('creates exact cents, defaults and a generated string ID', () async {
      final created = await repository.create(
        cents: 9007199254740991,
        description: ' Mercado ',
        occurredOn: DateTime(2026, 11, 8, 23, 59),
      );

      expect(created.id, isNotEmpty);
      expect(created.cents.cents, 9007199254740991);
      expect(created.description, 'Mercado');
      expect(created.category, ExpenseCategoryEnum.other);
      expect(created.occurredOn, DateTime(2026, 11, 8));
      final stored = await database.query('expenses').first();
      expect(stored!['occurred_on'], '2026-11-08T00:00:00.000Z');
      expect(stored.containsKey('owner'), isFalse);
      verify(homeWidgetClient.requestMonthlyRefresh).called(1);
    });

    test(
      'uses today at creation time without a schema timestamp default',
      () async {
        final before = DateTime.now();
        final created = await repository.create(cents: 1, description: 'Hoje');
        final after = DateTime.now();

        expect(
          created.occurredOn,
          anyOf(
            DateTime(before.year, before.month, before.day),
            DateTime(after.year, after.month, after.day),
          ),
        );
      },
    );

    for (final date in [
      DateTime(2026, 10, 5, 23),
      DateTime.utc(2026, 10, 5, 23),
    ]) {
      test(
        'preserves civil components from ${date.isUtc ? 'UTC' : 'local'} input',
        () async {
          final created = await repository.create(
            cents: 100,
            description: 'Data',
            occurredOn: date,
          );

          expect(created.occurredOn, DateTime(2026, 10, 5));
        },
      );
    }

    test('persists CRUD and nullable descriptions across reopening', () async {
      final inserted = await database.insert('expenses', {
        'amount': 500,
        'occurred_on': '2026-11-08T00:00:00.000Z',
      });
      final id = inserted.firstPrimaryKey!;
      expect((await repository.getById(id: id)).description, '');

      await repository.update(id: id, description: 'Café', category: .food);
      await database.close();
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: [expenseSchema],
      );
      repository = ExpenseRepository(
        database: database,
        client: homeWidgetClient,
      );
      final reopened = await repository.getById(id: id);
      expect(reopened.description, 'Café');
      expect(reopened.cents.cents, 500);
      expect(reopened.category, ExpenseCategoryEnum.food);

      await repository.delete(id: id);
      expect((await repository.get()).items, isEmpty);
      await expectLater(
        repository.getById(id: id),
        throwsA(isA<ExpenseException>()),
      );
    });

    test(
      'updates only supplied fields and accepts an empty description',
      () async {
        final original = await repository.create(
          cents: 500,
          description: 'Original',
          category: .food,
          occurredOn: DateTime(2026, 10, 5),
        );
        final changed = await repository.update(id: original.id, cents: 700);
        expect(changed.cents.cents, 700);
        expect(changed.description, 'Original');
        expect(changed.category, ExpenseCategoryEnum.food);
        expect(changed.occurredOn, original.occurredOn);

        final cleared = await repository.update(
          id: original.id,
          description: '',
          category: .other,
          occurredOn: DateTime.utc(2026, 12, 1, 22),
        );
        expect(cleared.description, '');
        expect(cleared.category, ExpenseCategoryEnum.other);
        expect(cleared.occurredOn, DateTime(2026, 12, 1));
        verify(homeWidgetClient.requestMonthlyRefresh).called(3);
      },
    );

    test('empty update reads without announcing a mutation', () async {
      final original = await repository.create(
        cents: 1,
        description: 'Original',
      );
      clearInteractions(homeWidgetClient);

      expect((await repository.update(id: original.id)).id, original.id);
      verifyNever(homeWidgetClient.requestMonthlyRefresh);
    });

    test(
      'independent concurrent updates do not overwrite omitted fields',
      () async {
        final original = await repository.create(
          cents: 1,
          description: 'Original',
        );
        final other = ExpenseRepository(
          database: database,
          client: homeWidgetClient,
        );

        await Future.wait([
          repository.update(id: original.id, cents: 99),
          other.update(id: original.id, description: 'Atualizada'),
        ]);

        final stored = await repository.getById(id: original.id);
        expect(stored.cents.cents, 99);
        expect(stored.description, 'Atualizada');
      },
    );

    for (final operation in ['get', 'update', 'empty update', 'delete']) {
      test('$operation rejects a missing record without refresh', () async {
        final pending = switch (operation) {
          'get' => repository.getById(id: '999'),
          'update' => repository.update(id: '999', cents: 10),
          'empty update' => repository.update(id: '999'),
          _ => repository.delete(id: '999'),
        };

        await expectLater(pending, throwsA(isA<ExpenseException>()));
        verifyNever(homeWidgetClient.requestMonthlyRefresh);
      });
    }

    for (final cents in [0, -1]) {
      test(
        'rejects $cents cents on create and update without refresh',
        () async {
          final original = await repository.create(
            cents: 1,
            description: 'Original',
          );
          clearInteractions(homeWidgetClient);

          await expectLater(
            repository.create(cents: cents, description: 'Inválido'),
            throwsA(isA<ExpenseException>()),
          );
          await expectLater(
            repository.update(id: original.id, cents: cents),
            throwsA(isA<ExpenseException>()),
          );

          expect((await repository.getById(id: original.id)).cents.cents, 1);
          expect((await repository.get()).items, hasLength(1));
          verifyNever(homeWidgetClient.requestMonthlyRefresh);
        },
      );
    }
  });

  group('Filtered pages', () {
    test('keeps inclusive civil dates and category on every page', () async {
      for (final day in [7, 8, 9, 10]) {
        for (final category in [
          ExpenseCategoryEnum.food,
          ExpenseCategoryEnum.other,
        ]) {
          await repository.create(
            cents: day,
            description: '${category.value} $day',
            category: category,
            occurredOn: DateTime.utc(2026, 11, day, 23),
          );
        }
      }
      final first = await repository.get(
        category: 'food',
        from: DateTime(2026, 11, 8, 23),
        to: DateTime(2026, 11, 9, 1),
        pageSize: 1,
      );
      final second = await repository.get(
        category: 'food',
        from: DateTime(2026, 11, 8),
        to: DateTime(2026, 11, 9),
        pageSize: 1,
        page: first.nextPage!,
      );

      expect(first.items.single.description, 'food 9');
      expect(second.items.single.description, 'food 8');
      expect(second.nextPage, isNull);
      expect(() => first.items.clear(), throwsUnsupportedError);
    });

    test(
      'orders tied dates by sequential ID, not insertion-dependent pages',
      () async {
        final ids = <String>[];
        for (int index = 0; index < 12; index++) {
          final expense = await repository.create(
            cents: 100,
            description: '$index',
            occurredOn: DateTime(2026, 11, 8),
          );
          ids.add(expense.id);
        }

        final first = await repository.get(pageSize: 6);
        final second = await repository.get(pageSize: 6, page: 2);
        expect(
          [...first.items, ...second.items].map((item) => item.id),
          ids.reversed,
        );
        expect(second.nextPage, isNull);
        expect((await repository.get(page: 3, pageSize: 6)).items, isEmpty);
      },
    );

    test(
      'supports Dashboard oldest date and explicit local ordering',
      () async {
        await repository.create(
          cents: 300,
          description: 'Novo',
          occurredOn: DateTime(2026, 11, 9),
        );
        final oldest = await repository.create(
          cents: 100,
          description: 'Antigo',
          occurredOn: DateTime(2026, 11, 8),
        );

        expect(
          (await repository.get(
            sort: 'occurred_on',
            pageSize: 1,
          )).items.single.id,
          oldest.id,
        );
        expect(
          (await repository.get(sort: '-amount')).items.first.cents.cents,
          300,
        );
        expect((await repository.get(pageSize: 0)).items, hasLength(2));
      },
    );

    test(
      'does not disguise invalid query arguments as storage errors',
      () async {
        await expectLater(repository.get(page: 0), throwsArgumentError);
        await expectLater(repository.get(sort: 'owner'), throwsArgumentError);
        await expectLater(
          repository.get(category: 'unknown'),
          throwsStateError,
        );
      },
    );
  });

  group('Suggestions', () {
    test(
      'matches case-insensitively and keeps the latest category and cents',
      () async {
        await repository.create(
          cents: 100,
          description: 'Café',
          category: .food,
          occurredOn: DateTime(2026, 11, 7),
        );
        final latest = await repository.create(
          cents: 200,
          description: 'CAFÉ',
          category: .other,
          occurredOn: DateTime(2026, 11, 8),
        );
        await repository.create(
          cents: 300,
          description: 'Outra',
          occurredOn: DateTime(2026, 11, 9),
        );

        final suggestions = await repository.suggestions(query: 'cAfÉ');
        expect(suggestions.single.id, latest.id);
        expect(suggestions.single.category, ExpenseCategoryEnum.other);
        expect(suggestions.single.cents, 200);
        expect(() => suggestions.clear(), throwsUnsupportedError);
      },
    );

    test('treats wildcard and query syntax as literal descriptions', () async {
      for (final description in [
        '100%_\\ café',
        '100XX café',
        '" || category != "',
      ]) {
        await repository.create(cents: 1, description: description);
      }

      expect(
        (await repository.suggestions(query: '%_\\')).single.description,
        '100%_\\ café',
      );
      expect(
        (await repository.suggestions(query: '" ||')).single.description,
        '" || category != "',
      );
    });

    test('stops at 30 matching records before deduplication', () async {
      await repository.create(cents: 1, description: 'Café antigo');
      for (int index = 0; index < 30; index++) {
        await repository.create(cents: 1, description: 'Café repetido');
      }

      expect(
        (await repository.suggestions(query: 'café')).single.description,
        'Café repetido',
      );
    });

    test(
      'searches older batches and skips absent or empty descriptions',
      () async {
        final older = await repository.create(cents: 1, description: 'Agulha');
        for (int index = 0; index < 101; index++) {
          await repository.create(cents: 1, description: 'Palha');
        }
        await repository.create(cents: 1, description: '');
        await database.insert('expenses', {
          'amount': 1,
          'occurred_on': DateTime.now().toIso8601String(),
        });

        expect(
          (await repository.suggestions(query: 'AGULHA')).single.id,
          older.id,
        );
      },
    );
  });

  group('Storage failures and parsing', () {
    test(
      'preserves expected diagnostics without native messages or refresh',
      () async {
        final failing = ToStoreMock();
        when(() => failing.insert('expenses', any())).thenAnswer(
          (_) async => DbResult.error(
            type: ResultType.sysIoGeneric,
            message: 'private path and data',
          ),
        );
        final local = ExpenseRepository(
          database: failing,
          client: homeWidgetClient,
        );

        await expectLater(
          local.create(cents: 1, description: 'Teste'),
          throwsA(
            isA<ExpenseException>()
                .having(
                  (error) => error.errors.errors.single.code,
                  'code',
                  ResultType.sysIoGeneric.codeKey,
                )
                .having(
                  (error) => error.errors.errors.single.detail,
                  'detail',
                  isNull,
                ),
          ),
        );
        verifyNever(homeWidgetClient.requestMonthlyRefresh);
      },
    );

    test('does not announce a pending or failed insert', () async {
      final failing = ToStoreMock();
      final pending = Completer<DbResult>();
      when(() => failing.insert('expenses', any()))
          .thenAnswer((_) => pending.future);
      final local = ExpenseRepository(
        database: failing,
        client: homeWidgetClient,
      );
      final created = local.create(cents: 1, description: 'Teste');
      final assertion = expectLater(created, throwsA(isA<ExpenseException>()));
      verifyNever(homeWidgetClient.requestMonthlyRefresh);

      pending.complete(
        DbResult.error(type: ResultType.sysIoGeneric, message: 'private'),
      );
      await assertion;
      verifyNever(homeWidgetClient.requestMonthlyRefresh);
    });

    test('maps filesystem failures without retry', () async {
      final failing = ToStoreMock();
      when(() => failing.query('expenses'))
          .thenThrow(const FileSystemException('private'));
      final local = ExpenseRepository(
        database: failing,
        client: homeWidgetClient,
      );

      await expectLater(local.get(), throwsA(isA<ExpenseException>()));
      verify(() => failing.query('expenses')).called(1);
    });

    for (final failure in [
      StateError('private'),
      const FormatException('private'),
    ]) {
      test('classifies ${failure.runtimeType} without retry', () async {
        final failing = ToStoreMock();
        when(() => failing.query('expenses')).thenThrow(failure);
        final local = ExpenseRepository(
          database: failing,
          client: homeWidgetClient,
        );

        await expectLater(local.get(), throwsA(same(failure)));
        verify(() => failing.query('expenses')).called(1);
      });
    }

    test('propagates native developer failures', () async {
      final failing = ToStoreMock();
      final failure = DbException(
        DbResult.error(
          type: ResultType.devTableNotFound,
          message: 'private',
        ).statuses,
      );
      when(() => failing.query('expenses')).thenThrow(failure);
      final local = ExpenseRepository(
        database: failing,
        client: homeWidgetClient,
      );

      await expectLater(local.get(), throwsA(same(failure)));
    });

    test('does not replace malformed stored category with other', () async {
      final inserted = await database.insert('expenses', {
        'amount': 1,
        'description': 'Inválida',
        'category': 'unknown',
        'occurred_on': '2026-11-08T00:00:00.000Z',
      });

      await expectLater(repository.get(), throwsStateError);
      await expectLater(
        repository.getById(id: inserted.firstPrimaryKey!),
        throwsStateError,
      );
      await expectLater(
        repository.suggestions(query: 'Inválida'),
        throwsStateError,
      );
    });
  });
}
