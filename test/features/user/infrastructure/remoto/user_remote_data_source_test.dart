import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/user/infrastructure/remoto/user_remote_data_source.dart';

import '../../../../support/core/mocks/http_client_mock.dart';

void main() {
  const body = {
    'data': {
      'id': '9',
      'type': 'users',
      'attributes': {
        'name': 'Gabriel Ramos',
        'email': 'person@example.com',
        'status': 'active',
        'created_at': '2026-10-02T17:21:48+00:00',
        'updated_at': '2026-10-05T13:33:59+00:00',
      },
      'links': {'self': 'https://example.com/api/users/9'},
    },
  };

  late HttpClientMock client;
  late IUserRemoteDataSource dataSource;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    dataSource = UserRemoteDataSource(client: client);
  });

  test('gets the protected user resource and preserves its response', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(Reponse(statusCode: 200, body: body)),
    );

    final user = (await dataSource.getById(id: '9')).right;

    expect(user.id, '9');
    expect(user.name, 'Gabriel Ramos');
    expect(user.email, 'person@example.com');
    expect(user.status, 'active');
    final request =
        verify(() => client.get(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect(request.path, 'users/9');
    expect(request.body, isNull);
    expect(request.headers, isNull);
  });

  test(
    'patches only the name and returns the user supplied by the API',
    () async {
      when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(statusCode: 200, body: body)),
      );

      final user = (await dataSource.update(
        id: '10',
        name: 'Gabriel Ramos',
      )).right;

      expect(user.id, '9');
      expect(user.name, 'Gabriel Ramos');
      final request =
          verify(() => client.patch(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'users/10');
      expect(request.headers, isNull);
      expect(request.body, {
        'data': {
          'type': 'users',
          'id': '10',
          'attributes': {'name': 'Gabriel Ramos'},
        },
      });
    },
  );

  test(
    'encodes the id in all resource paths without changing the payload id',
    () async {
      const id = 'a/b?c#d';
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(statusCode: 200, body: body)),
      );
      when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(statusCode: 200, body: body)),
      );
      when(() => client.delete(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(Reponse(statusCode: 204, body: {})),
      );

      await dataSource.getById(id: id);
      await dataSource.update(id: id, name: 'Gabriel');
      await dataSource.delete(id: id);

      final get =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      final patch =
          verify(() => client.patch(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      final delete =
          verify(() => client.delete(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      for (final request in [get, patch, delete]) {
        expect(request.path, 'users/a%2Fb%3Fc%23d');
      }
      expect((patch.body!['data'] as Map)['id'], id);
    },
  );

  test('omits the name when it was not supplied', () async {
    when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(Reponse(statusCode: 200, body: body)),
    );

    await dataSource.update(id: '9');

    final request =
        verify(() => client.patch(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect((request.body!['data'] as Map)['attributes'], isEmpty);
  });

  test('deletes the protected user and accepts 204 without a body', () async {
    when(
      () => client.delete(parameter: any(named: 'parameter')),
    ).thenAnswer((_) async => const Right(Reponse(statusCode: 204, body: {})));

    expect((await dataSource.delete(id: '10')).right, isTrue);
    final request =
        verify(() => client.delete(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect(request.path, 'users/10');
    expect(request.headers, isNull);
    expect(request.body, isNull);
  });

  test('does not report deletion for an unexpected success status', () async {
    when(
      () => client.delete(parameter: any(named: 'parameter')),
    ).thenAnswer((_) async => const Right(Reponse(statusCode: 200, body: {})));
    expect((await dataSource.delete(id: '10')).right, isFalse);
  });

  for (final operation in ['getById', 'update', 'delete']) {
    Future<Either<ErrorsResponse, Object>> execute() => switch (operation) {
      'getById' => dataSource.getById(id: '10'),
      'update' => dataSource.update(id: '10', name: 'Gabriel Ramos'),
      _ => dataSource.delete(id: '10'),
    };
    Future<Responses> request() => switch (operation) {
      'getById' => client.get(parameter: any(named: 'parameter')),
      'update' => client.patch(parameter: any(named: 'parameter')),
      _ => client.delete(parameter: any(named: 'parameter')),
    };

    test('$operation preserves every JSON:API error', () async {
      when(request).thenAnswer(
        (_) async => const Left(
          Reponse(
            statusCode: 422,
            body: {
              'errors': [
                {
                  'status': '422',
                  'title': 'Nome inválido',
                  'detail': 'Informe um nome.',
                  'source': {'pointer': '/data/attributes/name'},
                },
                {'status': '422', 'title': 'Outro erro'},
              ],
            },
          ),
        ),
      );

      final errors = (await execute()).left.errors;
      expect(errors, hasLength(2));
      expect(errors.first.status, '422');
      expect(errors.first.title, 'Nome inválido');
      expect(errors.first.detail, 'Informe um nome.');
      expect(errors.first.pointer, '/data/attributes/name');
    });

    test(
      '$operation translates malformed errors and transport failures',
      () async {
        for (final response in [
          const Reponse(statusCode: 500, body: {}),
          const Reponse(statusCode: 500, body: {'errors': []}),
          Reponse(
            statusCode: 0,
            body: {
              'errors': [
                {'title': 'Sem conexão', 'detail': 'Tente novamente.'},
              ],
            },
          ),
        ]) {
          when(request).thenAnswer((_) async => Left(response));
          final error = (await execute()).left.errors.single;
          expect(
            error.title,
            response.statusCode == 0 ? 'Sem conexão' : 'Erro desconhecido',
          );
        }
      },
    );

    test('$operation translates unexpected client exceptions', () async {
      when(request).thenAnswer((_) async => throw StateError('offline'));
      expect((await execute()).left.errors.single.title, 'Erro desconhecido');
    });
  }

  test('get and update reject malformed resource responses', () async {
    for (final malformed in <Map<String, dynamic>>[
      {},
      {
        'data': {'id': '10', 'attributes': {}},
      },
      {
        'data': {
          'id': '10',
          'attributes': {
            'name': 123,
            'email': 'person@example.com',
            'status': 'active',
          },
        },
      },
    ]) {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Right(Reponse(statusCode: 200, body: malformed)),
      );
      when(() => client.patch(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Right(Reponse(statusCode: 200, body: malformed)),
      );
      expect((await dataSource.getById(id: '10')).isLeft, isTrue);
      expect(
        (await dataSource.update(id: '10', name: 'Gabriel')).isLeft,
        isTrue,
      );
    }
  });
}
