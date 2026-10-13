import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';

import '../../../../support/core/mocks/http_client_mock.dart';

void main() {
  const attributes = {
    'amount': 300,
    'category': 'other',
    'description': 'Game',
    'occurred_on': '2026-10-05',
    'created_at': '2026-10-06T19:24:29+00:00',
  };

  const body = {
    'data': {'id': '9', 'type': 'expenses', 'attributes': attributes},
  };

  late DateTime occurredOn;
  late HttpClientMock client;
  late IExpenseRemoteDataSource dataSource;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    occurredOn = DateTime(2026, 10, 5, 23, 30);
    dataSource = ExpenseRemoteDataSource(client: client);
  });

  group('getById', () {
    test(
      'gets a protected relative resource and preserves every response field',
      () async {
        when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => const Right(Reponse(statusCode: 200, body: body)),
        );

        final expense = (await dataSource.getById(id: 'a/b?c#d')).right;

        expect(expense.id, '9');
        expect(expense.amount, 300);
        expect(expense.description, 'Game');
        expect(expense.occurredOn, DateTime(2026, 10, 5));
        expect(expense.category, ExpenseCategoryEnum.other);

        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;

        expect(request.body, isNull);
        expect(request.query, isNull);
        expect(request.headers, isNull);
        expect(request.path, 'expenses/a%2Fb%3Fc%23d');
      },
    );

    test(
      'preserves authentication, authorization, not found and transport errors',
      () async {
        for (final status in [401, 403, 404, 0]) {
          when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
            (_) async => Left(
              Reponse(
                statusCode: status,
                body: {
                  'errors': [
                    {
                      'status': '$status',
                      'detail': 'Tente novamente.',
                      'title': 'Despesa indisponível',
                      'source': {'pointer': '/data/id'},
                    },
                    {'title': 'Outro erro', 'status': '$status'},
                  ],
                },
              ),
            ),
          );

          final errors = (await dataSource.getById(id: '8')).left.errors;
          expect(errors, hasLength(2));
          expect(errors.first.status, '$status');
          expect(errors.last.title, 'Outro erro');
          expect(errors.first.pointer, '/data/id');
          expect(errors.first.detail, 'Tente novamente.');
          expect(errors.first.title, 'Despesa indisponível');
        }
      },
    );

    test('translates malformed error envelopes to generic errors', () async {
      for (final invalid in <Map<String, dynamic>>[
        {},
        {'errors': []},
        {'errors': 'invalid'},
      ]) {
        when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => Left(Reponse(statusCode: 500, body: invalid)),
        );
        expect(
          (await dataSource.getById(id: '8')).left.errors.single.title,
          'Erro desconhecido',
        );
      }
    });

    test(
      'rejects malformed resources and unexpected client exceptions',
      () async {
        for (final invalid in <Map<String, dynamic>>[
          {},
          {'data': null},
          for (final value in [
            {...attributes, 'amount': 3.0},
            {...attributes, 'description': null},
            {...attributes, 'occurred_on': 'invalid'},
            {...attributes, 'category': 'unknown'},
          ])
            {
              'data': {'id': '8', 'attributes': value},
            },
        ]) {
          when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
            (_) async => Right(Reponse(statusCode: 200, body: invalid)),
          );
          expect(
            (await dataSource.getById(id: '8')).left.errors.single.title,
            'Erro desconhecido',
          );
        }
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenThrow(StateError('failure'));
        expect(
          (await dataSource.getById(id: '8')).left.errors.single.title,
          'Erro desconhecido',
        );
      },
    );
  });

  test(
    'patches JSON:API attributes and preserves the returned expense',
    () async {
      when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(statusCode: 200, body: body)),
      );

      final expense = (await dataSource.update(
        id: '8',
        cents: 1500,
        description: ' Ônibus e metrô ',
        occurredOn: DateTime.utc(2026, 10, 6, 23, 30),
      )).right;

      expect(expense.id, '9');
      expect(expense.amount, 300);
      expect(expense.description, 'Game');
      expect(expense.occurredOn, DateTime(2026, 10, 5));
      expect(expense.category, ExpenseCategoryEnum.other);

      final request =
          verify(() => client.patch(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, isNull);
      expect(request.headers, isNull);
      expect(request.path, 'expenses/8');
      expect(request.body, {
        'data': {
          'type': 'expenses',
          'attributes': {
            'amount': 1500,
            'description': ' Ônibus e metrô ',
            'occurred_on': '2026-10-06',
          },
        },
      });
    },
  );

  test('encodes the update id as a single resource path segment', () async {
    when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(Reponse(statusCode: 200, body: body)),
    );

    await dataSource.update(id: 'a/b?c#d', cents: 1500);

    final request =
        verify(() => client.patch(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;

    expect(request.path, 'expenses/a%2Fb%3Fc%23d');
  });

  test('omits null update attributes and preserves supplied values', () async {
    when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(Reponse(statusCode: 200, body: body)),
    );

    for (final scenario in [
      (
        cents: 0,
        occurredOn: null,
        description: null,
        expected: <String, dynamic>{'amount': 0},
      ),
      (
        cents: null,
        description: '',
        occurredOn: null,
        expected: <String, dynamic>{'description': ''},
      ),
      (
        cents: null,
        occurredOn: null,
        description: null,
        expected: <String, dynamic>{},
      ),
      (
        cents: null,
        description: null,
        occurredOn: DateTime(2026, 1, 2, 12, 45),
        expected: <String, dynamic>{'occurred_on': '2026-01-02'},
      ),
    ]) {
      await dataSource.update(
        id: '8',
        cents: scenario.cents,
        occurredOn: scenario.occurredOn,
        description: scenario.description,
      );

      final request =
          verify(() => client.patch(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect((request.body!['data'] as Map)['attributes'], scenario.expected);
    }
  });

  test('preserves all JSON:API update errors and field pointers', () async {
    when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Left(
        Reponse(
          statusCode: 422,
          body: {
            'errors': [
              {
                'status': '422',
                'title': 'Valor inválido',
                'detail': 'Informe um valor positivo.',
                'source': {'pointer': '/data/attributes/amount'},
              },
              {
                'status': '422',
                'title': 'Descrição inválida',
                'source': {'pointer': '/data/attributes/description'},
              },
              {
                'status': '422',
                'title': 'Data inválida',
                'source': {'pointer': '/data/attributes/occurred_on'},
              },
            ],
          },
        ),
      ),
    );

    final errors = (await dataSource.update(id: '8', cents: 0)).left.errors;

    expect(errors, hasLength(3));

    expect(errors.first.status, '422');
    expect(errors.first.title, 'Valor inválido');
    expect(errors.first.pointer, '/data/attributes/amount');
    expect(errors.first.detail, 'Informe um valor positivo.');

    expect(errors[1].status, '422');
    expect(errors.last.title, 'Data inválida');
    expect(errors[1].title, 'Descrição inválida');
    expect(errors[1].pointer, '/data/attributes/description');
    expect(errors.last.pointer, '/data/attributes/occurred_on');
  });

  test(
    'preserves update authentication, permission and transport errors',
    () async {
      for (final status in [401, 403, 404, 0]) {
        when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => Left(
            Reponse(
              statusCode: status,
              body: {
                'errors': [
                  {'title': 'Falha na edição', 'status': '$status'},
                ],
              },
            ),
          ),
        );

        final error = (await dataSource.update(id: '8')).left.errors.single;

        expect(error.status, '$status');
        expect(error.title, 'Falha na edição');
      }
    },
  );

  test('translates malformed update errors to generic errors', () async {
    for (final errorBody in <Map<String, dynamic>>[
      {},
      {'errors': []},
      {'errors': 'invalid'},
    ]) {
      when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Left(Reponse(statusCode: 500, body: errorBody)),
      );

      expect(
        (await dataSource.update(id: '8')).left.errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test('translates malformed update responses to generic errors', () async {
    for (final invalidBody in <Map<String, dynamic>>[
      {},
      {'data': null},
      for (final invalidAttributes in [
        {...attributes, 'amount': 15.0},
        {...attributes, 'description': null},
        {...attributes, 'category': 'unknown'},
        {...attributes, 'occurred_on': 'invalid'},
      ])
        {
          'data': {'id': '8', 'attributes': invalidAttributes},
        },
    ]) {
      when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Right(Reponse(statusCode: 200, body: invalidBody)),
      );

      expect(
        (await dataSource.update(id: '8')).left.errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test('translates unexpected update exceptions to generic errors', () async {
    when(() => client.patch(parameter: any(named: 'parameter')))
        .thenThrow(StateError('unexpected failure'));

    expect(
      (await dataSource.update(id: '8')).left.errors.single.title,
      'Erro desconhecido',
    );
  });

  test('deletes the expense and accepts 204 without a body', () async {
    when(
      () => client.delete(parameter: any(named: 'parameter')),
    ).thenAnswer((_) async => const Right(Reponse(statusCode: 204, body: {})));

    expect((await dataSource.delete(id: '1')).right, isTrue);

    final request =
        verify(() => client.delete(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;

    expect(request.body, isNull);
    expect(request.query, isNull);
    expect(request.headers, isNull);
    expect(request.path, 'expenses/1');
  });

  test('encodes the expense id as a single resource path segment', () async {
    when(
      () => client.delete(parameter: any(named: 'parameter')),
    ).thenAnswer((_) async => const Right(Reponse(statusCode: 204, body: {})));

    await dataSource.delete(id: 'a/b?c#d');

    final request =
        verify(() => client.delete(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;

    expect(request.path, 'expenses/a%2Fb%3Fc%23d');
  });

  test('does not confirm deletion for other successful statuses', () async {
    for (final status in [200, 202]) {
      when(
        () => client.delete(parameter: any(named: 'parameter')),
      ).thenAnswer((_) async => Right(Reponse(statusCode: status, body: {})));

      expect((await dataSource.delete(id: '1')).right, isFalse);
    }
  });

  test('preserves every JSON:API deletion error', () async {
    when(() => client.delete(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Left(
        Reponse(
          statusCode: 403,
          body: {
            'errors': [
              {'title': 'Outro erro', 'status': '403'},
              {
                'status': '403',
                'title': 'Acesso negado',
                'source': {'pointer': '/data/id'},
                'detail': 'Sem permissão para excluir a despesa.',
              },
            ],
          },
        ),
      ),
    );

    final errors = (await dataSource.delete(id: '1')).left.errors;

    expect(errors, hasLength(2));
    expect(errors.last.status, '403');
    expect(errors.first.status, '403');
    expect(errors.last.pointer, '/data/id');
    expect(errors.first.title, 'Outro erro');
    expect(errors.last.title, 'Acesso negado');
    expect(errors.last.detail, 'Sem permissão para excluir a despesa.');
  });

  test(
    'preserves deletion authentication, not found and transport errors',
    () async {
      for (final status in [401, 404, 0]) {
        when(() => client.delete(parameter: any(named: 'parameter')))
            .thenAnswer(
              (_) async => Left(
                Reponse(
                  statusCode: status,
                  body: {
                    'errors': [
                      {'title': 'Falha na exclusão', 'status': '$status'},
                    ],
                  },
                ),
              ),
            );

        final error = (await dataSource.delete(id: '1')).left.errors.single;

        expect(error.status, '$status');
        expect(error.title, 'Falha na exclusão');
      }
    },
  );

  test('translates malformed deletion errors to generic errors', () async {
    for (final errorBody in <Map<String, dynamic>>[
      {},
      {'errors': []},
      {'errors': 'invalid'},
    ]) {
      when(() => client.delete(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Left(Reponse(statusCode: 500, body: errorBody)),
      );

      expect(
        (await dataSource.delete(id: '1')).left.errors.single.title,
        'Erro desconhecido',
      );
    }
  });

  test('translates unexpected deletion exceptions to generic errors', () async {
    when(() => client.delete(parameter: any(named: 'parameter')))
        .thenThrow(StateError('unexpected failure'));

    expect(
      (await dataSource.delete(id: '1')).left.errors.single.title,
      'Erro desconhecido',
    );
  });

  test(
    'gets the first page with an explicit size and preserves order',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          Reponse(
            statusCode: 200,
            body: {
              'data': [
                {'id': '9', 'type': 'expenses', 'attributes': attributes},
                {'id': '2', 'type': 'expenses', 'attributes': attributes},
              ],
              'links': {'next': '?page%5Bafter%5D=2', 'prev': null},
            },
          ),
        ),
      );

      final page = (await dataSource.get(pageSize: 6)).right;

      expect(page.prev, isNull);
      expect(page.next, '?page%5Bafter%5D=2');
      expect(page.items.map((item) => item.id), ['9', '2']);

      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.body, isNull);
      expect(request.headers, isNull);
      expect(request.path, 'expenses');
      expect(request.query, {'page[size]': 6});
    },
  );

  test(
    'uses continuation queries on the protected relative endpoint',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          Reponse(
            statusCode: 200,
            body: {
              'data': [],
              'links': {'next': null, 'prev': null},
            },
          ),
        ),
      );

      for (final link in [
        'https://trocado.test/api/expenses?page%5Bafter%5D=abc%2B123&page%5Bsize%5D=20',
        'expenses?page%5Bafter%5D=abc%2B123&page%5Bsize%5D=20',
        '?page%5Bafter%5D=abc%2B123&page%5Bsize%5D=20',
      ]) {
        final data = await dataSource.get(pageSize: 6, pageLink: link);
        expect(data.right.items, isEmpty);

        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;

        expect(request.path, 'expenses');
        expect(request.query, {'page[after]': 'abc+123', 'page[size]': 6});
      }
    },
  );

  test('preserves repeated continuation query parameters', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(
        Reponse(
          statusCode: 200,
          body: {
            'data': [],
            'links': {'next': null, 'prev': null},
          },
        ),
      ),
    );

    await dataSource.get(
      pageSize: 20,
      pageLink:
          '?page[number]=2&filter[category][]=food&filter[category][]=other',
    );

    final request =
        verify(() => client.get(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;

    expect(request.query, {
      'page[number]': '2',
      'filter[category][]': ['food', 'other'],
      'page[size]': 20,
    });
  });

  test(
    'serializes only supplied civil limits without timezone conversion',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          Reponse(
            statusCode: 200,
            body: {
              'data': [],
              'links': {'next': null, 'prev': null},
            },
          ),
        ),
      );

      final to = DateTime(2026, 9, 30, 12);
      final from = DateTime.utc(2026, 9, 1, 23, 59);

      for (final limits in [
        (from: from, to: to),
        (from: from, to: null),
        (from: null, to: to),
      ]) {
        await dataSource.get(pageSize: 6, from: limits.from, to: limits.to);
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;

        expect(request.body, isNull);
        expect(request.headers, isNull);
        expect(request.path, 'expenses');
        expect(request.query, {
          'page[size]': 6,
          if (limits.from != null) 'filter[from]': '2026-09-01',
          if (limits.to != null) 'filter[to]': '2026-09-30',
        });
      }
    },
  );

  test('reapplies explicit interval and size preserving opaque continuation parameters', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(
        Reponse(
          statusCode: 200,
          body: {
            'data': [],
            'links': {'next': null, 'prev': null},
          },
        ),
      ),
    );
    for (final suffix in [
      '',
      '&filter[from]=2025-01-01&filter[to]=2025-01-31&filter[year]=2025&filter[month]=1&filter[day]=2',
    ]) {
      await dataSource.get(
        pageSize: 20,
        to: DateTime(2026, 9, 30),
        from: DateTime(2026, 9, 1),
        pageLink:
            'https://other.example/ignored?page[after]=abc%2B123&page[size]=6&filter[category][]=food&filter[category][]=other$suffix',
      );

      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.path, 'expenses');
      expect(request.query, {
        'page[after]': 'abc+123',
        'page[size]': 20,
        'filter[category][]': ['food', 'other'],
        'filter[from]': '2026-09-01',
        'filter[to]': '2026-09-30',
      });
    }
  });

  test(
    'preserves temporal filters from continuation when no interval is supplied',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          Reponse(
            statusCode: 200,
            body: {
              'data': [],
              'links': {'next': null, 'prev': null},
            },
          ),
        ),
      );
      await dataSource.get(
        pageSize: 20,
        pageLink: '?page[number]=2&filter[year]=2026&filter[month]=9&filter[day]=1&filter[from]=2026-09-01&filter[to]=2026-09-30',
      );
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, {
        'page[number]': '2',
        'page[size]': 20,
        'filter[year]': '2026',
        'filter[month]': '9',
        'filter[day]': '1',
        'filter[from]': '2026-09-01',
        'filter[to]': '2026-09-30',
      });
    },
  );

  test(
    'preserves filter validation pointers without completing the interval',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(
          Reponse(
            statusCode: 422,
            body: {
              'errors': [
                {
                  'status': '422',
                  'title': 'Intervalo inválido',
                  'source': {'pointer': '/filter/from'},
                },
              ],
            },
          ),
        ),
      );

      final data = await dataSource.get(
        pageSize: 6,
        from: DateTime(2026, 9, 1),
      );

      expect(data.left.errors.single.status, '422');
      expect(data.left.errors.single.pointer, '/filter/from');

      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, {'page[size]': 6, 'filter[from]': '2026-09-01'});
    },
  );

  test('rejects invalid continuation links without making a request', () async {
    for (final link in ['', 'expenses', '?page[number]=2#fragment']) {
      expect(
        (await dataSource.get(pageSize: 6, pageLink: link)).isLeft,
        isTrue,
      );
    }
    verifyNoMoreInteractions(client);
  });

  test('preserves listing authentication and transport errors', () async {
    for (final status in [401, 0]) {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Left(
          Reponse(
            statusCode: status,
            body: {
              'errors': [
                {'title': 'Falha na consulta', 'status': '$status'},
              ],
            },
          ),
        ),
      );

      final errors = (await dataSource.get(pageSize: 6)).left.errors;

      expect(errors.single.status, '$status');
      expect(errors.single.title, 'Falha na consulta');
    }
  });

  test(
    'keeps explicit category and month on first and subsequent pages',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          Reponse(
            statusCode: 200,
            body: {
              'data': [],
              'links': {'next': null, 'prev': null},
            },
          ),
        ),
      );
      for (final link in [
        null,
        '?page[after]=opaque&filter[category]=travel&sort=-occurred_on',
      ]) {
        await dataSource.get(
          pageSize: 20,
          pageLink: link,
          category: 'food',
          from: DateTime.utc(2026, 9, 1, 23),
          to: DateTime(2026, 9, 30, 12),
        );
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.path, 'expenses');
        expect(request.query, {
          'page[size]': 20,
          'filter[from]': '2026-09-01',
          'filter[to]': '2026-09-30',
          'filter[category]': 'food',
          if (link != null) 'page[after]': 'opaque',
          if (link != null) 'sort': '-occurred_on',
        });
      }
    },
  );

  test(
    'preserves continuation category when no category is supplied',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          Reponse(
            statusCode: 200,
            body: {
              'data': [],
              'links': {'next': null, 'prev': null},
            },
          ),
        ),
      );
      await dataSource.get(
        pageSize: 20,
        pageLink: '?page[after]=opaque&filter[category]=food',
      );
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, {
        'page[size]': 20,
        'page[after]': 'opaque',
        'filter[category]': 'food',
      });
    },
  );

  test(
    'returns an error for malformed pages and unexpected exceptions',
    () async {
      for (final invalidBody in [
        <String, dynamic>{},
        {
          'data': {},
          'links': {'next': null, 'prev': null},
        },
        {
          'data': [
            body['data'],
            {'id': 'invalid'},
          ],
          'links': {'next': null, 'prev': null},
        },
        {
          'data': [],
          'links': {'next': 1, 'prev': null},
        },
      ]) {
        when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => Right(Reponse(statusCode: 200, body: invalidBody)),
        );
        expect((await dataSource.get(pageSize: 6)).isLeft, isTrue);
      }
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenThrow(StateError('failure'));
      expect((await dataSource.get(pageSize: 6)).isLeft, isTrue);
    },
  );

  test(
    'posts creation parameters as JSON:API and preserves the returned expense',
    () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(statusCode: 201, body: body)),
      );

      final expense = (await dataSource.create(
        cents: 300,
        description: '',
        occurredOn: occurredOn,
      )).right;

      expect(expense.id, '9');
      expect(expense.amount, 300);
      expect(expense.description, 'Game');
      expect(expense.occurredOn, DateTime(2026, 10, 5));
      expect(expense.category, ExpenseCategoryEnum.other);

      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, isNull);
      expect(request.headers, isNull);
      expect(request.path, 'expenses');
      expect(request.body, {
        'data': {
          'type': 'expenses',
          'attributes': {
            'amount': 300,
            'description': '',
            'occurred_on': '2026-10-05',
          },
        },
      });
    },
  );

  test('formats the supplied civil date without time or timezone', () async {
    when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(Reponse(statusCode: 201, body: body)),
    );

    await dataSource.create(
      cents: 1,
      description: ' Game ',
      occurredOn: .utc(2026, 1, 2, 23, 59),
    );

    final request =
        verify(() => client.post(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;

    expect((request.body!['data'] as Map)['attributes'], {
      'amount': 1,
      'description': ' Game ',
      'occurred_on': '2026-01-02',
    });
  });

  test('defaults the occurrence date to today when omitted or null', () async {
    when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(Reponse(statusCode: 201, body: body)),
    );
    for (final explicitNull in [false, true]) {
      final before = DateTime.now();
      if (explicitNull) {
        await dataSource.create(
          cents: 300,
          occurredOn: null,
          description: 'Game',
        );
      } else {
        await dataSource.create(cents: 300, description: 'Game');
      }
      final after = DateTime.now();
      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      final sent = (request.body!['data'] as Map)['attributes'] as Map;

      expect(
        DateTime.parse(sent['occurred_on'] as String),
        anyOf(
          DateTime(before.year, before.month, before.day),
          DateTime(after.year, after.month, after.day),
        ),
      );
    }
  });

  test('preserves all JSON:API error details and field pointers', () async {
    when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Left(
        Reponse(
          statusCode: 422,
          body: {
            'errors': [
              {
                'status': '422',
                'title': 'Descrição inválida',
                'detail': 'Informe uma descrição.',
                'source': {'pointer': '/data/attributes/description'},
              },
              {
                'status': '422',
                'title': 'Valor inválido',
                'source': {'pointer': '/data/attributes/amount'},
              },
            ],
          },
        ),
      ),
    );

    final errors = (await dataSource.create(
      cents: 300,
      description: '',
      occurredOn: occurredOn,
    )).left.errors;

    expect(errors, hasLength(2));

    expect(errors.first.status, '422');
    expect(errors.first.title, 'Descrição inválida');
    expect(errors.first.detail, 'Informe uma descrição.');
    expect(errors.first.pointer, '/data/attributes/description');

    expect(errors.last.pointer, '/data/attributes/amount');
  });

  test(
    'preserves authentication and transport failures from the client',
    () async {
      for (final status in [401, 0]) {
        when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => Left(
            Reponse(
              statusCode: status,
              body: {
                'errors': [
                  {'title': 'Falha', 'status': '$status'},
                ],
              },
            ),
          ),
        );

        final data = await dataSource.create(
          cents: 300,
          description: '',
          occurredOn: occurredOn,
        );

        expect(data.left.errors.single.title, 'Falha');
        expect(data.left.errors.single.status, '$status');
      }
    },
  );

  test('translates unexpected client exceptions to generic errors', () async {
    when(() => client.post(parameter: any(named: 'parameter')))
        .thenThrow(StateError('unexpected failure'));

    final data = await dataSource.create(
      cents: 300,
      description: '',
      occurredOn: occurredOn,
    );

    expect(data.left.errors.single.title, 'Erro desconhecido');
  });

  for (final errorBody in <Map<String, dynamic>>[
    {},
    {'errors': []},
  ]) {
    test(
      'translates malformed error envelope $errorBody to a generic error',
      () async {
        when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => Left(Reponse(statusCode: 500, body: errorBody)),
        );

        final data = await dataSource.create(
          cents: 300,
          description: '',
          occurredOn: occurredOn,
        );

        expect(data.left.errors.single.title, 'Erro desconhecido');
      },
    );
  }

  for (final invalidBody in <Map<String, dynamic>>[
    {},
    {'data': null},
    {
      'data': {
        'id': '9',
        'attributes': {...attributes, 'amount': 3.0},
      },
    },
    {
      'data': {
        'id': '9',
        'attributes': {...attributes, 'description': null},
      },
    },
    {
      'data': {
        'id': '9',
        'attributes': {...attributes, 'occurred_on': 'invalid'},
      },
    },
    {
      'data': {
        'id': '9',
        'attributes': {...attributes, 'category': 'unknown'},
      },
    },
  ]) {
    test(
      'translates invalid expense response $invalidBody to a generic error',
      () async {
        when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => Right(Reponse(statusCode: 201, body: invalidBody)),
        );

        final data = await dataSource.create(
          cents: 300,
          description: '',
          occurredOn: occurredOn,
        );

        expect(data.left.errors.single.title, 'Erro desconhecido');
      },
    );
  }
}
