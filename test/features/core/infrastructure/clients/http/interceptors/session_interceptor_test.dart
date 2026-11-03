import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/session_interceptor.dart';

import '../../../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  late HttpClient client;
  late int responseStatus;
  late RequestOptions? captured;
  late StorageClientMock storage;

  setUp(() {
    storage = StorageClientMock();
    captured = null;
    responseStatus = 200;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
      ..interceptors.add(SessionInterceptor(storage: storage));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              data: {},
              requestOptions: options,
              statusCode: responseStatus,
            ),
            true,
          );
        },
      ),
    );
    client = HttpClient(dio: dio);
  });

  group('Authorization for known endpoints', () {
    test('adds the stored bearer token only to protected requests', () async {
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');

      await client.get(parameter: const Requests(path: 'expenses'));

      expect(captured!.headers['Authorization'], 'Bearer opaque-token');
      verify(() => storage.read(key: StorageKeyEnum.token.key)).called(1);

      await client.post(
        parameter: const Requests(path: 'authentication/sign-in'),
      );

      expect(captured!.headers.containsKey('Authorization'), isFalse);
      verifyNever(() => storage.read(key: StorageKeyEnum.token.key));
    });

    test(
      'does not read or send a token for public PocketBase auth requests',
      () async {
        for (final path in [
          'collections/users/records',
          'collections/users/auth-with-password',
          'collections/users/request-verification',
          'collections/users/confirm-verification',
        ]) {
          await client.post(parameter: Requests(path: path));
          expect(captured!.headers.containsKey('Authorization'), isFalse);
        }
        verifyZeroInteractions(storage);
      },
    );

    test('authenticates expense metrics with query filters', () async {
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');

      await client.get(
        parameter: const Requests(
          path: 'metrics/expenses',
          query: {'group_by': 'category', 'start_date': '2026-10-01'},
        ),
      );

      expect(captured!.uri.path, '/api/metrics/expenses');
      expect(captured!.headers['Authorization'], 'Bearer opaque-token');
      verify(() => storage.read(key: StorageKeyEnum.token.key)).called(1);
    });

    test(
      'authenticates PocketBase refresh and protected record routes',
      () async {
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'fixture-token');
        await client.post(
          parameter: const Requests(path: 'collections/users/auth-refresh'),
        );

        expect(captured!.headers['Authorization'], 'Bearer fixture-token');
        for (final path in [
          'collections/users/records',
          'collections/expenses/records',
          'collections/users/records/user-1',
          'collections/expenses/records/expense-1',
        ]) {
          await client.get(
            parameter: Requests(path: path, query: const {'fields': 'id'}),
          );
          expect(captured!.headers['Authorization'], 'Bearer fixture-token');
        }

        await client.post(
          parameter: const Requests(
            body: {'amount': 100},
            path: 'collections/expenses/records',
          ),
        );

        expect(captured!.headers['Authorization'], 'Bearer fixture-token');
        await client.patch(
          parameter: const Requests(
            body: {'name': 'Pessoa'},
            path: 'collections/users/records/user-1',
          ),
        );

        expect(captured!.headers['Authorization'], 'Bearer fixture-token');
        await client.delete(
          parameter: const Requests(
            path: 'collections/expenses/records/expense-1',
          ),
        );

        expect(captured!.headers['Authorization'], 'Bearer fixture-token');
      },
    );
  });

  group('PocketBase authorization boundaries and refresh failures', () {
    test('does not leak token to unknown collection paths or absolute refresh URLs', () async {
      for (final path in [
        'collections/other/records',
        'collections/expenses/records/',
        'collections/expenses/records-other',
        'collections/users/auth-refresh/extra',
        'collections/users/records/user-1/extra',
        'collections/expenses/records/expense-1/extra',
        'https://example.com/api/collections/users/auth-refresh',
        'https://external.example/api/collections/expenses/records',
      ]) {
        await client.get(parameter: Requests(path: path));
        expect(captured!.headers.containsKey('Authorization'), isFalse);
      }
      verifyZeroInteractions(storage);
    });

    test(
      'refresh 401 only invalidates the sent token while 403 preserves it',
      () async {
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'fixture-token');
        when(() => storage.delete(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async {});

        responseStatus = 403;
        await expectLater(
          client.post(
            parameter: const Requests(path: 'collections/users/auth-refresh'),
          ),
          throwsA(isA<HttpResponseException>()),
        );

        verifyNever(() => storage.delete(key: StorageKeyEnum.token.key));
        responseStatus = 401;
        await expectLater(
          client.post(
            parameter: const Requests(path: 'collections/users/auth-refresh'),
          ),
          throwsA(isA<HttpResponseException>()),
        );

        verify(() => storage.delete(key: StorageKeyEnum.token.key)).called(1);
        verifyNever(storage.clear);
        verifyNever(() => storage.delete(key: StorageKeyEnum.userId.key));
      },
    );
  });

  group('Legacy protected resources', () {
    test('does not authenticate absolute or unrelated metrics paths', () async {
      for (final path in [
        'metrics',
        'metrics/expenses/1',
        'metrics/expenses-other',
        'https://example.com/api/metrics/expenses',
        'https://external.example/api/metrics/expenses',
      ]) {
        await client.get(parameter: Requests(path: path));
        expect(captured!.headers.containsKey('Authorization'), isFalse);
      }

      verifyZeroInteractions(storage);
    });

    test('removes only the sent token when metrics returns 401', () async {
      responseStatus = 401;
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');
      when(() => storage.delete(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async {});

      await expectLater(
        client.get(parameter: const Requests(path: 'metrics/expenses')),
        throwsA(
          isA<HttpResponseException>().having(
            (error) => error.status,
            'status',
            401,
          ),
        ),
      );

      verifyNever(() => storage.clear());
      verifyNever(() => storage.delete(key: StorageKeyEnum.userId.key));
      verify(() => storage.delete(key: StorageKeyEnum.token.key)).called(1);
    });

    test('does not authenticate unrelated paths', () async {
      for (final path in [
        'unknown/1',
        'expenses-other',
        'https://example.com/api/expenses',
        'https://external.example/api/expenses',
      ]) {
        await client.get(parameter: Requests(path: path));
        expect(captured!.headers.containsKey('Authorization'), isFalse);
      }

      verifyZeroInteractions(storage);
    });

    test('removes the sent token when expenses returns 401', () async {
      responseStatus = 401;
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');
      when(() => storage.delete(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async {});

      await expectLater(
        client.get(parameter: const Requests(path: 'expenses')),
        throwsA(
          isA<HttpResponseException>().having(
            (error) => error.status,
            'status',
            401,
          ),
        ),
      );

      verify(() => storage.delete(key: StorageKeyEnum.token.key)).called(1);
    });

    test('does not send Authorization without a saved token', () async {
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => null);

      await client.get(parameter: const Requests(path: 'expenses'));

      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });

    test('authenticates GET, PATCH and DELETE of the user resource', () async {
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');
      const parameter = Requests(path: 'users/10');

      await client.get(parameter: parameter);
      expect(captured!.uri.path, '/api/users/10');
      expect(captured!.headers['Authorization'], 'Bearer opaque-token');

      await client.patch(parameter: parameter);
      expect(captured!.headers['Authorization'], 'Bearer opaque-token');

      await client.delete(parameter: parameter);
      expect(captured!.headers['Authorization'], 'Bearer opaque-token');
    });

    test('authenticates expense deletion through the repository', () async {
      responseStatus = 204;
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');
      final repository = ExpenseRepository(
        httpClient: client,
        storageClient: storage,
      );

      await repository.delete(id: '1');
      expect(captured!.method, 'DELETE');
      expect(captured!.uri.path, '/api/collections/expenses/records/1');
      expect(captured!.headers['Authorization'], 'Bearer opaque-token');
      verify(() => storage.read(key: StorageKeyEnum.token.key)).called(1);
      verifyNever(() => storage.delete(key: StorageKeyEnum.token.key));
    });

    test('authenticates an expense with an encoded id', () async {
      responseStatus = 204;
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');

      await ExpenseRepository(
        httpClient: client,
        storageClient: storage,
      ).delete(id: 'a/b?c#d');

      expect(captured!.uri.pathSegments.last, 'a/b?c#d');
      expect(captured!.headers['Authorization'], 'Bearer opaque-token');
    });

    test(
      'authenticates GET, PATCH and DELETE of an expense resource',
      () async {
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'opaque-token');
        const parameter = Requests(path: 'expenses/8');

        await client.get(parameter: parameter);
        expect(captured!.uri.path, '/api/expenses/8');
        expect(captured!.headers['Authorization'], 'Bearer opaque-token');

        await client.patch(parameter: parameter);
        expect(captured!.headers['Authorization'], 'Bearer opaque-token');

        await client.delete(parameter: parameter);
        expect(captured!.headers['Authorization'], 'Bearer opaque-token');
        verify(() => storage.read(key: StorageKeyEnum.token.key)).called(3);
        verifyNever(() => storage.delete(key: StorageKeyEnum.token.key));
      },
    );

    test('does not authenticate unrelated or absolute expense paths', () async {
      for (final path in [
        'expenses/',
        'expenses/1/items',
        'expenses-other/1',
        'https://example.com/api/expenses/1',
        'https://external.example/api/expenses/1',
      ]) {
        await client.delete(parameter: Requests(path: path));
        expect(captured!.headers.containsKey('Authorization'), isFalse);
      }

      verifyZeroInteractions(storage);
    });

    test(
      'removes the sent token after an expense deletion returns 401',
      () async {
        responseStatus = 401;
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'opaque-token');
        when(() => storage.delete(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async {});

        await expectLater(
          client.delete(parameter: const Requests(path: 'expenses/1')),
          throwsA(
            isA<HttpResponseException>().having(
              (error) => error.status,
              'status',
              401,
            ),
          ),
        );

        expect(captured!.headers['Authorization'], 'Bearer opaque-token');
        verify(() => storage.delete(key: StorageKeyEnum.token.key)).called(1);
      },
    );

    test('preserves the session when expense deletion is forbidden', () async {
      responseStatus = 403;
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');

      await expectLater(
        client.delete(parameter: const Requests(path: 'expenses/1')),
        throwsA(
          isA<HttpResponseException>().having(
            (error) => error.status,
            'status',
            403,
          ),
        ),
      );

      expect(captured!.headers['Authorization'], 'Bearer opaque-token');
      verifyNever(() => storage.delete(key: StorageKeyEnum.token.key));
    });

    test('does not authenticate unrelated or external user paths', () async {
      for (final path in [
        'users',
        'users/',
        'other/10',
        'users/10/expenses',
        'users/10/../11/expenses',
        'https://example.com/users/10',
        'https://example.com/api/users/10',
        'https://external.example/api/users/10',
      ]) {
        await client.get(parameter: Requests(path: path));
        expect(captured!.headers.containsKey('Authorization'), isFalse);
      }

      verifyNever(() => storage.read(key: StorageKeyEnum.token.key));
    });

    test('removes the sent token after a user resource returns 401', () async {
      responseStatus = 401;
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');
      when(() => storage.delete(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async {});

      await expectLater(
        client.get(parameter: const Requests(path: 'users/10')),
        throwsA(
          isA<HttpResponseException>().having(
            (error) => error.status,
            'status',
            401,
          ),
        ),
      );

      verify(() => storage.delete(key: StorageKeyEnum.token.key)).called(1);
    });
  });

  group('Unknown paths and token isolation', () {
    test('does not read the token for an unknown endpoint', () async {
      await client.get(parameter: const Requests(path: 'items'));

      expect(captured!.headers.containsKey('Authorization'), isFalse);
      verifyNever(() => storage.read(key: StorageKeyEnum.token.key));
    });

    test('does not accept ids on fixed authentication endpoints', () async {
      for (final path in [
        'authentication/sign-in/1',
        'authentication/sign-up/1',
        'authentication/sign-out/1',
        'authentication/email-verification/resend/1',
      ]) {
        await client.post(parameter: Requests(path: path));

        expect(captured!.headers.containsKey('Authorization'), isFalse);
      }

      verifyZeroInteractions(storage);
    });

    test(
      'rejects empty and dot resource ids without reading the token',
      () async {
        for (final path in [
          'users/',
          'users/%2E',
          'users/%2E%2E',
          'expenses/',
          'expenses/%2E',
          'expenses/%2E%2E',
        ]) {
          await client.delete(parameter: Requests(path: path));

          expect(captured!.headers.containsKey('Authorization'), isFalse);
        }

        verifyZeroInteractions(storage);
      },
    );

    test(
      'does not authenticate the removed legacy sign-out endpoint',
      () async {
        await client.delete(
          parameter: const Requests(path: 'authentication/sign-out'),
        );

        verifyZeroInteractions(storage);
        expect(captured!.headers.containsKey('Authorization'), isFalse);
      },
    );

    test(
      'does not authenticate a path resembling a protected endpoint',
      () async {
        await client.get(parameter: const Requests(path: 'expenses-other'));

        expect(captured!.headers.containsKey('Authorization'), isFalse);
        verifyNever(() => storage.read(key: StorageKeyEnum.token.key));
      },
    );

    test('does not send the token to an external URL', () async {
      await client.get(
        parameter: const Requests(path: 'https://external.example/expenses'),
      );

      verifyNever(() => storage.read(key: StorageKeyEnum.token.key));
      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('Invalidation, concurrent sessions and storage failures', () {
    test('does not send a stale header when secure storage fails', () async {
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenThrow(StateError('storage unavailable'));

      await expectLater(
        client.get(parameter: const Requests(path: 'expenses')),
        throwsA(isA<HttpUnexpectedException>()),
      );

      expect(captured, isNull);
    });

    test('removes the token after a protected request returns 401', () async {
      responseStatus = 401;
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');
      when(() => storage.delete(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async {});

      await expectLater(
        client.get(parameter: const Requests(path: 'expenses')),
        throwsA(
          isA<HttpResponseException>().having(
            (error) => error.status,
            'status',
            401,
          ),
        ),
      );

      verify(() => storage.delete(key: StorageKeyEnum.token.key)).called(1);
    });

    test('does not remove the token for a public 401', () async {
      responseStatus = 401;

      await expectLater(
        client.post(parameter: const Requests(path: 'authentication/sign-in')),
        throwsA(
          isA<HttpResponseException>().having(
            (error) => error.status,
            'status',
            401,
          ),
        ),
      );

      verifyNever(() => storage.delete(key: StorageKeyEnum.token.key));
    });

    test('does not remove the token for a protected 403', () async {
      responseStatus = 403;
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');

      await expectLater(
        client.get(parameter: const Requests(path: 'expenses')),
        throwsA(
          isA<HttpResponseException>().having(
            (error) => error.status,
            'status',
            403,
          ),
        ),
      );

      verifyNever(() => storage.delete(key: StorageKeyEnum.token.key));
    });

    test(
      'does not remove a newer token after an older request returns 401',
      () async {
        int reads = 0;
        responseStatus = 401;
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => ++reads == 1 ? 'old-token' : 'new-token');

        await expectLater(
          client.get(parameter: const Requests(path: 'expenses')),
          throwsA(
            isA<HttpResponseException>().having(
              (error) => error.status,
              'status',
              401,
            ),
          ),
        );

        verifyNever(() => storage.delete(key: StorageKeyEnum.token.key));
      },
    );

    test(
      'preserves the 401 if secure storage cannot remove the token',
      () async {
        responseStatus = 401;
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'opaque-token');
        when(() => storage.delete(key: StorageKeyEnum.token.key))
            .thenThrow(StateError('storage unavailable'));

        await expectLater(
          client.get(parameter: const Requests(path: 'expenses')),
          throwsA(
            isA<HttpResponseException>().having(
              (error) => error.status,
              'status',
              401,
            ),
          ),
        );
      },
    );
  });
}
