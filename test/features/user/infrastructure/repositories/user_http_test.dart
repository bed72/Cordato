import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/session_interceptor.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/infrastructure/repositories/user_repository.dart';

import '../../../../support/core/mocks/storage_client_mock.dart';
import '../../../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  late Dio dio;
  late StorageClientMock storage;
  late UserRepository repository;
  late RequestOptions sent;
  late int status;
  late String? token;

  setUp(() {
    status = 200;
    token = 'fixture-token';
    storage = StorageClientMock();
    when(() => storage.read(key: StorageKeyEnum.userId.key))
        .thenAnswer((_) async => 'user12345678901');
    when(() => storage.read(key: StorageKeyEnum.token.key))
        .thenAnswer((_) async => token);
    when(() => storage.delete(key: StorageKeyEnum.token.key))
        .thenAnswer((_) async => token = null);
    when(() => storage.clear()).thenAnswer((_) async => token = null);
    dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'));
    dio.interceptors.addAll([
      HeadersInterceptor(),
      SessionInterceptor(storage: storage),
    ]);
    dio.httpClientAdapter = HttpClientAdapterFake(
      respond: (options) {
        sent = options;
        return ResponseBody.fromString(
          status == 204
              ? ''
              : jsonEncode(
                  status == 200
                      ? {
                          'id': 'user12345678901',
                          'name': '',
                          'avatar': '',
                          'email': 'person@example.com',
                        }
                      : {
                          'status': status,
                          'message': 'Request rejected.',
                          'data': <String, dynamic>{},
                        },
                ),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      },
    );
    repository = UserRepository(
      httpClient: HttpClient(dio: dio),
      storageClient: storage,
    );
  });

  tearDown(() => dio.close(force: true));

  void verifyRequest(String method) {
    expect(sent.method, method);
    expect(
      sent.uri.toString(),
      'https://example.com/api/collections/users/records/user12345678901',
    );
    expect(sent.headers['Authorization'], 'Bearer fixture-token');
    expect(sent.headers['accept'], Headers.jsonContentType);
  }

  test(
    'GET reads a native record with optional profile fields empty',
    () async {
      final user = await repository.getById();

      expect(user.name, isEmpty);
      expect(user.avatar, isNull);
      verifyRequest('GET');
      expect(sent.data, isNull);
      verifyNever(storage.clear);
    },
  );

  test(
    'PATCH sends plain JSON without administrative or session fields',
    () async {
      await repository.update(name: 'Gabriel', avatar: 'seed');

      verifyRequest('PATCH');
      expect(sent.data, {'name': 'Gabriel', 'avatar': 'seed'});
      expect(sent.contentType, Headers.jsonContentType);
      verifyNever(storage.clear);
    },
  );

  test('DELETE accepts an empty 204 response and clears storage', () async {
    status = 204;

    await repository.delete();

    verifyRequest('DELETE');
    expect(sent.data, isNull);
    expect(token, isNull);
    verify(storage.clear).called(1);
  });

  test('401 invalidates only the rejected token', () async {
    status = 401;

    await expectLater(repository.getById(), throwsA(isA<UserException>()));

    verifyRequest('GET');
    expect(token, isNull);
    verifyNever(storage.clear);
    verifyNever(() => storage.delete(key: StorageKeyEnum.userId.key));
  });

  for (final rejectedStatus in [403, 404]) {
    test(
      '$rejectedStatus does not delete the account or clear the session',
      () async {
        status = rejectedStatus;

        await expectLater(repository.delete(), throwsA(isA<UserException>()));

        verifyRequest('DELETE');
        expect(token, 'fixture-token');
        verifyNever(storage.clear);
        verifyNever(() => storage.delete(key: StorageKeyEnum.token.key));
      },
    );
  }
}
