import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/metrics/infrastructure/daos/metrics_dao.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/daos/suggestions_dao.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/infrastructure/repositories/metrics_repository.dart';

import '../../../../support/core/mocks/widget_client_mock.dart';
import '../../../../support/metrics/fakes/metrics_query_interceptor.dart';
import '../../../../support/metrics/fakes/metrics_remote_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseClient database;
  late MetricsQueryInterceptor interceptor;
  late int profileId;
  late WidgetClientMock client;
  late MetricsRepository repository;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });
  setUp(() async {
    interceptor = MetricsQueryInterceptor();
    database = DatabaseClient(
      executor: NativeDatabase.memory().interceptWith(interceptor),
    );
    profileId = await database
        .into(database.profilesTable)
        .insert(ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'));
    client = WidgetClientMock();
    when(client.monthlyRead).thenReturn(1);
    when(
      () => client.publishMonthly(
        revision: any(named: 'revision'),
        month: any(named: 'month'),
        cents: any(named: 'cents'),
      ),
    ).thenAnswer((_) async {});
    repository = MetricsRepository(
      dao: MetricsDao(client: database),
      client: client,
    );
  });
  tearDown(() => database.close());

  Future<void> insert({
    required int cents,
    String category = 'other',
    String date = '2026-10-15',
  }) async {
    await database
        .into(database.expensesTable)
        .insert(
          ExpensesTableCompanion.insert(
            profileId: profileId,
            amount: cents,
            category: Value(category),
            occurredOn: Value(date),
          ),
        );
  }

  Future<ExpenseMetricsEntity> load({MetricsGroupByEnum? groupBy}) =>
      repository.getExpenses(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
        groupBy: groupBy,
      );

  void verifyNoPublication() {
    verifyNever(
      () => client.publishMonthly(
        revision: any(named: 'revision'),
        month: any(named: 'month'),
        cents: any(named: 'cents'),
      ),
    );
  }

  group('Real SQLite monthly aggregation', () {
    test(
      'derives exact integer total and unrounded ordered percentages',
      () async {
        await insert(cents: 1, category: 'food');
        await insert(cents: 1, category: 'food');
        await insert(cents: 1, category: 'housing');

        final metrics = await load(groupBy: .category);

        expect(metrics.id, 'monthly-2026-10');
        expect(metrics.total, 3);
        expect(metrics.startDate, DateTime(2026, 10));
        expect(metrics.endDate, DateTime(2026, 10, 31));
        expect(metrics.categories!.map((item) => item.category), [
          'food',
          'housing',
        ]);
        expect(metrics.categories!.first.total, 2);
        expect(metrics.categories!.first.percentage, closeTo(200 / 3, 1e-12));
        expect(metrics.categories!.last.percentage, closeTo(100 / 3, 1e-12));
        expect(() => metrics.categories!.clear(), throwsUnsupportedError);
        verifyZeroInteractions(client);
      },
    );

    test('reads beyond expense pagination', () async {
      for (int index = 0; index < 135; index++) {
        await insert(cents: 2);
      }

      expect((await load()).total, 270);
    });

    test('preserves cents beyond JavaScript safe-integer limit', () async {
      await insert(cents: 9007199254740991, category: 'food');
      await insert(cents: 2, category: 'food');
      await insert(cents: 2);

      final metrics = await load(groupBy: .category);

      expect(metrics.total, 9007199254740995);
      expect(metrics.categories!.first.total, 9007199254740993);
    });

    test(
      'grouping is optional and empty totals keep a stable month ID',
      () async {
        final empty = await load(groupBy: .category);
        expect(empty.total, 0);
        expect(empty.categories, isEmpty);
        await insert(cents: 123);

        final metrics = await load();

        expect(metrics.id, empty.id);
        expect(metrics.total, 123);
        expect(metrics.categories, isNull);
      },
    );

    test(
      'includes civil month boundaries and excludes adjacent months',
      () async {
        await insert(cents: 1000, date: '2026-09-30');
        await insert(cents: 2, date: '2026-10-01');
        await insert(cents: 3, date: '2026-10-31');
        await insert(cents: 1000, date: '2026-11-01');

        expect((await load()).total, 5);
      },
    );

    for (final utc in [true, false]) {
      test(
        'supports leap month using civil components with utc=$utc',
        () async {
          await insert(cents: 1, date: '2024-02-01');
          await insert(cents: 2, date: '2024-02-29');
          await insert(cents: 1000, date: '2024-03-01');

          final metrics = await repository.getExpenses(
            startDate: utc
                ? DateTime.utc(2024, 2, 1, 23)
                : DateTime(2024, 2, 1, 23),
            endDate: utc
                ? DateTime.utc(2024, 2, 29, 23)
                : DateTime(2024, 2, 29, 23),
          );

          expect(metrics.total, 3);
          expect(metrics.endDate, DateTime(2024, 2, 29));
        },
      );
    }

    test('supports December to January boundary', () async {
      await insert(cents: 1, date: '2025-12-31');
      await insert(cents: 1000, date: '2026-01-01');

      final metrics = await repository.getExpenses(
        startDate: DateTime(2025, 12),
        endDate: DateTime(2025, 12, 31),
      );

      expect(metrics.total, 1);
    });

    test(
      'reflects CRUD, category changes and month moves without cached totals',
      () async {
        final expenses = ExpenseRepository(
          databaseClient: database,
          widgetClient: client,
          dao: SuggestionsDao(client: database),
        );
        final created = await expenses.create(
          cents: 100,
          description: 'Mercado',
          occurredOn: DateTime(2026, 10, 10),
          category: .food,
        );
        expect((await load()).total, 100);
        await expenses.update(id: created.id, cents: 200, category: .housing);
        final changed = await load(groupBy: .category);
        expect(changed.total, 200);
        expect(changed.categories!.single.category, 'housing');

        await expenses.update(
          id: created.id,
          occurredOn: DateTime(2026, 9, 30),
        );
        expect((await load()).total, 0);
        await expenses.update(
          id: created.id,
          occurredOn: DateTime(2026, 10, 31),
        );
        expect((await load()).total, 200);
        await expenses.delete(id: created.id);
        expect((await load()).total, 0);
      },
    );

    test('rejects unknown categories rather than substituting other', () async {
      await database.customStatement('PRAGMA ignore_check_constraints = ON');
      await insert(cents: 1, category: 'unknown');

      await expectLater(load(), throwsStateError);
      verifyNoPublication();
    });

    for (final cents in [0, -1]) {
      test('rejects invalid stored cents: $cents', () async {
        await database.customStatement('PRAGMA ignore_check_constraints = ON');
        await insert(cents: cents);

        await expectLater(load(), throwsFormatException);
      });
    }

    test('rejects category overflow', () async {
      await insert(cents: 9223372036854775807);
      await insert(cents: 1);

      await expectLater(load(), throwsA(isA<SqliteException>()));
    });

    test(
      'rejects nonpositive cents even when their group sum is positive',
      () async {
        await database.customStatement('PRAGMA ignore_check_constraints = ON');
        await insert(cents: -1);
        await insert(cents: 10);

        await expectLater(load(), throwsFormatException);
      },
    );

    for (final year in [1, 9999]) {
      test('supports the civil schema boundary in year $year', () async {
        await insert(
          cents: 1,
          date: '${year.toString().padLeft(4, '0')}-12-31',
        );

        final metrics = await repository.getExpenses(
          startDate: DateTime(year, 12),
          endDate: DateTime(year, 12, 31),
        );

        expect(metrics.total, 1);
      });
    }

    test('rejects monthly overflow across categories', () async {
      await insert(cents: 9223372036854775807, category: 'food');
      await insert(cents: 1);

      await expectLater(load(), throwsFormatException);
    });
  });

  group('Monthly period validation', () {
    for (final year in [0, 10000]) {
      test('rejects year $year before reading storage', () async {
        await expectLater(
          repository.getExpenses(
            startDate: DateTime(year, 1),
            endDate: DateTime(year, 1, 31),
          ),
          throwsArgumentError,
        );

        expect(interceptor.selects, isEmpty);
        verifyZeroInteractions(client);
      });
    }
    for (final period in [
      (name: 'start only', start: DateTime(2026, 10), end: null),
      (name: 'end only', start: null, end: DateTime(2026, 10, 31)),
      (
        name: 'partial start',
        start: DateTime(2026, 10, 2),
        end: DateTime(2026, 10, 31),
      ),
      (
        name: 'partial end',
        start: DateTime(2026, 10),
        end: DateTime(2026, 10, 30),
      ),
      (
        name: 'multiple months',
        start: DateTime(2026, 10),
        end: DateTime(2026, 11, 30),
      ),
      (name: 'reversed', start: DateTime(2026, 10), end: DateTime(2026, 9, 30)),
    ]) {
      test('rejects ${period.name} before storage or widget access', () async {
        await expectLater(
          repository.getExpenses(startDate: period.start, endDate: period.end),
          throwsA(
            isA<MetricsException>().having(
              (exception) => exception.errors.errors.single.parameter,
              'parameter',
              'period',
            ),
          ),
        );
        expect(interceptor.selects, isEmpty);
        verifyZeroInteractions(client);
      });
    }
  });

  group('Native publication and SDK failures', () {
    for (final code in [
      SqlError.SQLITE_BUSY,
      SqlError.SQLITE_LOCKED,
      SqlError.SQLITE_READONLY,
      SqlError.SQLITE_IOERR,
      SqlError.SQLITE_FULL,
      SqlError.SQLITE_CANTOPEN,
    ]) {
      for (final remote in [false, true]) {
        test('maps SQLite $code with remote=$remote without retry', () async {
          final failure = SqliteException(
            extendedResultCode: code,
            message: 'private database details',
          );
          interceptor.beforeRead = () async {
            if (remote) {
              throw MetricsRemoteException(failure, StackTrace.current);
            }
            throw failure;
          };

          await expectLater(
            repository.getExpenses(),
            throwsA(isA<MetricsException>()),
          );

          expect(interceptor.selects, hasLength(1));
          verifyNoPublication();
        });
      }
    }

    for (final code in [
      SqlError.SQLITE_ERROR,
      SqlError.SQLITE_CONSTRAINT,
      SqlError.SQLITE_CORRUPT,
      SqlError.SQLITE_TOOBIG,
    ]) {
      test('propagates unexpected SQLite $code', () async {
        final failure = SqliteException(
          extendedResultCode: code,
          message: 'unexpected',
        );
        interceptor.beforeRead = () async => throw failure;

        await expectLater(repository.getExpenses(), throwsA(same(failure)));

        verifyNoPublication();
      });
    }

    test(
      'unwraps remote unexpected failures preserving cause and stack',
      () async {
        final failure = StateError('unexpected');
        final stack = StackTrace.current;
        interceptor.beforeRead = () async =>
            throw MetricsRemoteException(failure, stack);

        try {
          await repository.getExpenses();
          fail('Expected storage failure');
        } catch (error, stackTrace) {
          expect(error, same(failure));
          expect(stackTrace, same(stack));
        }
        verifyNoPublication();
      },
    );

    test(
      'widget publication failure is not translated to storage failure',
      () async {
        const failure = FileSystemException('native publication');
        when(
          () => client.publishMonthly(
            revision: any(named: 'revision'),
            month: any(named: 'month'),
            cents: any(named: 'cents'),
          ),
        ).thenThrow(failure);

        await expectLater(repository.getExpenses(), throwsA(same(failure)));
      },
    );

    test('defaults to current month and publishes its total', () async {
      final now = DateTime.now();
      await insert(
        cents: 123,
        date: '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
      );

      expect((await repository.getExpenses()).total, 123);
      verify(
        () => client.publishMonthly(
          revision: 1,
          month: DateTime(now.year, now.month),
          cents: 123,
        ),
      ).called(1);
    });

    test(
      'awaits publication of valid zero with the original revision',
      () async {
        final started = Completer<void>();
        final published = Completer<void>();
        when(client.monthlyRead).thenReturn(7);
        when(
          () => client.publishMonthly(
            revision: 7,
            month: any(named: 'month'),
            cents: 0,
          ),
        ).thenAnswer((_) {
          started.complete();
          return published.future;
        });
        bool completed = false;
        final pending = repository.getExpenses().then((metrics) {
          completed = true;
          return metrics;
        });
        when(client.monthlyRead).thenReturn(8);

        await started.future;
        expect(completed, isFalse);
        published.complete();
        expect((await pending).total, 0);
        expect(completed, isTrue);
      },
    );

    test('captures revision before pending storage read', () async {
      final started = Completer<void>();
      final reading = Completer<void>();
      interceptor.beforeRead = () {
        started.complete();
        return reading.future;
      };
      when(client.monthlyRead).thenReturn(7);

      final pending = repository.getExpenses();
      await started.future;
      verifyNoPublication();
      when(client.monthlyRead).thenReturn(8);
      reading.complete();
      expect((await pending).total, 0);
      verify(
        () => client.publishMonthly(
          revision: 7,
          month: any(named: 'month'),
          cents: 0,
        ),
      ).called(1);
    });

    test('historical queries do not publish', () async {
      final now = DateTime.now();
      final first = DateTime(now.year, now.month - 1);

      await repository.getExpenses(
        startDate: first,
        endDate: DateTime(first.year, first.month + 1, 0),
      );

      verifyZeroInteractions(client);
    });

    test(
      'maps exposed filesystem failure without retry or fabricated zero',
      () async {
        interceptor.beforeRead = () async {
          throw const FileSystemException('private path');
        };

        await expectLater(
          repository.getExpenses(),
          throwsA(
            isA<MetricsException>().having(
              (exception) => exception.errors.errors.single.title,
              'safe title',
              'Erro desconhecido',
            ),
          ),
        );
        expect(interceptor.selects, hasLength(1));
        verifyNoPublication();
      },
    );

    for (final failure in [
      StateError('unexpected'),
      const FormatException('invalid'),
    ]) {
      test('propagates ${failure.runtimeType} without publishing', () async {
        interceptor.beforeRead = () async => throw failure;

        await expectLater(repository.getExpenses(), throwsA(same(failure)));
        verifyNoPublication();
      });
    }
  });
}
