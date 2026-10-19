import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/insight/infrastructure/remoto/insight_remote_data_source.dart';

import '../../../../support/core/mocks/http_client_mock.dart';

void main() {
  const item = {
    'id': 'insight-1',
    'type': 'insights',
    'attributes': {
      'group': 'comparison',
      'title': 'Mais valor registrado',
      'type': 'registered_amount_increase',
      'description': 'Você registrou 35% mais valor.',
      'period': {'from': '2026-10-01', 'to': '2026-10-08', 'comparison': null},
    },
  };
  late HttpClientMock client;
  late IInsightRemoteDataSource dataSource;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    dataSource = InsightRemoteDataSource(client: client);
  });

  test(
    'gets the relative insights endpoint and preserves list order',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Right(
          Reponse(
            status: 200,
            body: {
              'data': [
                item,
                {...item, 'id': 'insight-2'},
              ],
            },
          ),
        ),
      );

      final data = await dataSource.get();

      expect(data.right.map((item) => item.id), ['insight-1', 'insight-2']);
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.body, isNull);
      expect(request.query, isNull);
      expect(request.headers, isNull);
      expect(request.path, 'insights');
      verifyNoMoreInteractions(client);
    },
  );

  test(
    'accepts onboarding alongside dated insights without discarding the list',
    () async {
      const onboarding = {
        'id':
            '2fc73afb4eaeadb33c40d6c5df66e6333739cc91fa87f0fd1bc72335c06a0ce0',
        'type': 'insights',
        'attributes': {
          'period': null,
          'group': 'onboarding',
          'type': 'insufficient_history',
          'title': 'Cada registro traz contexto',
          'description': 'Continue registrando suas despesas. Por enquanto, os registros não sustentam uma observação financeira.',
        },
      };
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          Reponse(
            status: 200,
            body: {
              'data': [onboarding, item],
            },
          ),
        ),
      );

      final data = await dataSource.get(year: 2026, month: 9);

      expect(data.isRight, isTrue);
      expect(data.right.map((insight) => insight.id), [
        onboarding['id'],
        item['id'],
      ]);
      expect(data.right.first.period, isNull);
      expect(data.right.last.period, isNotNull);
      expect(data.right.first.group, 'onboarding');
      expect(data.right.first.type, 'insufficient_history');
      expect(data.right.first.title, 'Cada registro traz contexto');
    },
  );

  test('returns success when the API has no insights', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(Reponse(status: 200, body: {'data': []})),
    );

    expect((await dataSource.get(year: 2026, month: 9)).right, isEmpty);
  });

  test(
    'serializes only non-null year and month without defaults or validation',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(status: 200, body: {'data': []})),
      );
      for (final filters in [
        (year: 2026, month: 9),
        (year: 2026, month: null),
        (year: null, month: 13),
      ]) {
        await dataSource.get(year: filters.year, month: filters.month);
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;

        expect(request.body, isNull);
        expect(request.headers, isNull);
        expect(request.path, 'insights');
        expect(request.query, {
          'filter[year]': ?filters.year,
          'filter[month]': ?filters.month,
        });
      }
    },
  );

  test(
    'preserves multi-month periods for the requested reference month',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Right(
          Reponse(
            status: 200,
            body: {
              'data': [
                {
                  ...item,
                  'attributes': {
                    ...(item['attributes'] as Map<String, dynamic>),
                    'period': {
                      'to': '2026-09-30',
                      'from': '2026-07-01',
                      'comparison': {'from': '2026-04-01', 'to': '2026-06-30'},
                    },
                  },
                },
              ],
            },
          ),
        ),
      );

      final insight = (await dataSource.get(year: 2026, month: 9)).right.single;

      expect(insight.title, 'Mais valor registrado');
      expect(insight.period!.to, DateTime(2026, 9, 30));
      expect(insight.period!.from, DateTime(2026, 7, 1));
      expect(insight.description, 'Você registrou 35% mais valor.');
      expect(insight.period!.comparison!.to, DateTime(2026, 6, 30));
      expect(insight.period!.comparison!.from, DateTime(2026, 4, 1));
    },
  );

  test(
    'preserves missing-month validation metadata without inserting a month',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(
          Reponse(
            status: 422,
            body: {
              'errors': [
                {
                  'status': '422',
                  'detail': 'Informe o mês.',
                  'title': 'Mês obrigatório',
                  'source': {
                    'pointer': '/filter/month',
                    'parameter': 'filter[month]',
                  },
                },
              ],
            },
          ),
        ),
      );

      final error = (await dataSource.get(year: 2026)).left.errors.single;

      expect(error.status, '422');
      expect(error.detail, 'Informe o mês.');
      expect(error.pointer, '/filter/month');
      expect(error.parameter, 'filter[month]');

      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, {'filter[year]': 2026});
    },
  );

  test('preserves all JSON:API errors and metadata', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Left(
        Reponse(
          status: 403,
          body: {
            'errors': [
              {
                'status': '403',
                'title': 'Acesso negado',
                'detail': 'Consulta não permitida.',
                'source': {'pointer': '/data'},
              },
              {'detail': 'Outro erro'},
            ],
          },
        ),
      ),
    );

    final errors = (await dataSource.get()).left.errors;

    expect(errors, hasLength(2));
    expect(errors.first.status, '403');
    expect(errors.first.pointer, '/data');
    expect(errors.last.detail, 'Outro erro');
    expect(errors.first.title, 'Acesso negado');
    expect(errors.first.detail, 'Consulta não permitida.');
  });

  test('rejects a malformed page without returning partial insights', () async {
    for (final body in <Map<String, dynamic>>[
      {},
      {'data': null},
      {'data': {}},
      {
        'data': [
          item,
          {'id': 'broken'},
        ],
      },
    ]) {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => Right(Reponse(status: 200, body: body)));

      expect(
        (await dataSource.get(year: 2026, month: 9)).left.errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test('translates malformed errors and transport failures', () async {
    for (final body in <Map<String, dynamic>>[
      {},
      {'errors': []},
      {'errors': 'invalid'},
    ]) {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => Left(Reponse(status: 0, body: body)));

      expect(
        (await dataSource.get()).left.errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test('translates unexpected HTTP client exceptions', () async {
    when(() => client.get(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => throw StateError('offline'));

    expect(
      (await dataSource.get()).left.errors.single.title,
      'Erro desconhecido',
    );
  });
}
