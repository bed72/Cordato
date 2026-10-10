import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/infrastructure/remoto/metrics_remote_data_source.dart';

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
  late IMetricsRemoteDataSource dataSource;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    dataSource = MetricsRemoteDataSource(client: client);
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async =>
          const Right(Reponse(statusCode: 200, body: {'data': resource})),
    );
  });

  test(
    'gets the relative endpoint without filters or custom headers',
    () async {
      final result = await dataSource.getExpenses();

      expect(result.right.id, 'metrics-id');
      expect(result.right.totalAmount, 389205);
      expect(result.right.startDate, DateTime(2026, 10, 1));
      expect(result.right.endDate, DateTime(2026, 10, 31));
      expect(result.right.categories, isNull);
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'metrics/expenses');
      expect(request.query, isNull);
      expect(request.body, isNull);
      expect(request.headers, isNull);
      verifyNoMoreInteractions(client);
    },
  );

  test('serializes civil dates without times or timezone conversion', () async {
    for (final utc in [false, true]) {
      await dataSource.getExpenses(
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
        await dataSource.getExpenses(
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
      await dataSource.getExpenses(
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
      (_) async => Right(
        Reponse(
          statusCode: 200,
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
      ),
    );

    final result = await dataSource.getExpenses(groupBy: .category);

    expect(result.right.categories!.map((category) => category.category), [
      'housing',
      'future_category',
    ]);
    expect(result.right.categories!.first.totalAmount, 216000);
    expect(result.right.categories!.first.percentage, 55.50);
    expect(result.right.categories!.last.totalAmount, 7965);
    expect(result.right.categories!.last.percentage, 2.05);
  });

  test('accepts zero totals with an empty grouping', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => Right(
        Reponse(
          statusCode: 200,
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
      ),
    );

    final result = await dataSource.getExpenses(groupBy: .category);

    expect(result.right.totalAmount, 0);
    expect(result.right.categories, isEmpty);
  });

  test(
    'preserves JSON:API validation errors and their query parameter',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(
          Reponse(
            statusCode: 422,
            body: {
              'errors': [
                {
                  'detail':
                      'As datas inicial e final devem ser informadas juntas.',
                  'title': 'Parâmetro inválido',
                  'source': {'parameter': 'start_date'},
                  'status': '422',
                },
                {'detail': 'Outro erro'},
              ],
            },
          ),
        ),
      );

      final errors = (await dataSource.getExpenses(
        endDate: DateTime(2026, 10, 31),
      )).left.errors;

      expect(errors, hasLength(2));
      expect(errors.first.title, 'Parâmetro inválido');
      expect(
        errors.first.detail,
        'As datas inicial e final devem ser informadas juntas.',
      );
      expect(errors.first.status, '422');
      expect(errors.first.parameter, 'start_date');
      expect(errors.first.pointer, isNull);
      expect(errors.last.detail, 'Outro erro');
    },
  );

  test('returns an unknown error for malformed success responses', () async {
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
          .thenAnswer((_) async => Right(Reponse(statusCode: 200, body: body)));

      expect(
        (await dataSource.getExpenses()).left.errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test('preserves transport errors and translates malformed errors', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Left(
        Reponse(
          statusCode: 0,
          body: {
            'errors': [
              {'title': 'Sem conexão', 'detail': 'Tente novamente.'},
            ],
          },
        ),
      ),
    );
    expect(
      (await dataSource.getExpenses()).left.errors.single.title,
      'Sem conexão',
    );

    for (final body in <Map<String, dynamic>>[
      {},
      {'errors': []},
      {'errors': 'invalid'},
    ]) {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => Left(Reponse(statusCode: 0, body: body)));
      expect(
        (await dataSource.getExpenses()).left.errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test('translates synchronous client exceptions', () async {
    when(() => client.get(parameter: any(named: 'parameter')))
        .thenThrow(StateError('unexpected'));

    expect(
      (await dataSource.getExpenses()).left.errors.single.title,
      'Erro desconhecido',
    );
  });

  test('translates asynchronous client exceptions', () async {
    when(() => client.get(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => throw StateError('offline'));

    expect(
      (await dataSource.getExpenses()).left.errors.single.title,
      'Erro desconhecido',
    );
  });
}
