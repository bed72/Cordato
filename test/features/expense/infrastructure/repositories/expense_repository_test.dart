import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';

import '../../../../support/core/mocks/collection_ref_mock.dart';
import '../../../../support/core/mocks/document_ref_mock.dart';
import '../../../../support/core/mocks/widget_client_mock.dart';
import '../../../../support/core/mocks/localstore_mock.dart';
import '../../../../support/core/storage/localstore_test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real Localstore expenses', () {
    final storage = LocalstoreTestStorage();
    late ExpenseRepository repository;
    late WidgetClientMock client;

    setUpAll(storage.open);
    tearDownAll(storage.close);
    setUp(() {
      client = WidgetClientMock();
      repository = ExpenseRepository(
        database: storage.database,
        client: client,
      );
    });
    tearDown(storage.clear);

    Future<void> insert({
      required String id,
      int amount = 100,
      String? description,
      String category = 'other',
      String date = '2026-11-08',
    }) => storage.expense(() async {
      await storage.database.collection('expenses').doc(id).set({
        'id': id,
        'amount': amount,
        'description': description,
        'category': category,
        'occurred_on': '${date}T00:00:00.000Z',
      });
    });

    test(
      'creates exact integer cents, generated ID, defaults and civil date',
      () async {
        final created = await storage.expense(
          () => repository.create(
            cents: 9007199254740991,
            description: ' Mercado ',
            occurredOn: DateTime.utc(2026, 11, 8, 23),
          ),
        );
        final record = jsonDecode(
          await File('${storage.directory.path}/expenses/${created.id}')
              .readAsString(),
        ) as Map<String, dynamic>;

        expect(created.id, isNotEmpty);
        expect(created.cents.cents, 9007199254740991);
        expect(created.description, 'Mercado');
        expect(created.category, ExpenseCategoryEnum.other);
        expect(created.occurredOn, DateTime(2026, 11, 8));
        expect(record['occurred_on'], '2026-11-08T00:00:00.000Z');
        expect(record.containsKey('owner'), isFalse);
        verify(client.monthlyRefresh).called(1);
      },
    );

    test('defaults date to today', () async {
      final before = DateTime.now();
      final created = await storage.expense(
        () => repository.create(cents: 1, description: 'Hoje'),
      );
      final after = DateTime.now();

      expect(
        created.occurredOn,
        anyOf(
          DateTime(before.year, before.month, before.day),
          DateTime(after.year, after.month, after.day),
        ),
      );
    });

    test(
      'updates supplied fields, preserves omitted values and deletes',
      () async {
        await insert(id: 'expense', category: 'food');
        expect((await repository.getById(id: 'expense')).description, '');

        final updated = await storage.expense(
          () => repository.update(
            id: 'expense',
            cents: 200,
            description: ' Café ',
          ),
        );

        expect(updated.cents.cents, 200);
        expect(updated.description, 'Café');
        expect(updated.category, ExpenseCategoryEnum.food);
        expect(updated.occurredOn, DateTime(2026, 11, 8));
        final moved = await storage.expense(
          () => repository.update(
            id: 'expense',
            category: .other,
            description: '',
            occurredOn: DateTime(2026, 12, 1),
          ),
        );
        expect(moved.description, '');
        expect(moved.category, ExpenseCategoryEnum.other);
        expect(moved.occurredOn, DateTime(2026, 12, 1));

        await repository.delete(id: 'expense');

        expect((await repository.get()).items, isEmpty);
        verify(client.monthlyRefresh).called(3);
      },
    );

    test('empty update only reads without refresh', () async {
      await insert(id: 'expense');

      expect((await repository.update(id: 'expense')).cents.cents, 100);
      verifyNever(client.monthlyRefresh);
    });

    for (final operation in ['get', 'update', 'empty update', 'delete']) {
      test('$operation rejects missing ID without refresh', () async {
        final pending = switch (operation) {
          'get' => repository.getById(id: 'missing'),
          'update' => repository.update(id: 'missing', cents: 1),
          'empty update' => repository.update(id: 'missing'),
          _ => repository.delete(id: 'missing'),
        };

        await expectLater(pending, throwsA(isA<ExpenseException>()));
        verifyNever(client.monthlyRefresh);
      });
    }

    for (final amount in [0, -1]) {
      test('rejects $amount cents before writing or refreshing', () async {
        await insert(id: 'expense');

        await expectLater(
          repository.create(cents: amount, description: 'Inválido'),
          throwsA(isA<ExpenseException>()),
        );
        await expectLater(
          repository.update(id: 'expense', cents: amount),
          throwsA(isA<ExpenseException>()),
        );

        expect((await repository.getById(id: 'expense')).cents.cents, 100);
        verifyNever(client.monthlyRefresh);
      });
    }

    test('filters inclusive civil dates and category across pages', () async {
      for (final day in [7, 8, 9, 10]) {
        for (final category in ['food', 'other']) {
          await insert(
            id: '$category-$day',
            category: category,
            date: '2026-11-${day.toString().padLeft(2, '0')}',
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

      expect(first.items.single.id, 'food-9');
      expect(second.items.single.id, 'food-8');
      expect(second.nextPage, isNull);
      expect(() => first.items.clear(), throwsUnsupportedError);
    });

    test(
      'uses textual ID as deterministic tiebreaker rather than creation order',
      () async {
        for (final id in ['b', 'c', 'a']) {
          await insert(id: id);
        }

        final first = await repository.get(pageSize: 2);
        final second = await repository.get(pageSize: 2, page: 2);

        expect(first.items.map((item) => item.id), ['c', 'b']);
        expect(second.items.single.id, 'a');
        expect(second.nextPage, isNull);
        expect((await repository.get(page: 3, pageSize: 2)).items, isEmpty);
      },
    );

    test(
      'supports oldest date, amount and nullable description ordering',
      () async {
        await insert(
          id: 'new',
          amount: 300,
          description: 'Novo',
          date: '2026-11-09',
        );
        await insert(id: 'old', amount: 100);

        expect(
          (await repository.get(
            sort: 'occurred_on',
            pageSize: 1,
          )).items.single.id,
          'old',
        );
        expect((await repository.get(sort: '-amount')).items.first.id, 'new');
        expect(
          (await repository.get(sort: 'description')).items.first.id,
          'old',
        );
        expect((await repository.get(pageSize: 0)).items, hasLength(2));
      },
    );

    test('invalid query arguments propagate', () async {
      await expectLater(repository.get(page: 0), throwsArgumentError);
      await expectLater(repository.get(sort: 'owner'), throwsArgumentError);
      await expectLater(repository.get(category: 'unknown'), throwsStateError);
    });

    test(
      'suggestions preserve latest literal case-insensitive match',
      () async {
        await insert(
          id: 'old',
          description: 'Café',
          category: 'food',
          date: '2026-11-07',
        );
        await insert(id: 'new', description: 'CAFÉ', amount: 200);
        await insert(id: 'literal', description: '100%_\\ café');
        await insert(id: 'absent');
        await insert(id: 'empty', description: '');

        final suggestions = await repository.suggestions(query: 'cAfÉ');

        expect(suggestions.firstWhere((item) => item.id == 'new').cents, 200);
        expect(
          suggestions.firstWhere((item) => item.id == 'new').category,
          ExpenseCategoryEnum.other,
        );
        expect(suggestions.where((item) => item.id == 'old'), isEmpty);
        expect(
          (await repository.suggestions(query: '%_\\')).single.id,
          'literal',
        );
        expect(() => suggestions.clear(), throwsUnsupportedError);
      },
    );

    test(
      'suggestions stop at 30 matching records before deduplication',
      () async {
        await insert(id: 'old', description: 'Café antigo', date: '2026-11-01');
        for (int index = 0; index < 30; index++) {
          await insert(id: 'repeat-$index', description: 'Café repetido');
        }

        expect(
          (await repository.suggestions(query: 'café')).single.description,
          'Café repetido',
        );
      },
    );

    test('suggestions search history beyond a page', () async {
      await insert(id: 'old', description: 'Agulha', date: '2026-11-01');
      for (int index = 0; index < 101; index++) {
        await insert(id: 'recent-$index', description: 'Palha');
      }

      expect((await repository.suggestions(query: 'AGULHA')).single.id, 'old');
    });
  });

  group('SDK failures and pending writes', () {
    late LocalstoreMock database;
    late CollectionRefMock collection;
    late DocumentRefMock document;
    late WidgetClientMock client;
    late ExpenseRepository repository;
    final record = <String, dynamic>{
      'id': 'expense',
      'amount': 100,
      'category': 'food',
      'description': 'Mercado',
      'occurred_on': '2026-11-08T00:00:00.000Z',
    };

    setUp(() {
      database = LocalstoreMock();
      collection = CollectionRefMock();
      document = DocumentRefMock();
      client = WidgetClientMock();
      when(() => database.collection('expenses')).thenReturn(collection);
      when(() => collection.doc(any())).thenReturn(document);
      when(() => collection.doc()).thenReturn(document);
      when(() => document.id).thenReturn('expense');
      when(() => document.get()).thenAnswer((_) async => {...record});
      repository = ExpenseRepository(database: database, client: client);
    });

    test(
      'maps exposed filesystem read failure without diagnostics or refresh',
      () async {
        when(() => collection.get())
            .thenThrow(const FileSystemException('private path'));
        when(() => document.get())
            .thenThrow(const FileSystemException('private path'));

        await expectLater(repository.get(), throwsA(isA<ExpenseException>()));
        await expectLater(
          repository.suggestions(query: ''),
          throwsA(isA<ExpenseException>()),
        );
        await expectLater(
          repository.getById(id: 'expense'),
          throwsA(isA<ExpenseException>()),
        );
        verifyNever(client.monthlyRefresh);
      },
    );

    test('unexpected SDK errors and malformed records propagate', () async {
      final failure = StateError('unexpected');
      when(() => collection.get()).thenThrow(failure);
      await expectLater(repository.get(), throwsA(same(failure)));
      when(() => document.get())
          .thenAnswer((_) async => {...record, 'amount': '100'});

      await expectLater(
        repository.getById(id: 'expense'),
        throwsA(isA<TypeError>()),
      );
      verifyNever(client.monthlyRefresh);
    });

    test('refresh waits for the exposed SDK Future', () async {
      final started = Completer<void>();
      final writing = Completer<void>();
      when(() => document.set(any())).thenAnswer((_) {
        started.complete();
        return writing.future;
      });

      final creating = repository.create(cents: 100, description: 'Mercado');
      await started.future;
      verifyNever(client.monthlyRefresh);
      writing.complete();
      expect((await creating).id, 'expense');
      verify(client.monthlyRefresh).called(1);
    });

    test(
      'exposed write failure permits manual retry without false refresh',
      () async {
        when(() => document.set(any()))
            .thenThrow(const FileSystemException('private'));

        await expectLater(
          repository.update(id: 'expense', cents: 200),
          throwsA(isA<ExpenseException>()),
        );
        verifyNever(client.monthlyRefresh);
        when(() => document.set(any())).thenAnswer((_) async {});

        expect(
          (await repository.update(id: 'expense', cents: 200)).cents.cents,
          200,
        );
        verify(client.monthlyRefresh).called(1);
      },
    );
  });
}
