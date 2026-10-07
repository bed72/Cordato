import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';

import '../../../../support/core/mocks/http_client_mock.dart';

void main() {
  const attributes = {
    'amount': 300,
    'occurred_on': '2026-10-05',
    'description': 'Game',
    'category': 'other',
    'created_at': '2026-10-06T19:24:29+00:00',
  };
  const body = {
    'data': {'id': '9', 'type': 'expenses', 'attributes': attributes},
  };

  late HttpClientMock client;
  late IExpenseRemoteDataSource dataSource;
  late CreateExpenseInput input;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    dataSource = ExpenseRemoteDataSource(client: client);
    input = CreateExpenseInput(
      cents: 300,
      description: '',
      occurredOn: DateTime(2026, 10, 5, 23, 30),
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

      expect(page.items.map((item) => item.id), ['9', '2']);
      expect(page.next, '?page%5Bafter%5D=2');
      expect(page.prev, isNull);
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'expenses');
      expect(request.query, {'page[size]': 6});
      expect(request.headers, isNull);
      expect(request.body, isNull);
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
        final result = await dataSource.get(pageSize: 6, pageLink: link);
        expect(result.right.items, isEmpty);
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
      expect(errors.single.title, 'Falha na consulta');
      expect(errors.single.status, '$status');
    }
  });

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
    'posts the input as JSON:API and preserves the returned expense',
    () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(statusCode: 201, body: body)),
      );

      final expense = (await dataSource.create(input: input)).right;

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
      expect(request.path, 'expenses');
      expect(request.headers, isNull);
      expect(request.query, isNull);
      expect(request.body, {
        'data': {
          'type': 'expenses',
          'attributes': {
            'amount': 300,
            'occurred_on': '2026-10-05',
            'description': '',
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
      input: CreateExpenseInput(
        cents: 1,
        description: ' Game ',
        occurredOn: DateTime.utc(2026, 1, 2, 23, 59),
      ),
    );

    final request =
        verify(() => client.post(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect((request.body!['data'] as Map)['attributes'], {
      'amount': 1,
      'occurred_on': '2026-01-02',
      'description': ' Game ',
    });
  });

  test(
    'sends the default occurrence date already provided by the input',
    () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(statusCode: 201, body: body)),
      );
      final input = CreateExpenseInput(cents: 300, description: 'Game');

      await dataSource.create(input: input);

      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      final sent = (request.body!['data'] as Map)['attributes'] as Map;
      expect(
        DateTime.parse(sent['occurred_on'] as String),
        DateTime(
          input.occurredOn.year,
          input.occurredOn.month,
          input.occurredOn.day,
        ),
      );
    },
  );

  test('preserves all JSON:API error details and field pointers', () async {
    when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Left(
        Reponse(
          statusCode: 422,
          body: {
            'errors': [
              {
                'title': 'Descrição inválida',
                'detail': 'Informe uma descrição.',
                'status': '422',
                'source': {'pointer': '/data/attributes/description'},
              },
              {
                'title': 'Valor inválido',
                'status': '422',
                'source': {'pointer': '/data/attributes/amount'},
              },
            ],
          },
        ),
      ),
    );

    final errors = (await dataSource.create(input: input)).left.errors;

    expect(errors, hasLength(2));
    expect(errors.first.title, 'Descrição inválida');
    expect(errors.first.detail, 'Informe uma descrição.');
    expect(errors.first.status, '422');
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

        final result = await dataSource.create(input: input);

        expect(result.left.errors.single.title, 'Falha');
        expect(result.left.errors.single.status, '$status');
      }
    },
  );

  test('translates unexpected client exceptions to generic errors', () async {
    when(() => client.post(parameter: any(named: 'parameter')))
        .thenThrow(StateError('unexpected failure'));

    final result = await dataSource.create(input: input);

    expect(result.left.errors.single.title, 'Erro desconhecido');
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

        final result = await dataSource.create(input: input);

        expect(result.left.errors.single.title, 'Erro desconhecido');
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

        final result = await dataSource.create(input: input);

        expect(result.left.errors.single.title, 'Erro desconhecido');
      },
    );
  }
}
