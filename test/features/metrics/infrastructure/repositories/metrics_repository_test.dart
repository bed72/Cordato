import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';

import 'package:cordato/features/metrics/infrastructure/repositories/metrics_repository.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import '../../../../support/core/fakes/pocketbase_fixture.dart';
import '../../../../support/core/mocks/home_widget_client_mock.dart';

void main() {
  const record = {
    'id': 'metrics-id',
    'owner': 'owner-id',
    'total_amount': '389205',
    'start_date': '2026-10-01',
    'end_date': '2026-10-31',
    'categories': [
      {'category': 'housing', 'total_amount': '216000', 'percentage': 55.5},
      {
        'category': 'future_category',
        'total_amount': '7965',
        'percentage': 2.05,
      },
    ],
  };
  late PocketBaseFixture fixture;
  late HomeWidgetClientMock homeWidgetClient;
  late IMetricsRepository repository;

  void respond(Map<String, dynamic> body) {
    fixture.respond = (_) => PocketBaseFixture.jsonResponse(body);
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

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });
  setUp(() {
    fixture = PocketBaseFixture();
    fixture.authenticate(id: 'owner-id');
    addTearDown(fixture.client.close);
    homeWidgetClient = HomeWidgetClientMock();
    when(() => homeWidgetClient.beginMonthlyRead()).thenReturn(1);
    when(
      () => homeWidgetClient.publishMonthlyTotal(
        revision: any(named: 'revision'),
        month: any(named: 'month'),
        cents: any(named: 'cents'),
      ),
    ).thenAnswer((_) async {});
    repository = MetricsRepository(
      pocketBase: fixture.client,
      client: homeWidgetClient,
    );
    respond({
      'items': [record],
    });
  });

  group('Monthly view requests', () {
    test(
      'awaits widget publication with the revision captured before HTTP',
      () async {
        final now = DateTime.now();
        final first = DateTime(now.year, now.month);
        final last = DateTime(now.year, now.month + 1, 0);
        final remote = Completer<http.Response>();
        final started = Completer<void>();
        final publishing = Completer<void>();
        final published = Completer<void>();
        when(() => homeWidgetClient.beginMonthlyRead()).thenReturn(7);
        fixture.respond = (_) {
          started.complete();
          return remote.future;
        };
        when(
          () => homeWidgetClient.publishMonthlyTotal(
            revision: 7,
            month: first,
            cents: 389205,
          ),
        ).thenAnswer((_) {
          publishing.complete();
          return published.future;
        });
        var completed = false;

        final pending = repository.getExpenses().then((metrics) {
          completed = true;
          return metrics;
        });
        await started.future;
        verify(homeWidgetClient.beginMonthlyRead).called(1);
        when(() => homeWidgetClient.beginMonthlyRead()).thenReturn(8);
        remote.complete(
          PocketBaseFixture.jsonResponse({
            'items': [
              {
                ...record,
                'start_date': first.toIso8601String().split('T').first,
                'end_date': last.toIso8601String().split('T').first,
              },
            ],
          }),
        );
        await publishing.future;

        expect(completed, isFalse);
        published.complete();
        expect((await pending).totalAmount, 389205);
        expect(completed, isTrue);
      },
    );

    test('publishes the current month total returned by PocketBase', () async {
      final now = DateTime.now();
      final first = DateTime(now.year, now.month);
      final last = DateTime(now.year, now.month + 1, 0);
      respond({
        'items': [
          {
            ...record,
            'start_date': first.toIso8601String().split('T').first,
            'end_date': last.toIso8601String().split('T').first,
          },
        ],
      });

      final metrics = await repository.getExpenses();

      expect(metrics.totalAmount, 389205);
      verify(
        () => homeWidgetClient.publishMonthlyTotal(
          revision: 1,
          month: first,
          cents: 389205,
        ),
      ).called(1);
    });

    test('historical months never replace the widget total', () async {
      final now = DateTime.now();
      final first = DateTime(now.year, now.month - 1);
      final last = DateTime(first.year, first.month + 1, 0);
      respond({
        'items': [
          {
            ...record,
            'start_date': first.toIso8601String().split('T').first,
            'end_date': last.toIso8601String().split('T').first,
          },
        ],
      });

      await repository.getExpenses(startDate: first, endDate: last);

      verifyNever(homeWidgetClient.beginMonthlyRead);
      verifyNever(
        () => homeWidgetClient.publishMonthlyTotal(
          revision: any(named: 'revision'),
          month: any(named: 'month'),
          cents: any(named: 'cents'),
        ),
      );
    });

    test('publishes zero only for a successful empty current month', () async {
      final now = DateTime.now();
      final first = DateTime(now.year, now.month);
      respond({'items': []});

      await repository.getExpenses();

      verify(
        () => homeWidgetClient.publishMonthlyTotal(
          revision: 1,
          month: first,
          cents: 0,
        ),
      ).called(1);
    });

    test('invalid responses never overwrite the widget with zero', () async {
      respond({
        'items': [
          {...record, 'total_amount': 'invalid'},
        ],
      });

      await expectLater(
        repository.getExpenses(),
        throwsA(isA<FormatException>()),
      );

      verifyNever(
        () => homeWidgetClient.publishMonthlyTotal(
          revision: any(named: 'revision'),
          month: any(named: 'month'),
          cents: any(named: 'cents'),
        ),
      );
    });
    test(
      'reads the native view without client-side aggregation or owner filters',
      () async {
        final data = await load();

        expect(data.id, 'metrics-id');
        expect(data.totalAmount, 389205);
        expect(data.startDate, DateTime(2026, 10));
        expect(data.endDate, DateTime(2026, 10, 31));
        expect(data.categories, isNull);
        final captured = fixture.requests.single;
        expect(captured.url.path, '/api/collections/metrics/records');
        expect(captured.url.queryParameters, {
          'page': '1',
          'perPage': '2',
          'filter': 'start_date = "2026-10-01"',
          'skipTotal': 'true',
        });
        expect(captured.method, 'GET');
        expect(captured.body, isEmpty);
        expect(captured.headers['Authorization'], PocketBaseFixture.token);
      },
    );

    for (final utc in [false, true]) {
      test('uses civil dates for a leap month with utc=$utc', () async {
        respond({'items': []});

        final data = await repository.getExpenses(
          startDate: utc
              ? DateTime.utc(2024, 2, 1, 23)
              : DateTime(2024, 2, 1, 23),
          endDate: utc
              ? DateTime.utc(2024, 2, 29, 23)
              : DateTime(2024, 2, 29, 23),
        );

        expect(
          fixture.requests.single.url.queryParameters['filter'],
          'start_date = "2024-02-01"',
        );
        expect(data.startDate, DateTime(2024, 2));
        expect(data.endDate, DateTime(2024, 2, 29));
      });
    }

    test(
      'defaults to the current civil month when both dates are absent',
      () async {
        respond({'items': []});
        final now = DateTime.now();

        final data = await repository.getExpenses();

        expect(data.startDate, DateTime(now.year, now.month));
        expect(data.endDate, DateTime(now.year, now.month + 1, 0));
        expect(
          fixture.requests.single.url.queryParameters['filter'],
          contains(data.startDate.year.toString()),
        );
      },
    );

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
        'rejects ${period.name} without HTTP or silently changing the period',
        () async {
          final errors = await errorsOf(
            repository.getExpenses(
              startDate: period.start,
              endDate: period.end,
            ),
          );

          expect(errors.errors.single.title, 'Período inválido');
          expect(errors.errors.single.parameter, 'period');
          expect(fixture.requests, isEmpty);
          verifyZeroInteractions(homeWidgetClient);
        },
      );
    }
  });

  group('Server-calculated metrics', () {
    test('preserves category totals, percentages and order without recomputing them', () async {
      final data = await load(groupBy: .category);

      expect(data.totalAmount, 389205);
      expect(data.categories!.map((category) => category.category), [
        'housing',
        'future_category',
      ]);
      expect(data.categories!.first.totalAmount, 216000);
      expect(data.categories!.first.percentage, 55.5);
      expect(data.categories!.last.totalAmount, 7965);
      expect(data.categories!.last.percentage, 2.05);
      expect(() => data.categories!.clear(), throwsUnsupportedError);
    });

    for (final grouping in ExpenseMetricsGroupByEnum.values) {
      test(
        'returns an empty period for absent ${grouping.name} metrics',
        () async {
          respond({'items': []});

          final data = await load(groupBy: grouping);

          expect(data.totalAmount, 0);
          expect(data.categories, isEmpty);
          expect(data.startDate, DateTime(2026, 10));
          expect(data.endDate, DateTime(2026, 10, 31));
        },
      );
    }

    test(
      'returns zero with no grouping for an absent ungrouped period',
      () async {
        respond({'items': []});

        final data = await load();

        expect(data.totalAmount, 0);
        expect(data.categories, isNull);
      },
    );

    test('preserves a server record with zero totals', () async {
      respond({
        'items': [
          {...record, 'total_amount': '0', 'categories': []},
        ],
      });

      final data = await load(groupBy: .category);

      expect(data.totalAmount, 0);
      expect(data.categories, isEmpty);
      expect(data.id, 'metrics-id');
    });

    test(
      'preserves integer cents larger than the JavaScript safe-integer limit',
      () async {
        respond({
          'items': [
            {...record, 'total_amount': '9007199254740993'},
          ],
        });

        expect((await load()).totalAmount, 9007199254740993);
      },
    );

    test('waits for the view response before returning', () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      fixture.respond = (_) {
        started.complete();
        return pending.future;
      };
      var completed = false;
      final operation = load().then((value) {
        completed = true;
        return value;
      });

      await started.future;
      expect(completed, isFalse);
      pending.complete(
        PocketBaseFixture.jsonResponse({
          'items': [record],
        }),
      );

      expect((await operation).totalAmount, 389205);
      expect(completed, isTrue);
    });
  });

  group('Malformed responses', () {
    for (final envelope in <Map<String, dynamic>>[
      {},
      {'items': null},
      {'data': record},
    ]) {
      test(
        'invalid current-month envelope never becomes a published zero: $envelope',
        () async {
          respond(envelope);

          await expectLater(
            repository.getExpenses(),
            throwsA(isA<TypeError>()),
          );

          verifyNever(
            () => homeWidgetClient.publishMonthlyTotal(
              revision: any(named: 'revision'),
              month: any(named: 'month'),
              cents: any(named: 'cents'),
            ),
          );
        },
      );
    }

    for (final body in ['', 'invalid JSON', '[]', 'null']) {
      test('invalid successful response body propagates: "$body"', () async {
        fixture.respond = (_) => http.Response(body, 200);

        await expectLater(load(), throwsA(isA<TypeError>()));
      });
    }

    final malformed = <String, Map<String, dynamic>>{
      'missing items': {},
      'null items': {'items': null},
      'wrong envelope': {'data': record},
      'invalid record': {
        'items': [null],
      },
      'duplicate months': {
        'items': [record, record],
      },
      'fractional amount': {
        'items': [
          {...record, 'total_amount': '3.50'},
        ],
      },
      'numeric amount': {
        'items': [
          {...record, 'total_amount': 350},
        ],
      },
      'invalid date': {
        'items': [
          {...record, 'start_date': 'invalid'},
        ],
      },
      'different month': {
        'items': [
          {...record, 'start_date': '2026-09-01'},
        ],
      },
      'different end': {
        'items': [
          {...record, 'end_date': '2026-10-30'},
        ],
      },
      'missing grouping': {
        'items': [
          {...record, 'categories': null},
        ],
      },
      'malformed category': {
        'items': [
          {
            ...record,
            'categories': [
              {'category': 'food', 'total_amount': 'invalid', 'percentage': 1},
            ],
          },
        ],
      },
    };
    for (final scenario in malformed.entries) {
      test(
        'propagates ${scenario.key} instead of returning zero or a business failure',
        () async {
          respond(scenario.value);

          await expectLater(
            load(),
            throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
          );
        },
      );
    }
  });

  group('Failure handling', () {
    for (final status in [401, 403, 404, 422, 429, 500]) {
      test(
        'HTTP $status preserves the session and never publishes a current-month zero',
        () async {
          fixture.respond = (_) => PocketBaseFixture.jsonResponse({
            'message': 'Remote failure',
          }, status: status);
          final authRecord = fixture.client.authStore.record;

          final errors = await errorsOf(repository.getExpenses());

          expect(errors.errors.single.status, '$status');
          expect(fixture.client.authStore.token, PocketBaseFixture.token);
          expect(fixture.client.authStore.record, same(authRecord));
          verifyNever(
            () => homeWidgetClient.publishMonthlyTotal(
              revision: any(named: 'revision'),
              month: any(named: 'month'),
              cents: any(named: 'cents'),
            ),
          );
        },
      );
    }

    test('preserves ordered PocketBase errors including codes, pointers and parameters', () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({
        'message': 'Filtro inválido',
        'data': {
          'filter': {
            'code': 'validation_invalid_filter',
            'message': 'Período inválido',
          },
          'sort': {
            'code': 'validation_invalid_sort',
            'message': 'Ordenação inválida',
          },
        },
      }, status: 400);

      final errors = (await errorsOf(load())).errors;

      expect(
        errors
            .map(
              (error) => (
                error.status,
                error.code,
                error.pointer,
                error.parameter,
                error.detail,
              ),
            )
            .toList(),
        [
          (
            '400',
            'validation_invalid_filter',
            '/filter',
            'filter',
            'Período inválido',
          ),
          (
            '400',
            'validation_invalid_sort',
            '/sort',
            'sort',
            'Ordenação inválida',
          ),
        ],
      );
    });

    for (final body in <Map<String, dynamic>>[
      {},
      {'errors': []},
      {'errors': 'invalid'},
    ]) {
      test(
        'preserves HTTP status without native field errors: $body',
        () async {
          fixture.respond = (_) =>
              PocketBaseFixture.jsonResponse(body, status: 503);

          expect((await errorsOf(load())).errors.single.status, '503');
        },
      );
    }

    for (final failure in <Exception>[
      const SocketException('offline'),
      TimeoutException('timeout'),
      http.ClientException('connection closed'),
    ]) {
      test(
        'translates ${failure.runtimeType} into a safe MetricsException',
        () async {
          fixture.respond = (_) => throw failure;

          expect(
            (await errorsOf(load())).errors.single.title,
            'Erro desconhecido',
          );
        },
      );
    }

    for (final failure in [
      StateError('unexpected'),
      const FormatException('invalid payload'),
    ]) {
      for (final synchronous in [false, true]) {
        test(
          'propagates ${failure.runtimeType} unchanged with synchronous=$synchronous',
          () async {
            fixture.respond = (_) {
              if (synchronous) {
                throw failure;
              }
              return Future<http.Response>.error(failure);
            };

            await expectLater(load(), throwsA(same(failure)));
          },
        );
      }
    }
  });
}
