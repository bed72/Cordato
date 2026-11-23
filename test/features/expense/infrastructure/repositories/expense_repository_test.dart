import 'dart:io';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/infrastructure/daos/suggestions_dao.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';

import '../../../../support/core/mocks/widget_client_mock.dart';
import '../../../../support/expense/fakes/expense_query_interceptor.dart';

void main() {
  group('Real SQLite expenses', () {
    late DatabaseClient database;
    late ExpenseRepository repository;
    late ExpenseQueryInterceptor interceptor;
    late WidgetClientMock client;
    late int profileId;

    setUp(() async {
      interceptor = ExpenseQueryInterceptor();
      database = DatabaseClient(
        executor: NativeDatabase.memory(
          setup: DatabaseClient.configureConnection,
        ).interceptWith(interceptor),
      );
      profileId = await database
          .into(database.profilesTable)
          .insert(ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'));
      client = WidgetClientMock();
      repository = ExpenseRepository(
        databaseClient: database,
        widgetClient: client,
        dao: SuggestionsDao(client: database),
      );
    });

    tearDown(() => database.close());

    Future<int> insert({
      int amount = 100,
      String? description,
      String category = 'other',
      String date = '2026-11-08',
    }) => database
        .into(database.expensesTable)
        .insert(
          ExpensesTableCompanion.insert(
            profileId: profileId,
            amount: amount,
            description: Value(description),
            category: Value(category),
            occurredOn: Value(date),
          ),
        );

    group('CRUD and profile', () {
      test('create, update and delete each execute one mutation without preparatory selects', () async {
        interceptor.beforeRead = () async => throw StateError('redundant read');

        final created = await repository.create(cents: 100, description: 'New');
        final updated = await repository.update(
          id: created.id,
          description: 'Updated',
        );
        await repository.delete(id: created.id);

        expect(updated.id, created.id);
        expect(updated.description, 'Updated');
        expect(interceptor.selects, isEmpty);
        expect(interceptor.writes, hasLength(3));
        expect(interceptor.inserts, 1);
        expect(interceptor.updates, 1);
        expect(interceptor.deletions, 1);
        expect(interceptor.writes[0], contains('SELECT id'));
        expect(interceptor.writes[0], contains('RETURNING'));
        expect(interceptor.writes[1], contains('RETURNING'));
        verify(client.monthlyRefresh).called(3);
      });

      test(
        'insert select notifies Drift observers only after commit',
        () async {
          final initial = Completer<void>();
          final changed = Completer<List<ExpensesTableData>>();
          final started = Completer<void>();
          final pending = Completer<void>();
          final subscription = database
              .select(database.expensesTable)
              .watch()
              .listen((rows) {
                if (rows.isEmpty && !initial.isCompleted) {
                  initial.complete();
                }
                if (rows.isNotEmpty && !changed.isCompleted) {
                  changed.complete(rows);
                }
              });
          addTearDown(subscription.cancel);
          await initial.future;
          interceptor.beforeCommit = () {
            started.complete();
            return pending.future;
          };

          final creating = repository.create(cents: 100, description: 'New');
          try {
            await started.future;
            expect(changed.isCompleted, isFalse);
            verifyNever(client.monthlyRefresh);
          } finally {
            pending.complete();
          }

          final created = await creating;
          expect((await changed.future).single.id, created.id);
        },
      );

      test(
        'creates DB-generated ID, exact cents, defaults and civil date',
        () async {
          final created = await repository.create(
            cents: 9007199254740993,
            description: ' Mercado ',
            occurredOn: DateTime.utc(2026, 11, 8, 23),
          );
          final stored = await database
              .select(database.expensesTable)
              .getSingle();

          expect(created.id, greaterThan(0));
          expect(created.cents.cents, 9007199254740993);
          expect(created.description, 'Mercado');
          expect(created.category, CategoryEnum.other);
          expect(created.occurredOn, DateTime(2026, 11, 8));
          expect(stored.profileId, profileId);
          expect(stored.occurredOn, '2026-11-08');
          expect(stored.amount, created.cents.cents);
          verify(client.monthlyRefresh).called(1);
        },
      );

      test('defaults to today without moving civil components', () async {
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
        expect(interceptor.writes.single, isNot(contains('occurred_on')));
      });

      test(
        'awaiting create makes expense immediately available to listing',
        () async {
          final created = await repository.create(
            cents: 123,
            description: 'Mercado',
          );

          final page = await repository.get();

          expect(page.items.single.id, created.id);
          expect(page.items.single.cents.cents, 123);
        },
      );

      test('preserves fields and ID across updates and deletion', () async {
        final id = await insert(category: 'food');
        expect((await repository.getById(id: id)).description, '');

        final updated = await repository.update(
          id: id,
          cents: 200,
          description: ' Café ',
        );

        expect(updated.id, id);
        expect(updated.cents.cents, 200);
        expect(updated.description, 'Café');
        expect(updated.category, CategoryEnum.food);
        expect(updated.occurredOn, DateTime(2026, 11, 8));
        final moved = await repository.update(
          id: id,
          category: .other,
          description: '',
          occurredOn: DateTime(2026, 12, 1),
        );
        expect(moved.description, '');
        expect(moved.category, CategoryEnum.other);
        expect(moved.occurredOn, DateTime(2026, 12, 1));
        expect(
          (await database.select(database.expensesTable).getSingle()).profileId,
          profileId,
        );

        await repository.delete(id: id);

        expect((await repository.get()).items, isEmpty);
        verify(client.monthlyRefresh).called(3);
      });

      test('concurrent updates preserve omitted fields', () async {
        final id = await insert(category: 'food', description: 'Old');

        await Future.wait([
          repository.update(id: id, cents: 200),
          ExpenseRepository(
            databaseClient: database,
            widgetClient: client,
            dao: SuggestionsDao(client: database),
          ).update(id: id, description: 'New'),
        ]);
        final saved = await repository.getById(id: id);

        expect(saved.cents.cents, 200);
        expect(saved.description, 'New');
        expect(saved.category, CategoryEnum.food);
        verify(client.monthlyRefresh).called(2);
      });

      test('empty update reads without SQL update or refresh', () async {
        final id = await insert();

        expect((await repository.update(id: id)).cents.cents, 100);
        expect(interceptor.updates, 0);
        verifyNever(client.monthlyRefresh);
      });

      test('category alone is a supplied update', () async {
        final id = await insert(category: 'food');

        final updated = await repository.update(id: id, category: .transport);

        expect(updated.category, CategoryEnum.transport);
        expect(interceptor.updates, 1);
        verify(client.monthlyRefresh).called(1);
      });

      test('date alone is a supplied update and preserves explicit civil components', () async {
        final id = await insert();

        final updated = await repository.update(
          id: id,
          occurredOn: DateTime.utc(2024, 2, 29, 23),
        );

        expect(updated.occurredOn, DateTime(2024, 2, 29));
        expect(interceptor.updates, 1);
        verify(client.monthlyRefresh).called(1);
      });

      test(
        'empty description is a supplied update rather than an empty update',
        () async {
          final id = await insert(description: 'Previous');

          final updated = await repository.update(id: id, description: '');

          expect(updated.description, isEmpty);
          expect(interceptor.updates, 1);
          verify(client.monthlyRefresh).called(1);
        },
      );

      test(
        'missing profile fails safely without creating another profile',
        () async {
          await database.delete(database.profilesTable).go();

          await expectLater(
            repository.create(cents: 100, description: 'Mercado'),
            throwsA(
              isA<ExpenseException>().having(
                (error) => error.errors.errors.single.code,
                'code',
                'profile_not_found',
              ),
            ),
          );

          expect(await database.select(database.profilesTable).get(), isEmpty);
          expect(await database.select(database.expensesTable).get(), isEmpty);
          verifyNever(client.monthlyRefresh);
        },
      );

      test(
        'new expenses bind to replacement profile, old IDs cannot mutate them',
        () async {
          final oldId = await insert();
          await database.delete(database.profilesTable).go();
          final newProfileId = await database
              .into(database.profilesTable)
              .insert(
                ProfilesTableCompanion.insert(
                  name: 'Cordato',
                  seed: 'new-seed',
                ),
              );

          final created = await repository.create(
            cents: 100,
            description: 'New',
          );

          expect(created.id, greaterThan(oldId));
          expect(
            (await database.select(database.expensesTable).getSingle())
                .profileId,
            newProfileId,
          );
          await expectLater(
            repository.update(id: oldId, cents: 1),
            throwsA(isA<ExpenseException>()),
          );
          await expectLater(
            repository.delete(id: oldId),
            throwsA(isA<ExpenseException>()),
          );
          expect((await repository.getById(id: created.id)).cents.cents, 100);
          verify(client.monthlyRefresh).called(1);
        },
      );

      for (final operation in ['get', 'update', 'empty update', 'delete']) {
        test('$operation rejects missing ID without refresh', () async {
          final pending = switch (operation) {
            'get' => repository.getById(id: 999),
            'update' => repository.update(id: 999, cents: 1),
            'empty update' => repository.update(id: 999),
            _ => repository.delete(id: 999),
          };

          await expectLater(
            pending,
            throwsA(
              isA<ExpenseException>().having(
                (error) => error.errors.errors.single.code,
                'code',
                'expense_not_found',
              ),
            ),
          );
          verifyNever(client.monthlyRefresh);
        });
      }

      for (final amount in [0, -1]) {
        test('rejects $amount cents before SQL mutation or refresh', () async {
          final id = await insert();
          final failure = throwsA(
            isA<ExpenseException>()
                .having(
                  (error) => error.errors.errors.single.code,
                  'code',
                  'invalid_amount',
                )
                .having(
                  (error) => error.errors.errors.single.parameter,
                  'parameter',
                  'amount',
                ),
          );

          await expectLater(
            repository.create(cents: amount, description: 'Inválido'),
            failure,
          );
          await expectLater(repository.update(id: id, cents: amount), failure);

          expect((await repository.getById(id: id)).cents.cents, 100);
          expect(interceptor.inserts, 0);
          expect(interceptor.updates, 0);
          verifyNever(client.monthlyRefresh);
        });
      }
    });

    group('SQL filtering, ordering and pagination', () {
      test(
        'filters inclusive civil dates and category across immutable pages',
        () async {
          final ids = <int, int>{};
          for (final day in [7, 8, 9, 10]) {
            for (final category in ['food', 'other']) {
              final id = await insert(
                category: category,
                date: '2026-11-${day.toString().padLeft(2, '0')}',
              );
              if (category == 'food') {
                ids[day] = id;
              }
            }
          }

          final first = await repository.get(
            category: 'food',
            from: DateTime(2026, 11, 8, 23),
            to: DateTime.utc(2026, 11, 9, 1),
            pageSize: 1,
          );
          final second = await repository.get(
            category: 'food',
            from: DateTime(2026, 11, 8),
            to: DateTime(2026, 11, 9),
            pageSize: 1,
            page: first.nextPage!,
          );

          expect(first.items.single.id, ids[9]);
          expect(second.items.single.id, ids[8]);
          expect(second.nextPage, isNull);
          expect(() => first.items.clear(), throwsUnsupportedError);
          expect(interceptor.selects.last, contains('WHERE'));
          expect(interceptor.selects.last, contains('ORDER BY'));
          expect(interceptor.selects.last, contains('LIMIT'));
          expect(interceptor.selects.last, contains('OFFSET'));
        },
      );

      test('uses numeric ID as deterministic tie breaker', () async {
        for (int index = 0; index < 12; index++) {
          await insert();
        }

        final first = await repository.get(pageSize: 2);
        final second = await repository.get(pageSize: 2, page: 2);

        expect(first.items.map((item) => item.id), [12, 11]);
        expect(second.items.map((item) => item.id), [10, 9]);
        expect((await repository.get(page: 7, pageSize: 2)).items, isEmpty);
        expect(
          (await repository.get(
            sort: 'id',
            pageSize: 2,
          )).items.map((item) => item.id),
          [1, 2],
        );
      });

      test('supports oldest date, amount, category and nullable description ordering', () async {
        final newest = await insert(
          amount: 300,
          description: 'Novo',
          date: '2026-11-09',
          category: 'food',
        );
        final oldest = await insert(amount: 100);

        expect(
          (await repository.get(
            sort: 'occurred_on',
            pageSize: 1,
          )).items.single.id,
          oldest,
        );
        expect((await repository.get(sort: '-amount')).items.first.id, newest);
        expect(
          (await repository.get(sort: 'description')).items.first.id,
          oldest,
        );
        expect((await repository.get(sort: 'category')).items.first.id, newest);
        expect(
          (await repository.get(sort: 'amount,occurred_on')).items.first.id,
          oldest,
        );
        expect((await repository.get(pageSize: 0)).items, hasLength(2));
      });

      test(
        'non-ID ordering appends ascending numeric ID as a stable tie breaker',
        () async {
          final first = await insert();
          final second = await insert();

          expect(
            (await repository.get(sort: 'amount')).items.map((item) => item.id),
            [first, second],
          );
        },
      );

      test('invalid arguments and SQL-like sort input fail before executing a query', () async {
        await expectLater(repository.get(page: 0), throwsArgumentError);
        await expectLater(repository.get(sort: 'owner'), throwsArgumentError);
        await expectLater(
          repository.get(sort: 'id; DROP TABLE expenses'),
          throwsArgumentError,
        );
        await expectLater(
          repository.get(category: 'unknown'),
          throwsStateError,
        );
        await expectLater(
          repository.get(from: DateTime.utc(0)),
          throwsArgumentError,
        );
        expect(interceptor.selects, isEmpty);
      });

      test(
        'unknown stored category propagates instead of producing a default',
        () async {
          await database.customStatement(
            'PRAGMA ignore_check_constraints = ON',
          );
          final id = await insert(category: 'unknown');

          await expectLater(repository.get(), throwsStateError);
          await expectLater(repository.getById(id: id), throwsStateError);
          await expectLater(
            repository.update(id: id, description: 'Changed'),
            throwsStateError,
          );
          expect(
            (await database.select(database.expensesTable).getSingle())
                .description,
            isNull,
          );
          verifyNever(client.monthlyRefresh);
        },
      );
    });

    group('Suggestions', () {
      test('preserves latest literal Unicode case-insensitive match and category other', () async {
        final oldId = await insert(
          description: 'Café',
          category: 'food',
          date: '2026-11-07',
        );
        final newest = await insert(description: 'CAFÉ', amount: 200);
        final literal = await insert(description: '100%_\\ café');
        await insert();
        await insert(description: '');

        final suggestions = await repository.suggestions(query: 'cAfÉ');

        expect(suggestions.firstWhere((item) => item.id == newest).cents, 200);
        expect(
          suggestions.firstWhere((item) => item.id == newest).category,
          CategoryEnum.other,
        );
        expect(suggestions.where((item) => item.id == oldId), isEmpty);
        expect(
          (await repository.suggestions(query: '%_\\')).single.id,
          literal,
        );
        expect(() => suggestions.clear(), throwsUnsupportedError);
      });

      test('stops at 30 matching records before deduplication', () async {
        await insert(description: 'Café antigo', date: '2026-11-01');
        for (int index = 0; index < 30; index++) {
          await insert(description: 'Café repetido');
        }

        expect(
          (await repository.suggestions(query: 'café')).single.description,
          'Café repetido',
        );
      });

      test('searches history with one SQL statement without losing literal matches', () async {
        final oldest = await insert(description: 'Agulha', date: '2026-11-01');
        for (int index = 0; index < 101; index++) {
          await insert(description: 'Palha');
        }

        expect(
          (await repository.suggestions(query: 'AGULHA')).single.id,
          oldest,
        );
        expect(interceptor.selects, hasLength(1));
        expect(
          interceptor.selects.every((statement) => statement.contains('LIMIT')),
          isTrue,
        );
      });

      test('empty query skips null and empty descriptions', () async {
        await insert();
        await insert(description: '');
        final id = await insert(description: 'Mercado');

        expect((await repository.suggestions(query: '')).single.id, id);
      });

      test('unknown category in a matching suggestion propagates', () async {
        await database.customStatement('PRAGMA ignore_check_constraints = ON');
        await insert(description: 'Mercado', category: 'unknown');

        await expectLater(
          repository.suggestions(query: 'mercado'),
          throwsStateError,
        );
      });
    });

    group('Failures and pending operations', () {
      test(
        'delete awaits atomic SQL completion without an explicit transaction',
        () async {
          final id = await insert();
          final started = Completer<void>();
          final pending = Completer<void>();
          interceptor.beforeCommit = () async =>
              throw StateError('unexpected transaction');
          interceptor.beforeDelete = () {
            started.complete();
            return pending.future;
          };
          bool completed = false;
          final deleting = repository.delete(id: id).then((_) {
            completed = true;
          });

          try {
            await started.future;
            expect(completed, isFalse);
            verifyNever(client.monthlyRefresh);
          } finally {
            pending.complete();
          }

          await deleting;
          expect(completed, isTrue);
          expect(await database.select(database.expensesTable).get(), isEmpty);
          verify(client.monthlyRefresh).called(1);
        },
      );

      test(
        'filesystem read failure is safe for every read operation',
        () async {
          final id = await insert();
          interceptor.beforeRead = () async =>
              throw const FileSystemException('private path');

          await expectLater(repository.get(), throwsA(isA<ExpenseException>()));
          await expectLater(
            repository.suggestions(query: ''),
            throwsA(isA<ExpenseException>()),
          );
          await expectLater(
            repository.getById(id: id),
            throwsA(isA<ExpenseException>()),
          );
          verifyNever(client.monthlyRefresh);
        },
      );

      for (final operation in ['update', 'delete']) {
        test(
          '$operation operational write failure rolls back without refresh',
          () async {
            final id = await insert();
            Future<void> failWrite() async => throw SqliteException(
              extendedResultCode: SqlError.SQLITE_IOERR,
              message: 'private diagnostic',
            );
            switch (operation) {
              case 'update':
                interceptor.beforeUpdate = failWrite;
              case 'delete':
                interceptor.beforeDelete = failWrite;
            }
            final mutation = switch (operation) {
              'update' => repository.update(id: id, cents: 200),
              _ => repository.delete(id: id),
            };

            await expectLater(mutation, throwsA(isA<ExpenseException>()));

            expect((await repository.getById(id: id)).cents.cents, 100);
            verifyNever(client.monthlyRefresh);
          },
        );
      }

      for (final code in [
        SqlError.SQLITE_BUSY,
        SqlError.SQLITE_LOCKED,
        SqlError.SQLITE_READONLY,
        SqlError.SQLITE_IOERR,
        SqlExtendedError.SQLITE_IOERR_READ,
        SqlError.SQLITE_FULL,
        SqlError.SQLITE_CANTOPEN,
      ]) {
        test(
          'maps operational SQLite failure $code without native diagnostics',
          () async {
            interceptor.beforeRead = () async => throw SqliteException(
              extendedResultCode: code,
              message: 'private path',
            );

            await expectLater(
              repository.get(),
              throwsA(isA<ExpenseException>()),
            );
            await expectLater(
              repository.getById(id: 1),
              throwsA(isA<ExpenseException>()),
            );
            await expectLater(
              repository.suggestions(query: ''),
              throwsA(isA<ExpenseException>()),
            );
            verifyNever(client.monthlyRefresh);
          },
        );
      }

      for (final failure in [
        StateError('unexpected'),
        TypeError(),
        const FormatException('invalid'),
        SqliteException(
          extendedResultCode: SqlError.SQLITE_ERROR,
          message: 'SQL',
        ),
        SqliteException(
          extendedResultCode: SqlError.SQLITE_CONSTRAINT,
          message: 'constraint',
        ),
        SqliteException(
          extendedResultCode: SqlError.SQLITE_CORRUPT,
          message: 'corrupt',
        ),
      ]) {
        test('propagates unexpected $failure without refresh', () async {
          interceptor.beforeRead = () async => throw failure;

          await expectLater(repository.get(), throwsA(same(failure)));
          await expectLater(repository.getById(id: 1), throwsA(same(failure)));
          await expectLater(
            repository.suggestions(query: ''),
            throwsA(same(failure)),
          );
          verifyNever(client.monthlyRefresh);
        });
      }

      for (final operation in ['create', 'update']) {
        test(
          '$operation awaits commit before refresh and completion',
          () async {
            final id = await insert();
            final started = Completer<void>();
            final pending = Completer<void>();
            interceptor.beforeCommit = () {
              started.complete();
              return pending.future;
            };
            bool completed = false;
            final mutation = switch (operation) {
              'create' => repository.create(cents: 100, description: 'New'),
              'update' => repository.update(id: id, cents: 200),
              _ => repository.delete(id: id),
            };
            final completion = mutation.then((_) {
              completed = true;
            });

            try {
              await started.future;
              verifyNever(client.monthlyRefresh);
              expect(completed, isFalse);
            } finally {
              pending.complete();
            }

            await completion;
            expect(completed, isTrue);
            verify(client.monthlyRefresh).called(1);
          },
        );

        test(
          '$operation rolls back commit failure without refresh and allows manual retry',
          () async {
            final id = await insert(description: 'Original');
            interceptor.beforeCommit = () async =>
                throw const FileSystemException('private path');
            Future<void> mutate() async {
              switch (operation) {
                case 'create':
                  await repository.create(cents: 200, description: 'New');
                case 'update':
                  await repository.update(id: id, cents: 200);
                case 'delete':
                  await repository.delete(id: id);
              }
            }

            await expectLater(mutate(), throwsA(isA<ExpenseException>()));

            final stored = await database.select(database.expensesTable).get();
            expect(stored, hasLength(1));
            expect(stored.single.id, id);
            expect(stored.single.amount, 100);
            verifyNever(client.monthlyRefresh);

            interceptor.beforeCommit = null;
            await mutate();
            verify(client.monthlyRefresh).called(1);
          },
        );
      }

      test('failed insert does not persist data or refresh', () async {
        interceptor.beforeInsert = () async => throw SqliteException(
          extendedResultCode: SqlError.SQLITE_FULL,
          message: 'private',
        );

        await expectLater(
          repository.create(cents: 100, description: 'New'),
          throwsA(isA<ExpenseException>()),
        );

        expect(await database.select(database.expensesTable).get(), isEmpty);
        verifyNever(client.monthlyRefresh);
      });

      test('unexpected write failure propagates without refresh', () async {
        final id = await insert();
        final failure = StateError('write');
        interceptor.beforeUpdate = () async => throw failure;

        await expectLater(
          repository.update(id: id, cents: 200),
          throwsA(same(failure)),
        );

        expect((await repository.getById(id: id)).cents.cents, 100);
        verifyNever(client.monthlyRefresh);
      });
    });
  });

  group('File and background isolate', () {
    test('preserves expenses and profile relation after reopening', () async {
      final directory = await Directory.systemTemp.createTemp(
        'cordato-expense-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/cordato.sqlite');
      final first = DatabaseClient(
        executor: NativeDatabase.createInBackground(
          file,
          setup: DatabaseClient.configureConnection,
        ),
      );
      final client = WidgetClientMock();
      late int savedId;
      late int profileId;

      try {
        profileId = await first
            .into(first.profilesTable)
            .insert(
              ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'),
            );
        final created =
            await ExpenseRepository(
              databaseClient: first,
              widgetClient: client,
              dao: SuggestionsDao(client: first),
            ).create(
              cents: 9007199254740993,
              description: 'Café',
              category: .food,
              occurredOn: DateTime.utc(2026, 11, 8, 23),
            );
        savedId = created.id;
      } finally {
        await first.close();
      }

      final reopened = DatabaseClient(
        executor: NativeDatabase.createInBackground(
          file,
          setup: DatabaseClient.configureConnection,
        ),
      );
      try {
        final repository = ExpenseRepository(
          databaseClient: reopened,
          widgetClient: client,
          dao: SuggestionsDao(client: reopened),
        );
        final expense = await repository.getById(id: savedId);
        expect(expense.cents.cents, 9007199254740993);
        expect(expense.description, 'Café');
        expect(
          (await repository.suggestions(query: 'CAFÉ')).single.id,
          savedId,
        );
        expect(expense.category, CategoryEnum.food);
        expect(expense.occurredOn, DateTime(2026, 11, 8));
        expect(
          (await reopened.select(reopened.expensesTable).getSingle()).profileId,
          profileId,
        );

        await reopened.customStatement('PRAGMA query_only = ON');
        await expectLater(
          repository.update(id: savedId, cents: 1),
          throwsA(isA<ExpenseException>()),
        );
        await reopened.customStatement('PRAGMA query_only = OFF');
        expect(
          (await repository.getById(id: savedId)).cents.cents,
          9007199254740993,
        );

        await reopened.customStatement('DROP TABLE expenses');
        await expectLater(
          repository.get(),
          throwsA(
            isA<SqliteException>().having(
              (error) => error.resultCode,
              'resultCode',
              SqlError.SQLITE_ERROR,
            ),
          ),
        );
        verify(client.monthlyRefresh).called(1);
      } finally {
        await reopened.close();
      }
    });
  });
}
