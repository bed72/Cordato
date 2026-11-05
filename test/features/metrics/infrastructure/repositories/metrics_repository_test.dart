import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';

import 'package:cordato/features/metrics/infrastructure/repositories/metrics_repository.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import '../../../../support/core/mocks/http_client_mock.dart';
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
  late HttpClientMock client;
  late HomeWidgetClientMock homeWidgetClient;
  late IMetricsRepository repository;

  void respond(Map<String, dynamic> body) {
    when(() => client.get(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => Responses(status: 200, body: body));
  }

  Future<ExpenseMetricsEntity> load({ExpenseMetricsGroupByEnum? groupBy}) =>
      repository.getExpenses(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
        groupBy: groupBy,
      );

  Requests request() =>
      verify(() => client.get(parameter: captureAny(named: 'parameter')))
              .captured
              .single
          as Requests;

  Future<ErrorsEntity> errorsOf(Future<ExpenseMetricsEntity> operation) async {
    try {
      await operation;
      fail('Expected MetricsException');
    } on MetricsException catch (exception) {
      return exception.errors;
    }
  }

  setUpAll(() {
    registerFallbackValue(const Requests(path: ''));
    registerFallbackValue(DateTime(2026));
  });
  setUp(() {
    client = HttpClientMock();
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
      httpClient: client,
      homeWidgetClient: homeWidgetClient,
    );
    respond({
      'items': [record],
    });
  });

  group('Monthly view requests', () {
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
        final captured = request();
        expect(captured.path, 'collections/metrics/records');
        expect(captured.query, {
          'page': 1,
          'perPage': 2,
          'filter': 'start_date = "2026-10-01"',
          'skipTotal': true,
        });
        expect(captured.body, isNull);
        expect(captured.headers, isNull);
        verifyNoMoreInteractions(client);
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

        expect(request().query!['filter'], 'start_date = "2024-02-01"');
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
          request().query!['filter'],
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
          verifyZeroInteractions(client);
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
      final pending = Completer<Responses>();
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) => pending.future);
      var completed = false;
      final operation = load().then((value) {
        completed = true;
        return value;
      });

      expect(completed, isFalse);
      pending.complete(
        const Responses(
          status: 200,
          body: {
            'items': [record],
          },
        ),
      );

      expect((await operation).totalAmount, 389205);
      expect(completed, isTrue);
    });
  });

  group('Malformed responses', () {
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
    test(
      'preserves PocketBase errors including pointers and parameters',
      () async {
        final failure = HttpResponseException.fromResponse(
          const Responses(
            status: 400,
            body: {
              'code': 400,
              'message': 'Filtro inválido',
              'data': {
                'filter': {
                  'code': 'validation_invalid_filter',
                  'message': 'Período inválido',
                },
              },
            },
          ),
        );
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenThrow(failure);

        final errors = (await errorsOf(load())).errors;
        final original = failure.errors.toEntity().errors;

        expect(errors.length, original.length);
        expect(errors.first.title, original.first.title);
        expect(errors.first.pointer, original.first.pointer);
        expect(errors.first.parameter, original.first.parameter);
        expect(errors.first.code, original.first.code);
      },
    );

    test(
      'preserves legacy remote errors without rebuilding their metadata',
      () async {
        when(() => client.get(parameter: any(named: 'parameter'))).thenThrow(
          HttpResponseException.fromResponse(
            const Responses(
              status: 422,
              body: {
                'errors': [
                  {
                    'title': 'Período inválido',
                    'source': {
                      'pointer': '/start_date',
                      'parameter': 'start_date',
                    },
                  },
                  {'detail': 'Outro erro'},
                ],
              },
            ),
          ),
        );

        final errors = (await errorsOf(load())).errors;

        expect(errors, hasLength(2));
        expect(errors.first.pointer, '/start_date');
        expect(errors.first.parameter, 'start_date');
        expect(errors.last.detail, 'Outro erro');
      },
    );

    for (final body in <Map<String, dynamic>>[
      {},
      {'errors': []},
      {'errors': 'invalid'},
    ]) {
      test('uses a safe fallback for malformed HTTP errors: $body', () async {
        when(() => client.get(parameter: any(named: 'parameter'))).thenThrow(
          HttpResponseException.fromResponse(
            Responses(status: 503, body: body),
          ),
        );

        expect(
          (await errorsOf(load())).errors.single.title,
          'Erro desconhecido',
        );
      });
    }

    for (final failure in <HttpClientException>[
      HttpTransportException(failure: HttpExceptionEnum.connection),
      HttpTransportException(failure: HttpExceptionEnum.timeout),
      HttpTransportException(failure: HttpExceptionEnum.cancelled),
      HttpInvalidResponseException(status: 200),
      HttpUnexpectedException(),
    ]) {
      test(
        'translates ${failure.runtimeType} ${failure is HttpTransportException ? failure.failure.name : ''} into MetricsException',
        () async {
          when(() => client.get(parameter: any(named: 'parameter')))
              .thenThrow(failure);

          expect(
            (await errorsOf(load())).errors.single.title,
            'Erro desconhecido',
          );
        },
      );
    }

    for (final synchronous in [false, true]) {
      test(
        'propagates an unexpected failure with synchronous=$synchronous',
        () async {
          final failure = StateError('unexpected');
          if (synchronous) {
            when(() => client.get(parameter: any(named: 'parameter')))
                .thenThrow(failure);
          } else {
            when(() => client.get(parameter: any(named: 'parameter')))
                .thenAnswer((_) async => throw failure);
          }

          await expectLater(load(), throwsA(same(failure)));
        },
      );
    }
  });
}
