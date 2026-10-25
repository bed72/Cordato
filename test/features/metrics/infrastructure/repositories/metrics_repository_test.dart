import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';

import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/infrastructure/repositories/metrics_repository.dart';

import '../../../../support/core/mocks/http_client_mock.dart';

void main() {
  const attributes = {
    'total_amount': '389205',
    'start_date': '2026-10-01',
    'end_date': '2026-10-31',
  };
  const resource = {
    'id': 'metrics-id',
    'type': 'expense-metrics',
    'attributes': attributes,
  };
  late HttpClientMock client;
  late IMetricsRepository repository;

  Future<ErrorsEntity> errorsOf(Future<ExpenseMetricsEntity> request) async {
    try {
      await request;
      fail('Expected MetricsException');
    } on MetricsException catch (exception) {
      return exception.errors;
    }
  }

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    repository = MetricsRepository(httpClient: client);
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Responses(status: 200, body: {'data': resource}),
    );
  });

  test(
    'gets the relative endpoint without filters or custom headers',
    () async {
      final data = await repository.getExpenses();

      expect(data.id, 'metrics-id');
      expect(data.categories, isNull);
      expect(data.totalAmount, 389205);
      expect(data.endDate, DateTime(2026, 10, 31));
      expect(data.startDate, DateTime(2026, 10, 1));

      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.body, isNull);
      expect(request.query, isNull);
      expect(request.headers, isNull);
      expect(request.path, 'metrics/expenses');
      verifyNoMoreInteractions(client);
    },
  );

  test('serializes civil dates without times or timezone conversion', () async {
    for (final utc in [false, true]) {
      await repository.getExpenses(
        startDate: utc
            ? DateTime.utc(2026, 1, 2, 23, 59)
            : DateTime(2026, 1, 2, 23, 59),
        endDate: utc
            ? DateTime.utc(2026, 2, 3, 0, 1)
            : DateTime(2026, 2, 3, 0, 1),
      );

      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.query, {
        'start_date': '2026-01-02',
        'end_date': '2026-02-03',
      });
    }
  });

  test(
    'requests category grouping with or without an explicit period',
    () async {
      for (final explicitPeriod in [false, true]) {
        await repository.getExpenses(
          startDate: explicitPeriod ? DateTime(2026, 10, 1) : null,
          endDate: explicitPeriod ? DateTime(2026, 10, 31) : null,
          groupBy: ExpenseMetricsGroupByEnum.category,
        );

        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.query, {
          if (explicitPeriod) 'start_date': '2026-10-01',
          if (explicitPeriod) 'end_date': '2026-10-31',
          'group_by': 'category',
        });
      }
    },
  );

  test('sends an incomplete period without inventing the other date', () async {
    for (final startOnly in [true, false]) {
      await repository.getExpenses(
        startDate: startOnly ? DateTime(2026, 10, 1) : null,
        endDate: startOnly ? null : DateTime(2026, 10, 31),
      );

      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.query, {
        if (startOnly) 'start_date': '2026-10-01',
        if (!startOnly) 'end_date': '2026-10-31',
      });
    }
  });

  test('parses grouped metrics preserving categories and API order', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => Responses(
        status: 200,
        body: {
          'data': {
            ...resource,
            'attributes': {
              ...attributes,
              'categories': [
                {
                  'category': 'housing',
                  'total_amount': '216000',
                  'percentage': '55.50',
                },
                {
                  'category': 'future_category',
                  'total_amount': '7965',
                  'percentage': '2.05',
                },
              ],
            },
          },
        },
      ),
    );

    final data = await repository.getExpenses(groupBy: .category);

    expect(data.categories!.map((category) => category.category), [
      'housing',
      'future_category',
    ]);
    expect(data.categories!.last.percentage, 2.05);
    expect(data.categories!.last.totalAmount, 7965);
    expect(data.categories!.first.percentage, 55.50);
    expect(data.categories!.first.totalAmount, 216000);
    expect(() => data.categories!.clear(), throwsUnsupportedError);
  });

  test('accepts zero totals with an empty grouping', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => Responses(
        status: 200,
        body: {
          'data': {
            ...resource,
            'attributes': {
              ...attributes,
              'total_amount': '0',
              'categories': [],
            },
          },
        },
      ),
    );

    final data = await repository.getExpenses(groupBy: .category);

    expect(data.totalAmount, 0);
    expect(data.categories, isEmpty);
  });

  test(
    'preserves JSON:API validation errors and their query parameter',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => throw HttpResponseException.fromResponse(
          Responses(
            status: 422,
            body: {
              'errors': [
                {
                  'detail':
                      'As datas inicial e final devem ser informadas juntas.',
                  'title': 'Parâmetro inválido',
                  'source': {
                    'parameter': 'start_date',
                    'pointer': '/start_date',
                  },
                  'status': '422',
                },
                {'detail': 'Outro erro'},
              ],
            },
          ),
        ),
      );

      final errors = (await errorsOf(
        repository.getExpenses(endDate: DateTime(2026, 10, 31)),
      )).errors;

      expect(errors, hasLength(2));
      expect(errors.first.title, 'Parâmetro inválido');
      expect(
        errors.first.detail,
        'As datas inicial e final devem ser informadas juntas.',
      );
      expect(errors.first.status, '422');
      expect(errors.first.parameter, 'start_date');
      expect(errors.first.pointer, '/start_date');
      expect(errors.last.detail, 'Outro erro');
    },
  );

  test(
    'propagates malformed success responses instead of business failures',
    () async {
      for (final body in <Map<String, dynamic>>[
        {},
        {'data': null},
        {'data': []},
        {'data': {}},
        {
          'data': {
            ...resource,
            'attributes': {...attributes, 'total_amount': '3.50'},
          },
        },
        {
          'data': {
            ...resource,
            'attributes': {...attributes, 'start_date': 'invalid'},
          },
        },
        {
          'data': {
            ...resource,
            'attributes': {
              ...attributes,
              'categories': [
                {
                  'category': 'food',
                  'total_amount': '100',
                  'percentage': '100.00',
                },
                {
                  'category': 'housing',
                  'total_amount': 'invalid',
                  'percentage': '0',
                },
              ],
            },
          },
        },
      ]) {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => Responses(status: 200, body: body));

        await expectLater(
          repository.getExpenses(),
          throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
        );
      }
    },
  );

  test('preserves transport errors and translates malformed errors', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => throw HttpResponseException.fromResponse(
        Responses(
          status: 503,
          body: {
            'errors': [
              {'title': 'Sem conexão', 'detail': 'Tente novamente.'},
            ],
          },
        ),
      ),
    );
    expect(
      (await errorsOf(repository.getExpenses())).errors.single.title,
      'Sem conexão',
    );

    for (final body in <Map<String, dynamic>>[
      {},
      {'errors': []},
      {'errors': 'invalid'},
    ]) {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => throw HttpResponseException.fromResponse(
          Responses(status: 503, body: body),
        ),
      );
      expect(
        (await errorsOf(repository.getExpenses())).errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test(
    'propagates synchronous unexpected client exceptions unchanged',
    () async {
      final error = StateError('unexpected');
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenThrow(error);

      await expectLater(repository.getExpenses(), throwsA(same(error)));
    },
  );

  test(
    'propagates asynchronous unexpected client exceptions unchanged',
    () async {
      final error = StateError('offline');
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => throw error);

      await expectLater(repository.getExpenses(), throwsA(same(error)));
    },
  );

  for (final exception in <HttpClientException>[
    HttpTransportException(failure: HttpExceptionEnum.connection),
    HttpInvalidResponseException(status: 200),
    HttpUnexpectedException(),
  ]) {
    test(
      'translates ${exception.runtimeType} into a safe application failure',
      () async {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => throw exception);
        expect(
          (await errorsOf(repository.getExpenses())).errors.single.title,
          'Erro desconhecido',
        );
      },
    );
  }

  test(
    'preserves large integer cents without floating-point conversion',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Responses(
          status: 200,
          body: {
            'data': {
              ...resource,
              'attributes': {...attributes, 'total_amount': '9007199254740993'},
            },
          },
        ),
      );
      expect((await repository.getExpenses()).totalAmount, 9007199254740993);
    },
  );

  test('waits for HTTP completion before returning metrics', () async {
    final pending = Completer<Responses>();
    when(() => client.get(parameter: any(named: 'parameter')))
        .thenAnswer((_) => pending.future);
    var completed = false;
    final response = repository.getExpenses().then((value) {
      completed = true;
      return value;
    });
    expect(completed, isFalse);
    pending.complete(const Responses(status: 200, body: {'data': resource}));
    expect((await response).totalAmount, 389205);
    expect(completed, isTrue);
  });
}
