import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/insight/application/exceptions/insight_exception.dart';
import 'package:cordato/features/insight/application/repositories/interface_insight_repository.dart';
import 'package:cordato/features/insight/infrastructure/repositories/insight_repository.dart';

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
  late IInsightRepository repository;

  Future<ErrorsEntity> errorsOf(Future<Object?> operation) async {
    try {
      await operation;
      fail('Expected InsightException');
    } on InsightException catch (exception) {
      return exception.errors;
    }
  }

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    repository = InsightRepository(httpClient: client);
  });

  test(
    'gets the relative insights endpoint and preserves list order',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Responses(
          status: 200,
          body: {
            'data': [
              item,
              {...item, 'id': 'insight-2'},
            ],
          },
        ),
      );

      final data = await repository.get();

      expect(data.map((item) => item.id), ['insight-1', 'insight-2']);
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
        (_) async => const Responses(
          status: 200,
          body: {
            'data': [onboarding, item],
          },
        ),
      );

      final data = await repository.get(year: 2026, month: 9);

      expect(data.map((insight) => insight.id), [onboarding['id'], item['id']]);
      expect(data.first.period, isNull);
      expect(data.last.period, isNotNull);
      expect(data.first.group, 'onboarding');
      expect(data.first.type, 'insufficient_history');
      expect(data.first.title, 'Cada registro traz contexto');
    },
  );

  test('returns success when the API has no insights', () async {
    when(
      () => client.get(parameter: any(named: 'parameter')),
    ).thenAnswer((_) async => const Responses(status: 200, body: {'data': []}));

    expect(await repository.get(year: 2026, month: 9), isEmpty);
  });

  test(
    'serializes only non-null year and month without defaults or validation',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(status: 200, body: {'data': []}),
      );
      for (final filters in [
        (year: 2026, month: 9),
        (year: 2026, month: null),
        (year: null, month: 13),
      ]) {
        await repository.get(year: filters.year, month: filters.month);
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
        (_) async => Responses(
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
      );

      final insight = (await repository.get(year: 2026, month: 9)).single;

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
        (_) async => throw HttpResponseException.fromResponse(
          Responses(
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

      final error = (await errorsOf(repository.get(year: 2026))).errors.single;

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
      (_) async => throw HttpResponseException.fromResponse(
        Responses(
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

    final errors = (await errorsOf(repository.get())).errors;

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
          .thenAnswer((_) async => Responses(status: 200, body: body));

      await expectLater(
        repository.get(year: 2026, month: 9),
        throwsA(isA<TypeError>()),
      );
    }
  });

  test('translates malformed errors and transport failures', () async {
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
        (await errorsOf(repository.get())).errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test(
    'propagates asynchronous unexpected client exceptions unchanged',
    () async {
      final error = StateError('offline');
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => throw error);

      await expectLater(repository.get(), throwsA(same(error)));
    },
  );

  test(
    'propagates synchronous unexpected client exceptions unchanged',
    () async {
      final error = StateError('unexpected');
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenThrow(error);
      await expectLater(repository.get(), throwsA(same(error)));
    },
  );

  for (final exception in <HttpClientException>[
    for (final failure in HttpExceptionEnum.values)
      HttpTransportException(failure: failure),
    HttpInvalidResponseException(status: 200),
    HttpUnexpectedException(),
  ]) {
    test('translates $exception into a safe application failure', () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => throw exception);
      expect(
        (await errorsOf(repository.get())).errors.single.title,
        'Erro desconhecido',
      );
    });
  }

  test('propagates invalid dates instead of expected failures', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => Responses(
        status: 200,
        body: {
          'data': [
            {
              ...item,
              'attributes': {
                ...(item['attributes'] as Map<String, dynamic>),
                'period': {'from': 'not-a-date', 'to': '2026-10-08'},
              },
            },
          ],
        },
      ),
    );
    await expectLater(repository.get(), throwsA(isA<FormatException>()));
  });

  test(
    'preserves unknown groups, types, content and date components',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Responses(
          status: 200,
          body: {
            'data': [
              {
                ...item,
                'attributes': {
                  'group': 'future_group',
                  'type': 'future_type',
                  'title': ' Título original ',
                  'description': ' Descrição original ',
                  'period': {
                    'from': '2026-10-01',
                    'to': '2026-10-08',
                    'comparison': {'from': '2026-09-01', 'to': '2026-09-08'},
                  },
                },
              },
            ],
          },
        ),
      );
      final insight = (await repository.get()).single;
      expect(insight.group, 'future_group');
      expect(insight.type, 'future_type');
      expect(insight.title, ' Título original ');
      expect(insight.description, ' Descrição original ');
      expect(insight.period!.from, DateTime(2026, 10));
      expect(insight.period!.comparison!.from, DateTime(2026, 9));
      expect(insight.period!.comparison!.to, DateTime(2026, 9, 8));
    },
  );

  test('waits for HTTP completion before returning insights', () async {
    final pending = Completer<Responses>();
    when(() => client.get(parameter: any(named: 'parameter')))
        .thenAnswer((_) => pending.future);
    var completed = false;
    final response = repository.get().then((value) {
      completed = true;
      return value;
    });
    expect(completed, isFalse);
    pending.complete(
      const Responses(
        status: 200,
        body: {
          'data': [item],
        },
      ),
    );
    expect((await response).single.id, 'insight-1');
    expect(completed, isTrue);
  });
}
