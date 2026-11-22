import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/schemas/expense_schema.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/infrastructure/repositories/metrics_repository.dart';

import '../../../../support/core/mocks/home_widget_client_mock.dart';
import '../../../../support/core/mocks/tostore_mock.dart';
import '../../../../support/core/mocks/tostore_query_builder_mock.dart';

void main() {
  late Directory directory;
  late ToStore database;
  late MetricsRepository repository;
  late HomeWidgetClientMock homeWidgetClient;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-metrics-');
    database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: [expenseSchema],
    );
    homeWidgetClient = HomeWidgetClientMock();
    when(homeWidgetClient.beginMonthlyRead).thenReturn(1);
    when(
      () => homeWidgetClient.publishMonthlyTotal(
        revision: any(named: 'revision'),
        month: any(named: 'month'),
        cents: any(named: 'cents'),
      ),
    ).thenAnswer((_) async {});
    repository = MetricsRepository(
      database: database,
      client: homeWidgetClient,
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<void> insert({
    required int cents,
    String category = 'other',
    String date = '2026-10-15',
  }) async {
    final savedExpense = await database.insert('expenses', {
      'amount': cents,
      'category': category,
      'occurred_on': '${date}T00:00:00.000Z',
    });
    expect(savedExpense.hasErrors, isFalse);
  }

  Future<ExpenseMetricsEntity> load({ExpenseMetricsGroupByEnum? groupBy}) =>
      repository.getExpenses(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
        groupBy: groupBy,
      );

  Future<ErrorsEntity> errorsOf(Future<ExpenseMetricsEntity> operation) async {
    try {
      await operation;
      fail('Expected MetricsException');
    } on MetricsException catch (exception) {
      return exception.errors;
    }
  }

  void verifyNoPublication() {
    verifyNever(
      () => homeWidgetClient.publishMonthlyTotal(
        revision: any(named: 'revision'),
        month: any(named: 'month'),
        cents: any(named: 'cents'),
      ),
    );
  }

  group('Local monthly aggregation', () {
    test(
      'sums integer cents and derives unrounded category percentages',
      () async {
        await insert(cents: 1, category: 'food');
        await insert(cents: 1, category: 'food');
        await insert(cents: 1, category: 'housing');

        final metrics = await load(groupBy: .category);

        expect(metrics.id, 'monthly-2026-10');
        expect(metrics.totalAmount, 3);
        expect(metrics.startDate, DateTime(2026, 10));
        expect(metrics.endDate, DateTime(2026, 10, 31));
        expect(metrics.categories!.map((category) => category.category), [
          'food',
          'housing',
        ]);
        expect(metrics.categories!.first.totalAmount, 2);
        expect(metrics.categories!.first.percentage, closeTo(200 / 3, 1e-12));
        expect(metrics.categories!.last.percentage, closeTo(100 / 3, 1e-12));
        expect(() => metrics.categories!.clear(), throwsUnsupportedError);
        verifyZeroInteractions(homeWidgetClient);
      },
    );

    test('does not truncate the aggregation to an expense page', () async {
      for (int index = 0; index < 135; index++) {
        await insert(cents: 2);
      }

      expect((await load(groupBy: .category)).totalAmount, 270);
    });

    test('preserves cents beyond the JavaScript safe-integer limit', () async {
      await insert(cents: 9007199254740991, category: 'food');
      await insert(cents: 2, category: 'food');
      await insert(cents: 2, category: 'other');

      final metrics = await load(groupBy: .category);

      expect(metrics.totalAmount, 9007199254740995);
      expect(metrics.categories!.first.totalAmount, 9007199254740993);
    });

    test('keeps categories absent when no grouping is requested', () async {
      await insert(cents: 123);

      final metrics = await load();

      expect(metrics.totalAmount, 123);
      expect(metrics.categories, isNull);
    });

    test(
      'returns a successful empty grouped month without fictitious categories',
      () async {
        final metrics = await load(groupBy: .category);

        expect(metrics.totalAmount, 0);
        expect(metrics.categories, isEmpty);
        expect(metrics.id, 'monthly-2026-10');
        expect(metrics.startDate, DateTime(2026, 10));
        expect(metrics.endDate, DateTime(2026, 10, 31));
      },
    );

    test(
      'returns zero and null categories for an empty ungrouped month',
      () async {
        final metrics = await load();

        expect(metrics.totalAmount, 0);
        expect(metrics.categories, isNull);
      },
    );

    test('uses the same month ID before and after expense creation', () async {
      final empty = await load();
      await insert(cents: 1);

      expect((await load()).id, empty.id);
    });

    test(
      'includes both civil boundaries and excludes adjacent months',
      () async {
        await insert(cents: 1000, date: '2026-09-30');
        await insert(cents: 2, date: '2026-10-01');
        await insert(cents: 3, date: '2026-10-31');
        await insert(cents: 1000, date: '2026-11-01');

        expect((await load()).totalAmount, 5);
      },
    );

    for (final utc in [false, true]) {
      test('uses civil components in a leap month with utc=$utc', () async {
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

        expect(metrics.totalAmount, 3);
        expect(metrics.startDate, DateTime(2024, 2));
        expect(metrics.endDate, DateTime(2024, 2, 29));
      });
    }

    test('handles the December to January boundary', () async {
      await insert(cents: 1, date: '2025-12-31');
      await insert(cents: 1000, date: '2026-01-01');

      final metrics = await repository.getExpenses(
        startDate: DateTime(2025, 12),
        endDate: DateTime(2025, 12, 31),
      );

      expect(metrics.totalAmount, 1);
      expect(metrics.endDate, DateTime(2025, 12, 31));
    });

    test('reads persisted expenses after reopening the database', () async {
      await insert(cents: 123, category: 'food');
      await database.close();
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: [expenseSchema],
      );
      repository = MetricsRepository(
        database: database,
        client: homeWidgetClient,
      );

      final metrics = await load(groupBy: .category);

      expect(metrics.totalAmount, 123);
      expect(metrics.categories!.single.category, 'food');
    });

    test(
      'reflects CRUD, category changes and month moves without cached totals',
      () async {
        final expenses = ExpenseRepository(
          database: database,
          client: homeWidgetClient,
        );
        final created = await expenses.create(
          cents: 100,
          description: 'Mercado',
          occurredOn: DateTime(2026, 10, 10),
          category: .food,
        );
        expect((await load()).totalAmount, 100);

        await expenses.update(id: created.id, cents: 200, category: .housing);
        final changed = await load(groupBy: .category);
        expect(changed.totalAmount, 200);
        expect(changed.categories!.single.category, 'housing');

        await expenses.update(
          id: created.id,
          occurredOn: DateTime(2026, 9, 30),
        );
        expect((await load()).totalAmount, 0);

        await expenses.update(
          id: created.id,
          occurredOn: DateTime(2026, 10, 31),
        );
        expect((await load()).totalAmount, 200);

        await expenses.delete(id: created.id);
        expect((await load()).totalAmount, 0);
      },
    );

    test('rejects unknown stored categories even without grouping', () async {
      await insert(cents: 1, category: 'unknown');

      await expectLater(load(), throwsStateError);
      await expectLater(load(groupBy: .category), throwsStateError);
      verifyNoPublication();
    });
  });

  group('Monthly period validation', () {
    final invalidPeriods = [
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
    ];
    for (final period in invalidPeriods) {
      test(
        'rejects ${period.name} before accessing storage or the widget',
        () async {
          final unused = ToStoreMock();
          final local = MetricsRepository(
            database: unused,
            client: homeWidgetClient,
          );

          final errors = await errorsOf(
            local.getExpenses(startDate: period.start, endDate: period.end),
          );

          expect(errors.errors.single.title, 'Período inválido');
          expect(errors.errors.single.parameter, 'period');
          verifyZeroInteractions(unused);
          verifyZeroInteractions(homeWidgetClient);
        },
      );
    }
  });

  group('Native monthly publication', () {
    test(
      'defaults to the current month and publishes its local total',
      () async {
        final now = DateTime.now();
        final first = DateTime(now.year, now.month);
        final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        await insert(cents: 123, date: date);

        final metrics = await repository.getExpenses();

        expect(metrics.totalAmount, 123);
        expect(metrics.startDate, first);
        expect(metrics.endDate, DateTime(now.year, now.month + 1, 0));
        verify(homeWidgetClient.beginMonthlyRead).called(1);
        verify(
          () => homeWidgetClient.publishMonthlyTotal(
            revision: 1,
            month: first,
            cents: 123,
          ),
        ).called(1);
      },
    );

    test('publishes a successful empty current month as zero', () async {
      final now = DateTime.now();

      await repository.getExpenses();

      verify(
        () => homeWidgetClient.publishMonthlyTotal(
          revision: 1,
          month: DateTime(now.year, now.month),
          cents: 0,
        ),
      ).called(1);
    });

    test('historical queries do not acquire revisions or publish', () async {
      final now = DateTime.now();
      final first = DateTime(now.year, now.month - 1);

      await repository.getExpenses(
        startDate: first,
        endDate: DateTime(first.year, first.month + 1, 0),
      );

      verifyZeroInteractions(homeWidgetClient);
    });

    test(
      'awaits publication with the revision captured before reading',
      () async {
        final publishing = Completer<void>();
        final published = Completer<void>();
        when(homeWidgetClient.beginMonthlyRead).thenReturn(7);
        when(
          () => homeWidgetClient.publishMonthlyTotal(
            revision: 7,
            month: any(named: 'month'),
            cents: 0,
          ),
        ).thenAnswer((_) {
          publishing.complete();
          return published.future;
        });
        bool completed = false;

        final pending = repository.getExpenses().then((metrics) {
          completed = true;
          return metrics;
        });
        when(homeWidgetClient.beginMonthlyRead).thenReturn(8);
        await publishing.future;

        expect(completed, isFalse);
        published.complete();
        expect((await pending).totalAmount, 0);
        expect(completed, isTrue);
      },
    );

    test('malformed local data never publishes a fabricated zero', () async {
      final now = DateTime.now();
      await insert(
        cents: 1,
        category: 'unknown',
        date: '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
      );

      await expectLater(repository.getExpenses(), throwsStateError);

      verifyNoPublication();
    });
  });

  group('Storage failures', () {
    final invalidAggregations = <String, List<Map<String, dynamic>>>{
      'duplicate category groups': [
        {'category': 'food', 'total_amount': 1},
        {'category': 'food', 'total_amount': 2},
      ],
      'overflowing monthly total': [
        {'category': 'food', 'total_amount': 9223372036854775807},
        {'category': 'other', 'total_amount': 1},
      ],
    };
    for (final scenario in invalidAggregations.entries) {
      test('rejects ${scenario.key} without publishing a total', () async {
        final failing = ToStoreMock();
        final query = ToStoreQueryBuilderMock();
        when(() => failing.query('expenses')).thenAnswer((_) => query);
        when(() => query.where(any(), any(), any())).thenAnswer((_) => query);
        when(() => query.groupBy(any())).thenAnswer((_) => query);
        when(() => query.selectAgg(any())).thenAnswer((_) => query);
        when(() => query.future).thenAnswer(
          (_) async => QueryResult<Map<String, dynamic>>(
            type: ResultType.success,
            data: scenario.value,
          ),
        );
        final local = MetricsRepository(
          database: failing,
          client: homeWidgetClient,
        );

        await expectLater(local.getExpenses(), throwsFormatException);

        verifyNoPublication();
      });
    }

    test('preserves ordered native codes without storage messages', () async {
      final failing = ToStoreMock();
      final failure = DbException([
        ...DbResult.error(
          type: ResultType.sysIoGeneric,
          message: 'private',
        ).statuses,
        ...DbResult.error(
          type: ResultType.sysTimeout,
          message: 'private',
        ).statuses,
      ]);
      when(() => failing.query('expenses')).thenThrow(failure);
      final local = MetricsRepository(
        database: failing,
        client: homeWidgetClient,
      );

      final errors = await errorsOf(local.getExpenses());

      expect(
        errors.errors.map((error) => error.code),
        failure.statuses.map((status) => status.codeKey),
      );
      expect(errors.errors.every((error) => error.detail == null), isTrue);
      expect(errors.errors.every((error) => error.title == null), isTrue);
      verify(() => failing.query('expenses')).called(1);
      verifyNoPublication();
    });

    test('maps filesystem errors without retry or a published zero', () async {
      final failing = ToStoreMock();
      when(() => failing.query('expenses'))
          .thenThrow(const FileSystemException('private'));
      final local = MetricsRepository(
        database: failing,
        client: homeWidgetClient,
      );

      final errors = await errorsOf(local.getExpenses());

      expect(errors.errors.single.title, 'Erro desconhecido');
      verify(() => failing.query('expenses')).called(1);
      verifyNoPublication();
    });

    for (final failure in [
      StateError('private'),
      const FormatException('private'),
      DbException(
        DbResult.error(
          type: ResultType.devTableNotFound,
          message: 'private',
        ).statuses,
      ),
    ]) {
      test(
        'propagates ${failure.runtimeType} as unexpected without retry',
        () async {
          final failing = ToStoreMock();
          when(() => failing.query('expenses')).thenThrow(failure);
          final local = MetricsRepository(
            database: failing,
            client: homeWidgetClient,
          );

          await expectLater(local.getExpenses(), throwsA(same(failure)));

          verify(() => failing.query('expenses')).called(1);
          verifyNoPublication();
        },
      );
    }

    test(
      'checks query errors instead of publishing an empty success',
      () async {
        final failing = ToStoreMock();
        final query = ToStoreQueryBuilderMock();
        when(() => failing.query('expenses')).thenAnswer((_) => query);
        when(() => query.where(any(), any(), any())).thenAnswer((_) => query);
        when(() => query.groupBy(any())).thenAnswer((_) => query);
        when(() => query.selectAgg(any())).thenAnswer((_) => query);
        when(() => query.future).thenAnswer(
          (_) async => QueryResult<Map<String, dynamic>>(
            data: [],
            type: ResultType.sysIoGeneric,
            message: 'private',
          ),
        );
        final local = MetricsRepository(
          database: failing,
          client: homeWidgetClient,
        );

        final errors = await errorsOf(local.getExpenses());

        expect(errors.errors.single.code, ResultType.sysIoGeneric.codeKey);
        expect(errors.errors.single.detail, isNull);
        verifyNoPublication();
      },
    );

    test(
      'waits for a pending storage read and keeps its original revision',
      () async {
        final failing = ToStoreMock();
        final query = ToStoreQueryBuilderMock();
        final reading = Completer<QueryResult<Map<String, dynamic>>>();
        when(() => failing.query('expenses')).thenAnswer((_) => query);
        when(() => query.where(any(), any(), any())).thenAnswer((_) => query);
        when(() => query.groupBy(any())).thenAnswer((_) => query);
        when(() => query.selectAgg(any())).thenAnswer((_) => query);
        when(() => query.future).thenAnswer((_) => reading.future);
        when(homeWidgetClient.beginMonthlyRead).thenReturn(7);
        final local = MetricsRepository(
          database: failing,
          client: homeWidgetClient,
        );
        final pending = local.getExpenses();

        verify(homeWidgetClient.beginMonthlyRead).called(1);
        verifyNoPublication();
        when(homeWidgetClient.beginMonthlyRead).thenReturn(8);
        reading.complete(
          QueryResult<Map<String, dynamic>>(
            type: ResultType.success,
            data: [
              {'category': 'food', 'total_amount': 123},
            ],
          ),
        );

        expect((await pending).totalAmount, 123);
        verify(
          () => homeWidgetClient.publishMonthlyTotal(
            revision: 7,
            month: any(named: 'month'),
            cents: 123,
          ),
        ).called(1);
      },
    );
  });
}
