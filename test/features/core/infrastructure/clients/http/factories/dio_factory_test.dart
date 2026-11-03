import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

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
            'collections/expense_monthly_metrics/records',
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
