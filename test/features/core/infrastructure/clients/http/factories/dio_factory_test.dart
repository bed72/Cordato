import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/factories/dio_factory.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import '../../../../../../support/core/mocks/storage_client_mock.dart';
import '../../../../../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  late Dio dio;
  late HttpClient client;
  late int responseStatus;
  late RequestOptions? captured;
  late StorageClientMock storage;

  for (final baseUrl in [
    'https://example.com/api',
    'https://example.com/api/',
  ]) {
    group('base URL $baseUrl', () {
      setUp(() {
        captured = null;
        responseStatus = 200;
        storage = StorageClientMock();
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'opaque-token');
        when(() => storage.delete(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async {});
        dio = DioFactory.create(baseUrl: baseUrl, storage: storage)
          ..httpClientAdapter = HttpClientAdapterFake(
            respond: (options) {
              captured = options;
              return ResponseBody.fromString(
                '{}',
                responseStatus,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            },
          );
        client = HttpClient(dio: dio);
      });

      tearDown(() => dio.close(force: true));

      test(
        'authenticates the native password PATCH with the existing interceptor',
        () async {
          await client.patch(
            parameter: const Requests(
              path: 'collections/users/records/user-1',
              body: {
                'oldPassword': 'OldPass1',
                'password': 'NewPass1',
                'passwordConfirm': 'NewPass1',
              },
            ),
          );
          expect(captured!.uri.path, '/api/collections/users/records/user-1');
          expect(captured!.headers['Authorization'], 'Bearer opaque-token');
        },
      );

      group('Sensitive operation logging', () {
        for (final key in ['oldPassword', 'password', 'passwordConfirm']) {
          test('omits $key from all HTTP log channels', () {
            final settings = dio.interceptors
                .whereType<TalkerDioLogger>()
                .single
                .settings;
            final options = RequestOptions(
              path: '/api/collections/users/records/user-1',
              method: 'PATCH',
              data: {key: 'fixture-private'},
            );
            expect(settings.requestFilter!(options), isFalse);
            expect(
              settings.responseFilter!(Response(requestOptions: options)),
              isFalse,
            );
            expect(
              settings.errorFilter!(DioException(requestOptions: options)),
              isFalse,
            );
            expect(settings.hiddenHeaders, contains('Authorization'));
          });
        }

        for (final path in [
          '/api/collections/users/request-password-reset',
          '/api/collections/users/confirm-password-reset',
          '/api/other?token=fixture',
        ]) {
          test('preserves exclusion of $path', () {
            final settings = dio.interceptors
                .whereType<TalkerDioLogger>()
                .single
                .settings;
            final options = RequestOptions(path: path);
            expect(settings.requestFilter!(options), isFalse);
            expect(
              settings.responseFilter!(Response(requestOptions: options)),
              isFalse,
            );
            expect(
              settings.errorFilter!(DioException(requestOptions: options)),
              isFalse,
            );
          });
        }

        test('does not exclude ordinary profile updates', () {
          final settings = dio.interceptors
              .whereType<TalkerDioLogger>()
              .single
              .settings;
          final options = RequestOptions(
            path: '/api/collections/users/records/user-1',
            method: 'PATCH',
            data: {'name': 'Pessoa', 'avatar': 'seed'},
          );
          expect(settings.requestFilter!(options), isTrue);
          expect(
            settings.responseFilter!(Response(requestOptions: options)),
            isTrue,
          );
          expect(
            settings.errorFilter!(DioException(requestOptions: options)),
            isTrue,
          );
        });
      });

      test(
        'password reset endpoints stay public even with a stored session',
        () async {
          responseStatus = 204;
          for (final path in [
            'request-password-reset',
            'confirm-password-reset',
          ]) {
            await client.post(
              parameter: Requests(
                path: 'collections/users/$path',
                body: const {},
              ),
            );
            expect(captured!.uri.path, '/api/collections/users/$path');
            expect(captured!.headers['Authorization'], isNull);
            expect(captured!.headers['accept'], 'application/json');
          }
          verifyZeroInteractions(storage);
        },
      );

      test(
        'preserves the API prefix and authenticates protected resources',
        () async {
          for (final path in [
            'expenses',
            'users/10',
            'expenses/8',
            'collections/users/records',
            'collections/expenses/records',
            'collections/users/auth-refresh',
            'collections/users/records/user-1',
            'collections/expenses/records/expense-1',
            'collections/metrics/records',
          ]) {
            await client.get(parameter: Requests(path: path));

            expect(captured!.uri.path, '/api/$path');
            expect(captured!.headers['Authorization'], 'Bearer opaque-token');
          }
        },
      );

      test(
        'removes the sent token when a protected resource returns 401',
        () async {
          responseStatus = 401;

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

          expect(captured!.uri.path, '/api/expenses');
          expect(captured!.headers['Authorization'], 'Bearer opaque-token');
          verify(() => storage.delete(key: StorageKeyEnum.token.key)).called(1);
        },
      );
    });
  }
}
