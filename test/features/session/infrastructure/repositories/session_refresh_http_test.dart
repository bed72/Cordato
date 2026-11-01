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
  for (final status in [200, 401, 403]) {
    test(
      'real HTTP/interceptors coordinate refresh $status with storage',
      () async {
        final storage = StorageClientMock();
        String? token = 'old-token';
        var userId = 'old-user';
        var requests = 0;
        RequestOptions? sent;
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
        final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'));
        addTearDown(() => dio.close(force: true));
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
        final repository = SessionRepository(
          storageClient: storage,
          httpClient: HttpClient(dio: dio),
        );
        if (status == 403) {
          await expectLater(
            repository.loadSession(),
            throwsA(isA<SessionException>()),
          );
          expect(token, 'old-token');
          expect(userId, 'old-user');
        } else {
          expect(await repository.loadSession(), status == 200);
          expect(token, status == 200 ? 'new-token' : isNull);
          expect(userId, status == 200 ? 'new-user' : 'old-user');
        }
        expect(requests, 1);
        expect(
          sent!.uri.toString(),
          'https://example.com/api/collections/users/auth-refresh',
        );
        expect(sent!.method, 'POST');
        expect(sent!.data, isNull);
        expect(sent!.headers['Authorization'], 'Bearer old-token');
        verifyNever(storage.clear);
      },
    );
  }
}
