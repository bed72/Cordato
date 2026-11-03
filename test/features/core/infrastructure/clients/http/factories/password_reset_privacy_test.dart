import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/factories/dio_factory.dart';
import 'package:cordato/features/core/infrastructure/clients/logger/logger_client.dart';

import '../../../../../../support/core/fakes/http_client_adapter_fake.dart';
import '../../../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  for (final path in ['request-password-reset', 'confirm-password-reset']) {
    for (final status in [204, 400, 500]) {
      test(
        'does not log $path request or response on status $status',
        () async {
          final storage = StorageClientMock();
          final dio =
              DioFactory.create(
                  baseUrl: 'https://example.com/api/',
                  storage: storage,
                )
                ..httpClientAdapter = HttpClientAdapterFake(
                  respond: (options) => ResponseBody.fromString('{}', status),
                );
          addTearDown(() => dio.close(force: true));
          final before = loggerClient.history.length;
          await dio.post<Object?>(
            'collections/users/$path',
            data: {
              'token': 'fixture.reset.token',
              'password': 'NewPass1',
              'email': 'person@example.com',
            },
            options: Options(validateStatus: (_) => true),
          );
          expect(loggerClient.history.length, before);
        },
      );
    }
  }

  for (final path in ['request-password-reset', 'confirm-password-reset']) {
    test('does not log $path transport errors', () async {
      final dio =
          DioFactory.create(
              baseUrl: 'https://example.com/api/',
              storage: StorageClientMock(),
            )
            ..httpClientAdapter = HttpClientAdapterFake(
              respond: (options) => throw DioException(requestOptions: options),
            );
      addTearDown(() => dio.close(force: true));
      final before = loggerClient.history.length;
      await expectLater(
        dio.post<Object?>(
          'collections/users/$path',
          data: {'token': 'fixture.reset.token', 'password': 'NewPass1'},
        ),
        throwsA(isA<DioException>()),
      );
      expect(loggerClient.history.length, before);
    });
  }

  test('does not log tokenized URLs even on a transport error', () async {
    final dio =
        DioFactory.create(
            baseUrl: 'https://example.com/api/',
            storage: StorageClientMock(),
          )
          ..httpClientAdapter = HttpClientAdapterFake(
            respond: (options) => throw DioException(requestOptions: options),
          );
    addTearDown(() => dio.close(force: true));
    final before = loggerClient.history.length;
    await expectLater(
      dio.get<Object?>('public?token=fixture.reset.token'),
      throwsA(isA<DioException>()),
    );
    expect(loggerClient.history.length, before);
  });
}
