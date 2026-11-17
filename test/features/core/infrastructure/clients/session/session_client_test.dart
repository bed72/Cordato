import 'dart:async';
import 'dart:convert';
import 'dart:io' hide HttpClient;

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/session/session_client.dart';

import '../../../../../support/core/fakes/cookie_storage_fake.dart';
import '../../../../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  final account = Uri.parse('https://appwrite.example/v1/account');
  const expired = [
    'a_session_project=; Path=/; Max-Age=0',
    'a_session_project_legacy=; Domain=.appwrite.example; Path=/; Max-Age=0',
  ];

  late Dio transport;
  late HttpClient client;
  late List<bool> changes;
  late Directory directory;
  late SessionClient session;
  late PersistCookieJar cookies;
  late CookieStorageFake storage;
  late HttpClientAdapterFake adapter;

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

  Future<void> seedSession() => cookies.saveFromResponse(account, [
    Cookie('a_session_project', 'host-secret')..path = '/',
    Cookie('a_session_project_legacy', 'domain-secret')
      ..path = '/'
      ..domain = '.appwrite.example',
  ]);

  Future<List<Cookie>> persistedCookies(Uri uri) => PersistCookieJar(
    ignoreExpires: false,
    persistSession: true,
    storage: FileStorage(directory.path),
  ).loadForRequest(uri);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-session-');
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
    changes = [];

    final subscription = session.session.listen(changes.add);
    addTearDown(() async {
      await subscription.cancel();
      await session.close();
      client.close(force: true);
      await directory.delete(recursive: true);
    });
  });

  group('Session loading', () {
    for (final endpoint in [
      'https://appwrite.example/v1',
      'https://appwrite.example/v1/',
    ]) {
      test('queries account with cookies and preserves $endpoint', () async {
        await seedSession();
        transport.options.baseUrl = endpoint;
        final observed = session.session.first;

        expect(await session.loadSession(), isTrue);
        expect(await observed, isTrue);

        final request = adapter.requests.single;
        expect(request.uri, account);
        expect(request.method, 'GET');
        expect(request.headers['X-Appwrite-Project'], 'project');
        expect(
          request.headers[HttpHeaders.cookieHeader],
          contains('host-secret'),
        );
        expect(
          request.headers[HttpHeaders.cookieHeader],
          contains('domain-secret'),
        );
      });
    }

    test('uses HTTP success without interpreting account fields', () async {
      adapter.respond = (_) => respond(body: {r'$id': ''});
      final observed = session.session.first;

      expect(await session.loadSession(), isTrue);
      expect(await observed, isTrue);
      expect(adapter.requests, hasLength(1));
    });

    test(
      'uses the Dio success policy instead of enforcing a specific status',
      () async {
        adapter.respond = (_) => respond(status: 204, body: null);
        final observed = session.session.first;

        expect(await session.loadSession(), isTrue);
        expect(await observed, isTrue);
      },
    );

    test('401 publishes absence without manually deleting cookies', () async {
      await seedSession();
      adapter.respond = (_) => respond(status: 401);
      final observed = session.session.first;

      expect(await session.loadSession(), isFalse);
      expect(await observed, isFalse);

      expect(changes, [false]);
      expect(await persistedCookies(account), hasLength(2));
    });

    for (final status in [403, 429, 500, 503]) {
      test(
        '$status preserves cookies and the last confirmed observation',
        () async {
          await seedSession();

          final authenticated = session.session.first;
          await session.loadSession();
          await authenticated;

          adapter.respond = (_) => respond(status: status);

          await expectLater(
            session.loadSession(),
            throwsA(
              isA<HttpResponseException>().having(
                (exception) => exception.response.status,
                'status',
                status,
              ),
            ),
          );

          expect(changes, [true]);
          expect(adapter.requests, hasLength(2));
          expect(await persistedCookies(account), hasLength(2));
        },
      );
    }

    for (final type in [
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('$type is not absence and does not retry', () async {
        adapter.respond = (request) =>
            throw DioException(requestOptions: request, type: type);

        await expectLater(
          session.loadSession(),
          throwsA(isA<HttpTransportException>()),
        );

        expect(changes, isEmpty);
        expect(adapter.requests, hasLength(1));
      });
    }
  });

  group('Observation and cookies managed by the transport', () {
    test('cancelling one subscriber does not affect the others', () async {
      final cancelledChanges = <bool>[];
      final cancelled = session.session.listen(cancelledChanges.add);
      final first = session.session.first;

      await session.loadSession();
      await first;
      await cancelled.cancel();

      adapter.respond = (_) => respond(status: 401);
      final second = session.session.first;

      await session.loadSession();
      expect(await second, isFalse);
      expect(changes, [true, false]);
      expect(cancelledChanges, [true]);
    });

    test(
      'server expiry removes session cookies while preserving other origins',
      () async {
        final foreignUri = Uri.parse('https://foreign.example/account');
        await seedSession();
        await cookies.saveFromResponse(account, [
          Cookie('preference', 'keep')..path = '/',
        ]);
        await cookies.saveFromResponse(foreignUri, [
          Cookie('a_session_project', 'foreign')..path = '/',
        ]);

        adapter.respond = (_) => respond(status: 204, setCookies: expired);
        final observed = session.session.first;

        await session.signOut();
        expect(await observed, isFalse);

        expect((await persistedCookies(account)).single.name, 'preference');
        expect((await persistedCookies(foreignUri)).single.value, 'foreign');
        expect(
          adapter.requests.single.uri.path,
          '/v1/account/sessions/current',
        );
      },
    );

    test('logout without Set-Cookie does not invent local cleanup', () async {
      await seedSession();
      adapter.respond = (_) => respond(status: 204);
      final observed = session.session.first;

      await session.signOut();
      expect(await observed, isFalse);

      expect(await persistedCookies(account), hasLength(2));
    });

    test(
      'cookie load errors retain the transport exception without absence',
      () async {
        const failure = FileSystemException('read failed');
        storage.beforeRead = (_) async => throw failure;

        await expectLater(
          session.loadSession(),
          throwsA(isA<HttpUnexpectedException>()),
        );

        expect(changes, isEmpty);
        expect(adapter.requests, isEmpty);
      },
    );

    test(
      'cookie save failure attached to 401 is not confirmed absence',
      () async {
        await seedSession();
        const failure = FileSystemException('write failed');
        storage.beforeWrite = (_, _) async => throw failure;
        adapter.respond = (_) => respond(status: 401, setCookies: expired);

        await expectLater(
          session.loadSession(),
          throwsA(isA<HttpUnexpectedException>()),
        );

        expect(changes, isEmpty);
      },
    );
  });

  group('Confirmation and logout', () {
    test(
      'confirmation awaits cookies and GET before publishing authentication',
      () async {
        final getStarted = Completer<void>();
        final getResponse = Completer<ResponseBody>();
        adapter.respond = (request) {
          if (request.method == 'POST') {
            return respond(
              status: 201,
              setCookies: ['a_session_project=confirmed; Path=/'],
            );
          }
          getStarted.complete();
          return getResponse.future;
        };
        final observed = session.session.first;
        final confirmation = session.confirmCode(
          code: ' 012345 ',
          userId: ' user-id ',
        );
        await getStarted.future;

        expect(changes, isEmpty);
        expect(adapter.requests.first.data, {
          'userId': ' user-id ',
          'secret': ' 012345 ',
        });
        expect(
          adapter.requests.last.headers[HttpHeaders.cookieHeader],
          contains('confirmed'),
        );
        expect((await persistedCookies(account)).single.value, 'confirmed');

        getResponse.complete(respond());
        await confirmation;

        expect(await observed, isTrue);
        expect(adapter.requests.map((request) => request.method), [
          'POST',
          'GET',
        ]);
      },
    );

    test(
      'failed account query after confirmation is uncertain without POST retry',
      () async {
        adapter.respond = (request) => request.method == 'POST'
            ? respond(
                status: 201,
                setCookies: ['a_session_project=uncertain; Path=/'],
              )
            : respond(status: 401);

        await expectLater(
          session.confirmCode(userId: 'user-id', code: '012345'),
          throwsA(isA<HttpResponseException>()),
        );

        expect(changes, isEmpty);
        expect((await persistedCookies(account)).single.value, 'uncertain');
        adapter.respond = (_) => respond();
        final observed = session.session.first;

        expect(await session.loadSession(), isTrue);
        expect(await observed, isTrue);
        expect(adapter.requests.map((request) => request.method), [
          'POST',
          'GET',
          'GET',
        ]);
      },
    );

    test(
      'rejected code does not authenticate and permits manual retry',
      () async {
        adapter.respond = (_) => respond(status: 401);

        await expectLater(
          session.confirmCode(userId: 'user-id', code: '012345'),
          throwsA(isA<HttpResponseException>()),
        );

        expect(changes, isEmpty);
        expect(adapter.requests, hasLength(1));
        adapter.respond = (request) =>
            respond(status: request.method == 'POST' ? 201 : 200);
        final observed = session.session.first;

        await session.confirmCode(userId: 'user-id', code: '654321');

        expect(await observed, isTrue);
        expect(adapter.requests.map((request) => request.method), [
          'POST',
          'POST',
          'GET',
        ]);
      },
    );

    test('logout 401 means the current session is already absent', () async {
      adapter.respond = (_) => respond(status: 401);
      final observed = session.session.first;

      await session.signOut();

      expect(await observed, isFalse);
      expect(adapter.requests, hasLength(1));
    });

    test(
      'remote logout failure preserves cookies and publishes nothing',
      () async {
        await seedSession();
        adapter.respond = (_) => respond(status: 503);

        await expectLater(
          session.signOut(),
          throwsA(isA<HttpResponseException>()),
        );

        expect(changes, isEmpty);
        expect(await persistedCookies(account), hasLength(2));
      },
    );
  });

  group('Ordered operations', () {
    test(
      'each explicit load is queued rather than cached or coalesced',
      () async {
        final started = Completer<void>();
        final response = Completer<ResponseBody>();
        adapter.respond = (_) {
          if (adapter.requests.length == 1) {
            started.complete();
            return response.future;
          }

          return respond(status: 401);
        };

        final first = session.loadSession();
        await started.future;
        final second = session.loadSession();

        expect(second, isNot(same(first)));
        expect(adapter.requests, hasLength(1));

        response.complete(respond());
        expect(await first, isTrue);
        expect(await second, isFalse);
        expect(adapter.requests, hasLength(2));
      },
    );

    for (final scenario in [
      (name: 'restore', status: 200, methods: ['GET', 'DELETE', 'GET']),
      (name: 'confirm', status: 201, methods: ['POST', 'GET', 'DELETE', 'GET']),
    ]) {
      test(
        '${scenario.name} completes before logout without late cookie writes',
        () async {
          final started = Completer<void>();
          final response = Completer<ResponseBody>();

          adapter.respond = (request) {
            if (adapter.requests.length == 1) {
              started.complete();
              return response.future;
            }
            if (request.method == 'DELETE') {
              return respond(status: 204, setCookies: expired);
            }

            return respond(
              status: request.headers[HttpHeaders.cookieHeader] == null
                  ? 401
                  : 200,
            );
          };

          final observed = session.session.take(3).toList();
          final Future<Object?> first = switch (scenario.name) {
            'restore' => session.loadSession(),
            _ => session.confirmCode(userId: 'user-id', code: '012345'),
          };

          await started.future;
          final logout = session.signOut();
          final nextLoad = session.loadSession();

          expect(adapter.requests, hasLength(1));

          response.complete(
            respond(
              status: scenario.status,
              setCookies: ['a_session_project=late-secret; Path=/'],
            ),
          );

          await first;
          await logout;
          await nextLoad;

          expect(await observed, [true, false, false]);
          expect(
            adapter.requests.map((request) => request.method),
            scenario.methods,
          );
          expect(
            adapter.requests.last.headers[HttpHeaders.cookieHeader],
            isNull,
          );
          expect(await persistedCookies(account), isEmpty);
        },
      );
    }

    test('the queue continues after a failure without retrying it', () async {
      final started = Completer<void>();
      final response = Completer<ResponseBody>();
      adapter.respond = (request) {
        if (request.method == 'GET') {
          started.complete();
          return response.future;
        }
        return respond(status: 204);
      };
      final load = session.loadSession();
      final failure = expectLater(load, throwsA(isA<HttpResponseException>()));
      await started.future;
      final logout = session.signOut();
      final observed = session.session.first;

      response.complete(respond(status: 500));
      await failure;
      await logout;

      expect(await observed, isFalse);
      expect(adapter.requests.map((request) => request.method), [
        'GET',
        'DELETE',
      ]);
    });

    test(
      'cookie persistence blocks the following account query and logout',
      () async {
        await cookies.forceInit();
        final writeStarted = Completer<void>();
        final allowWrite = Completer<void>();
        storage.beforeWrite = (key, value) async {
          if (key == account.host && !writeStarted.isCompleted) {
            writeStarted.complete();
            await allowWrite.future;
          }
        };
        adapter.respond = (request) => switch (request.method) {
          'POST' => respond(
            status: 201,
            setCookies: ['a_session_project=confirmed; Path=/'],
          ),
          'DELETE' => respond(status: 204, setCookies: expired),
          _ => respond(),
        };
        final observed = session.session.take(2).toList();
        final confirmation = session.confirmCode(
          userId: 'user-id',
          code: '012345',
        );
        await writeStarted.future;
        final logout = session.signOut();

        expect(adapter.requests.map((request) => request.method), ['POST']);
        expect(changes, isEmpty);

        allowWrite.complete();
        await confirmation;
        await logout;

        expect(await observed, [true, false]);
        expect(await persistedCookies(account), isEmpty);
        expect(adapter.requests.map((request) => request.method), [
          'POST',
          'GET',
          'DELETE',
        ]);
      },
    );
  });
}
