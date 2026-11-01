import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/session_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/infrastructure/repositories/session_repository.dart';

import '../../../../support/core/fakes/http_client_adapter_fake.dart';
import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  late Dio dio;
  late int status;
  late int requests;
  late String? token;
  late String userId;
  late RequestOptions? sent;
  late StorageClientMock storage;
  late SessionRepository repository;

  setUp(() {
    status = 200;
    storage = StorageClientMock();
    token = 'old-token';
    userId = 'old-user';
    requests = 0;
    sent = null;
    when(() => storage.read(key: StorageKeyEnum.token.key))
        .thenAnswer((_) async => token);
    when(() => storage.delete(key: StorageKeyEnum.token.key))
        .thenAnswer((_) async {
          token = null;
        });
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final value = invocation.namedArguments[#value] as String;
      if (invocation.namedArguments[#key] == StorageKeyEnum.token.key) {
        token = value;
      } else {
        userId = value;
      }
    });
    dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'));
    dio.interceptors.addAll([
      HeadersInterceptor(),
      SessionInterceptor(storage: storage),
    ]);
    dio.httpClientAdapter = HttpClientAdapterFake(
      respond: (options) {
        requests++;
        sent = options;
        return ResponseBody.fromString(
          jsonEncode(
            status == 200
                ? {
                    'token': 'new-token',
                    'record': {'id': 'new-user'},
                  }
                : {
                    'status': status,
                    'message': 'Refresh rejected.',
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
    repository = SessionRepository(
      storageClient: storage,
      httpClient: HttpClient(dio: dio),
    );
  });

  tearDown(() => dio.close(force: true));

  void verifyRefreshRequest() {
    expect(requests, 1);
    expect(
      sent!.uri.toString(),
      'https://example.com/api/collections/users/auth-refresh',
    );
    expect(sent!.method, 'POST');
    expect(sent!.data, isNull);
    expect(sent!.headers['Authorization'], 'Bearer old-token');
    verifyNever(storage.clear);
  }

  group('Real HTTP refresh and session persistence', () {
    test('200 persists the renewed token and user id', () async {
      expect(await repository.loadSession(), isTrue);

      expect(token, 'new-token');
      expect(userId, 'new-user');
      verifyRefreshRequest();
    });

    test('401 removes only the rejected token', () async {
      status = 401;

      expect(await repository.loadSession(), isFalse);

      expect(token, isNull);
      expect(userId, 'old-user');
      verifyRefreshRequest();
    });

    test(
      '403 preserves the session and exposes an application failure',
      () async {
        status = 403;

        await expectLater(
          repository.loadSession(),
          throwsA(isA<SessionException>()),
        );

        expect(token, 'old-token');
        expect(userId, 'old-user');
        verifyRefreshRequest();
      },
    );
  });
}
