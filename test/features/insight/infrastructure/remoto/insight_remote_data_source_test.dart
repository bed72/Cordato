import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
            statusCode: 200,
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
          'title': 'Cada registro traz contexto',
          'type': 'insufficient_history',
          'group': 'onboarding',
          'description': 'Continue registrando suas despesas. Por enquanto, os registros não sustentam uma observação financeira.',
          'period': null,
        },
      };
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          Reponse(
            statusCode: 200,
            body: {
              'data': [onboarding, item],
            },
          ),
        ),
      );

      final data = await dataSource.get();

      expect(data.isRight, isTrue);
      expect(data.right.map((insight) => insight.id), [
        onboarding['id'],
        item['id'],
      ]);
      expect(data.right.first.title, 'Cada registro traz contexto');
      expect(data.right.first.type, 'insufficient_history');
      expect(data.right.first.group, 'onboarding');
      expect(data.right.first.period, isNull);
      expect(data.right.last.period, isNotNull);
    },
  );

  test('returns success when the API has no insights', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(Reponse(statusCode: 200, body: {'data': []})),
    );

    expect((await dataSource.get()).right, isEmpty);
  });

  test('preserves all JSON:API errors and metadata', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Left(
        Reponse(
          statusCode: 403,
          body: {
            'errors': [
              {
                'title': 'Acesso negado',
                'detail': 'Consulta não permitida.',
                'status': '403',
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
    expect(errors.first.title, 'Acesso negado');
    expect(errors.first.detail, 'Consulta não permitida.');
    expect(errors.first.status, '403');
    expect(errors.first.pointer, '/data');
    expect(errors.last.detail, 'Outro erro');
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
          .thenAnswer((_) async => Right(Reponse(statusCode: 200, body: body)));

      expect(
        (await dataSource.get()).left.errors.single.title,
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
          .thenAnswer((_) async => Left(Reponse(statusCode: 0, body: body)));

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
