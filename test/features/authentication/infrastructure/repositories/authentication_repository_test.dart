import 'dart:async';
import 'dart:convert';
import 'dart:io' hide HttpClient;

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/application/clients/interface_session_client.dart';
import 'package:cordato/features/core/infrastructure/clients/session/session_client.dart';

import '../../../../support/core/fakes/cookie_storage_fake.dart';
import '../../../../support/core/fakes/http_client_adapter_fake.dart';
import '../../../../support/core/mocks/session_client_mock.dart';

void main() {
  final accountUri = Uri.parse('https://appwrite.example/v1/account');
  const expiryHeaders = [
    'a_session_project=; Path=/; Max-Age=0',
    'a_session_project_legacy=; Domain=.appwrite.example; Path=/; Max-Age=0',
  ];
  late Directory directory;
  late CookieStorageFake storage;
  late PersistCookieJar cookies;
  late Dio transport;
  late HttpClient client;
  late HttpClientAdapterFake adapter;
  late ISessionClient session;
  late IAuthenticationRepository repository;
  late List<bool> changes;

  ResponseBody respond({
    int status = 200,
    Object? body = const {},
    List<String> setCookies = const [],
  }) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      if (setCookies.isNotEmpty) HttpHeaders.setCookieHeader: setCookies,
    },
  );

  Future<List<Cookie>> persistedCookies(Uri uri) => PersistCookieJar(
    storage: FileStorage(directory.path),
    ignoreExpires: false,
    persistSession: true,
  ).loadForRequest(uri);

  Future<void> seedSession() => cookies.saveFromResponse(accountUri, [
    Cookie('a_session_project', 'host-secret')..path = '/',
    Cookie('a_session_project_legacy', 'domain-secret')
      ..domain = '.appwrite.example'
      ..path = '/',
  ]);

  Future<Object?> call(String operation) => switch (operation) {
    'requestCode' => repository.requestCode(email: 'user@example.com'),
    'confirmCode' => repository.confirmCode(userId: 'user-id', code: '012345'),
    'signOut' => repository.signOut(),
    _ => throw ArgumentError.value(operation, 'operation'),
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'cordato-authentication-',
    );
    storage = CookieStorageFake(storage: FileStorage(directory.path));
    cookies = PersistCookieJar(
      storage: storage,
      ignoreExpires: false,
      persistSession: true,
    );
    transport = Dio(
      BaseOptions(
        baseUrl: 'https://appwrite.example/v1',
        headers: {'X-Appwrite-Project': 'project'},
      ),
    )..interceptors.add(CookieManager(cookies));
    client = HttpClient(dio: transport);
    adapter = HttpClientAdapterFake()..respond = (_) => respond();
    transport.httpClientAdapter = adapter;
    session = SessionClient(client: client);
    repository = AuthenticationRepository(
      httpClient: client,
      sessionClient: session,
    );
    changes = [];
    final subscription = session.session.listen(changes.add);
    addTearDown(() async {
      await subscription.cancel();
      await session.close();
      client.close(force: true);
      await directory.delete(recursive: true);
    });
  });

  group('Session client dependency inversion', () {
    test('confirms through the injected session contract', () async {
      final sessionMock = SessionClientMock();
      final authentication = AuthenticationRepository(
        httpClient: client,
        sessionClient: sessionMock,
      );
      when(() => sessionMock.confirmCode(userId: ' user-id ', code: ' 012345 '))
          .thenAnswer((_) async {});

      await authentication.confirmCode(userId: ' user-id ', code: ' 012345 ');

      verify(
        () => sessionMock.confirmCode(userId: ' user-id ', code: ' 012345 '),
      ).called(1);
      verifyNoMoreInteractions(sessionMock);
      expect(adapter.requests, isEmpty);
    });

    test('signs out through the injected session contract', () async {
      final sessionMock = SessionClientMock();
      final authentication = AuthenticationRepository(
        httpClient: client,
        sessionClient: sessionMock,
      );
      when(sessionMock.signOut).thenAnswer((_) async {});

      await authentication.signOut();

      verify(sessionMock.signOut).called(1);
      verifyNoMoreInteractions(sessionMock);
      expect(adapter.requests, isEmpty);
    });
  });

  group('requestCode', () {
    test(
      'sends only email and the REST sentinel and returns the service userId',
      () async {
        adapter.respond = (_) => respond(
          status: 201,
          body: {
            'userId': ' service-user ',
            'secret': '',
            'expire': '2026-11-17T12:15:00Z',
          },
        );

        final userId = await repository.requestCode(
          email: ' User@example.com ',
        );

        expect(userId, ' service-user ');
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(
          request.uri.toString(),
          'https://appwrite.example/v1/account/tokens/email',
        );
        expect(request.data, {
          'userId': 'unique()',
          'email': ' User@example.com ',
        });
        expect(request.headers['X-Appwrite-Project'], 'project');
        expect(request.headers.containsKey('X-Appwrite-Key'), isFalse);
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(changes, isEmpty);
      },
    );

    test('each explicit resend returns the new service userId without authenticating', () async {
      adapter.respond = (_) => respond(
        status: 201,
        body: {'userId': 'user-${adapter.requests.length}'},
      );

      final firstUserId = await repository.requestCode(
        email: 'user@example.com',
      );
      final nextUserId = await repository.requestCode(
        email: 'user@example.com',
      );

      expect(firstUserId, 'user-1');
      expect(nextUserId, 'user-2');
      expect(adapter.requests, hasLength(2));
      expect(changes, isEmpty);
    });

    for (final malformed in <({String name, Object? body})>[
      (name: 'null body', body: null),
      (name: 'missing userId', body: {}),
      (name: 'null userId', body: {'userId': null}),
      (name: 'numeric userId', body: {'userId': 42}),
    ]) {
      test(
        '${malformed.name} propagates a parsing error without retry',
        () async {
          adapter.respond = (_) => respond(status: 201, body: malformed.body);

          await expectLater(
            repository.requestCode(email: 'user@example.com'),
            throwsA(isA<TypeError>()),
          );

          expect(adapter.requests, hasLength(1));
          expect(changes, isEmpty);
        },
      );
    }

    for (final userId in ['', '   ']) {
      test(
        'blank userId of length ${userId.length} is not a successful challenge',
        () async {
          adapter.respond = (_) =>
              respond(status: 201, body: {'userId': userId});

          await expectLater(
            repository.requestCode(email: 'user@example.com'),
            throwsFormatException,
          );

          expect(changes, isEmpty);
        },
      );
    }

    test('invalid HTTP envelope propagates a format error', () async {
      adapter.respond = (_) => respond(status: 201, body: []);

      await expectLater(
        repository.requestCode(email: 'user@example.com'),
        throwsFormatException,
      );

      expect(changes, isEmpty);
      expect(adapter.requests, hasLength(1));
    });
  });

  group('confirmCode', () {
    test('sends the original code as secret and waits for cookies and account success', () async {
      final accountStarted = Completer<void>();
      final accountResponse = Completer<ResponseBody>();
      adapter.respond = (request) {
        if (request.method == 'POST') {
          return respond(
            status: 201,
            setCookies: [
              'a_session_project=confirmed; Path=/; Secure; HttpOnly',
            ],
          );
        }
        accountStarted.complete();
        return accountResponse.future;
      };
      final observed = session.session.first;

      final confirmation = repository.confirmCode(
        userId: ' user-id ',
        code: ' 012345 ',
      );
      await accountStarted.future;

      expect(changes, isEmpty);
      expect(adapter.requests.first.data, {
        'userId': ' user-id ',
        'secret': ' 012345 ',
      });
      expect(adapter.requests.first.uri.path, '/v1/account/sessions/token');
      expect(adapter.requests.last.uri, accountUri);
      expect(
        adapter.requests.last.headers[HttpHeaders.cookieHeader],
        contains('a_session_project=confirmed'),
      );
      expect((await persistedCookies(accountUri)).single.value, 'confirmed');

      accountResponse.complete(respond());
      await confirmation;

      expect(await observed, isTrue);
      expect(adapter.requests.map((request) => request.method), [
        'POST',
        'GET',
      ]);
    });

    test('account failure after cookie creation stays uncertain without repeating POST', () async {
      adapter.respond = (request) => request.method == 'POST'
          ? respond(
              status: 201,
              setCookies: ['a_session_project=uncertain; Path=/'],
            )
          : respond(
              status: 401,
              body: {'type': 'user_unauthorized', 'message': 'do not expose'},
            );

      await expectLater(
        repository.confirmCode(userId: 'user-id', code: '012345'),
        throwsA(
          isA<AuthenticationException>().having(
            (exception) => exception.errors.errors.single.status,
            'status',
            '401',
          ),
        ),
      );

      expect(changes, isEmpty);
      expect((await persistedCookies(accountUri)).single.value, 'uncertain');
      expect(adapter.requests.map((request) => request.method), [
        'POST',
        'GET',
      ]);
      adapter.respond = (_) => respond();
      final observed = session.session.first;

      expect(await session.loadSession(), isTrue);
      expect(await observed, isTrue);
      expect(adapter.requests.map((request) => request.method), [
        'POST',
        'GET',
        'GET',
      ]);
    });
  });

  group('signOut', () {
    test(
      'revokes only current session and leaves cookie expiry to the transport',
      () async {
        final foreignUri = Uri.parse('https://foreign.example/account');
        await seedSession();
        await cookies.saveFromResponse(accountUri, [
          Cookie('preference', 'keep')..path = '/',
        ]);
        await cookies.saveFromResponse(foreignUri, [
          Cookie('a_session_project', 'foreign')..path = '/',
        ]);
        adapter.respond = (_) =>
            respond(status: 204, setCookies: expiryHeaders);
        final observed = session.session.first;

        await repository.signOut();

        expect(await observed, isFalse);
        final request = adapter.requests.single;
        expect(request.method, 'DELETE');
        expect(request.uri.path, '/v1/account/sessions/current');
        expect((await persistedCookies(accountUri)).single.name, 'preference');
        expect((await persistedCookies(foreignUri)).single.value, 'foreign');
      },
    );

    for (final status in [204, 401]) {
      test(
        '$status without expiry headers publishes absence without local cleanup',
        () async {
          await seedSession();
          adapter.respond = (_) => respond(status: status);
          final observed = session.session.first;

          await repository.signOut();

          expect(await observed, isFalse);
          expect(await persistedCookies(accountUri), hasLength(2));
          expect(adapter.requests, hasLength(1));
        },
      );
    }

    test(
      'waits for response cookie persistence before completing logout',
      () async {
        await seedSession();
        final writeStarted = Completer<void>();
        final allowWrite = Completer<void>();
        storage.beforeWrite = (key, value) async {
          if (key == accountUri.host) {
            writeStarted.complete();
            await allowWrite.future;
          }
        };
        adapter.respond = (_) =>
            respond(status: 204, setCookies: expiryHeaders);
        final observed = session.session.first;
        final logout = repository.signOut();
        await writeStarted.future;

        expect(changes, isEmpty);
        expect(await persistedCookies(accountUri), hasLength(2));

        allowWrite.complete();
        await logout;

        expect(await observed, isFalse);
        expect(await persistedCookies(accountUri), isEmpty);
      },
    );

    test('cookie persistence failure after revocation fails without claiming cleanup', () async {
      await seedSession();
      storage.beforeWrite = (_, _) async =>
          throw const FileSystemException('write failed');
      adapter.respond = (_) => respond(status: 204, setCookies: expiryHeaders);

      await expectLater(
        repository.signOut(),
        throwsA(isA<AuthenticationException>()),
      );

      expect(changes, isEmpty);
      expect(await persistedCookies(accountUri), hasLength(2));
      expect(adapter.requests, hasLength(1));
      storage.beforeWrite = null;
      adapter.respond = (_) => respond(status: 401);
      final observed = session.session.first;

      await repository.signOut();

      expect(await observed, isFalse);
      expect(await persistedCookies(accountUri), hasLength(2));
    });
  });

  group('Failure mapping', () {
    for (final operation in ['requestCode', 'confirmCode', 'signOut']) {
      for (final status in [400, 403, 429, 500]) {
        test(
          '$operation maps $status and type without remote content or retry',
          () async {
            adapter.respond = (_) => respond(
              status: status,
              body: {
                'code': status,
                'type': 'operation_rejected',
                'message': 'private remote text',
              },
            );

            await expectLater(
              call(operation),
              throwsA(
                isA<AuthenticationException>()
                    .having(
                      (exception) => exception.errors.errors.single.status,
                      'status',
                      '$status',
                    )
                    .having(
                      (exception) => exception.errors.errors.single.code,
                      'type',
                      'operation_rejected',
                    )
                    .having(
                      (exception) => exception.errors.errors.single.title,
                      'title',
                      isNull,
                    )
                    .having(
                      (exception) => exception.errors.errors.single.detail,
                      'detail',
                      isNull,
                    ),
              ),
            );

            expect(changes, isEmpty);
            expect(adapter.requests, hasLength(1));
          },
        );
      }

      for (final type in [
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        test('$operation maps $type to safe fallback without retry', () async {
          adapter.respond = (request) =>
              throw DioException(requestOptions: request, type: type);

          await expectLater(
            call(operation),
            throwsA(
              isA<AuthenticationException>()
                  .having(
                    (exception) => exception.errors.errors.single.status,
                    'status',
                    isNull,
                  )
                  .having(
                    (exception) => exception.errors.errors.single.detail,
                    'fallback',
                    'Não foi possível processar a resposta.',
                  ),
            ),
          );

          expect(changes, isEmpty);
          expect(adapter.requests, hasLength(1));
        });
      }

      for (final failure in [
        StateError('unexpected'),
        const FormatException('malformed'),
      ]) {
        test(
          '$operation propagates unexpected ${failure.runtimeType}',
          () async {
            adapter.respond = (_) => throw failure;

            await expectLater(call(operation), throwsA(same(failure)));

            expect(changes, isEmpty);
            expect(adapter.requests, hasLength(1));
          },
        );
      }

      test('$operation does not mask invalid error metadata', () async {
        adapter.respond = (_) => respond(status: 400, body: {'type': 42});

        await expectLater(call(operation), throwsA(isA<TypeError>()));

        expect(changes, isEmpty);
      });

      test('$operation does not swallow cookie read failure', () async {
        storage.beforeRead = (_) async =>
            throw const FileSystemException('read failed');

        await expectLater(
          call(operation),
          throwsA(isA<AuthenticationException>()),
        );

        expect(changes, isEmpty);
        expect(adapter.requests, isEmpty);
      });
    }

    for (final operation in ['requestCode', 'confirmCode']) {
      test(
        '$operation treats 401 as rejection, not successful absence',
        () async {
          adapter.respond = (_) =>
              respond(status: 401, body: {'type': 'user_unauthorized'});

          await expectLater(
            call(operation),
            throwsA(
              isA<AuthenticationException>()
                  .having(
                    (exception) => exception.errors.errors.single.status,
                    'status',
                    '401',
                  )
                  .having(
                    (exception) => exception.errors.errors.single.code,
                    'type',
                    'user_unauthorized',
                  ),
            ),
          );

          expect(changes, isEmpty);
          expect(adapter.requests, hasLength(1));
        },
      );
    }
  });
}
