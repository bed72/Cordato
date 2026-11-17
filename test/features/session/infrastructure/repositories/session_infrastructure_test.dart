import 'dart:async';
import 'dart:convert';
import 'dart:io' hide HttpClient;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';
import 'package:cordato/features/core/application/clients/interface_session_client.dart';
import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';
import 'package:cordato/features/session/session_module.dart';

import '../../../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  late Directory directory;
  late ModularBootstrap boot;
  late HttpClientAdapterFake adapter;
  late ISessionRepository session;
  late AuthenticationRepository authentication;
  final account = Uri.parse('$endpoint/account');
  final cookieName = 'a_session_$projectId';

  ResponseBody respond({
    int status = 200,
    Object body = const {},
    List<String> setCookies = const [],
    String? location,
  }) => ResponseBody.fromString(
    status == 204 ? '' : jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      if (setCookies.isNotEmpty) HttpHeaders.setCookieHeader: setCookies,
      if (location != null) HttpHeaders.locationHeader: [location],
    },
  );

  ModularBootstrap compose() {
    final composition = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<Directory>(directory)
          ..module(coreModule)
          ..module(sessionModule),
      ),
    );
    final client = composition.injector.get<IHttpClient>();
    final coordinator = composition.injector.get<ISessionClient>();
    addTearDown(() async {
      await coordinator.close();
      client.close(force: true);
      composition.injector.dispose();
    });
    return composition;
  }

  Future<List<Cookie>> persistedCookies() => PersistCookieJar(
    ignoreExpires: false,
    persistSession: true,
    storage: FileStorage('${directory.path}/$projectId/cookies'),
  ).loadForRequest(account);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-session-flow-');
    addTearDown(() => directory.delete(recursive: true));
    boot = compose();
    adapter = HttpClientAdapterFake();
    boot.injector.get<Dio>().httpClientAdapter = adapter;
    session = boot.injector.get<ISessionRepository>();
    authentication = AuthenticationRepository(
      httpClient: boot.injector.get<IHttpClient>(),
      sessionClient: boot.injector.get<ISessionClient>(),
    );
  });

  test(
    'code, cookies, account observation, fresh composition and logout',
    () async {
      final changes = <bool>[];
      final subscription = session.session.listen(changes.add);
      addTearDown(subscription.cancel);
      adapter.respond = (request) => switch (request.uri.path) {
        '/v1/account/tokens/email' => respond(
          status: 201,
          body: {'userId': 'service-user'},
        ),
        '/v1/account/sessions/token' => respond(
          status: 201,
          setCookies: ['$cookieName=fake-session; Path=/; Secure; HttpOnly'],
        ),
        _ => respond(),
      };

      final userId = await authentication.requestCode(
        email: ' User@example.com ',
      );
      expect(changes, isEmpty);
      final confirmed = session.session.first;
      await authentication.confirmCode(userId: userId, code: '012345');
      expect(await confirmed, isTrue);
      expect(adapter.requests[1].data, {'userId': userId, 'secret': '012345'});
      expect(
        adapter.requests.last.headers[HttpHeaders.cookieHeader],
        contains('$cookieName=fake-session'),
      );
      expect((await persistedCookies()).single.value, 'fake-session');

      final restoredBoot = compose();
      final restoredAdapter = HttpClientAdapterFake();
      restoredBoot.injector.get<Dio>().httpClientAdapter = restoredAdapter;
      final restoredSession = restoredBoot.injector.get<ISessionRepository>();
      final restoredEvent = restoredSession.session.first;
      expect(await restoredSession.loadSession(), isTrue);
      expect(await restoredEvent, isTrue);
      expect(
        restoredAdapter.requests.single.headers[HttpHeaders.cookieHeader],
        contains('$cookieName=fake-session'),
      );
      expect(
        restoredBoot.injector.get<PersistCookieJar>(),
        isNot(same(boot.injector.get<PersistCookieJar>())),
      );
      restoredAdapter.respond = (_) => respond(
        status: 204,
        setCookies: ['$cookieName=; Path=/; Max-Age=0; Secure'],
      );
      final restoredAuthentication = AuthenticationRepository(
        httpClient: restoredBoot.injector.get<IHttpClient>(),
        sessionClient: restoredBoot.injector.get<ISessionClient>(),
      );
      final loggedOut = restoredSession.session.first;
      await restoredAuthentication.signOut();

      expect(await loggedOut, isFalse);
      expect(restoredAdapter.requests.last.method, 'DELETE');
      expect(
        restoredAdapter.requests.last.uri,
        Uri.parse('$endpoint/account/sessions/current'),
      );
      expect(await persistedCookies(), isEmpty);
      expect(changes, [true]);
    },
  );

  test(
    'a fresh jar never sends expired credentials and 401 publishes absence',
    () async {
      await boot.injector.get<PersistCookieJar>().saveFromResponse(account, [
        Cookie(cookieName, 'expired')
          ..path = '/'
          ..expires = DateTime.utc(2000),
      ]);
      final restoredBoot = compose();
      final restoredAdapter = HttpClientAdapterFake()
        ..respond = (_) => respond(status: 401);
      restoredBoot.injector.get<Dio>().httpClientAdapter = restoredAdapter;
      final restoredSession = restoredBoot.injector.get<ISessionRepository>();
      final absent = restoredSession.session.first;

      expect(await restoredSession.loadSession(), isFalse);
      expect(await absent, isFalse);
      expect(
        restoredAdapter.requests.single.headers[HttpHeaders.cookieHeader],
        isNull,
      );
      expect(await persistedCookies(), isEmpty);
    },
  );

  test(
    'origin and redirect restrictions do not forward persisted credentials',
    () async {
      await boot.injector.get<PersistCookieJar>().saveFromResponse(account, [
        Cookie(cookieName, 'fake-session')..path = '/',
      ]);
      final http = boot.injector.get<IHttpClient>();

      await expectLater(
        http.get(
          parameter: const Requests(path: 'https://foreign.example/account'),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(adapter.requests, isEmpty);
      adapter.respond = (_) =>
          respond(status: 302, location: 'https://foreign.example/account');
      await expectLater(
        session.loadSession(),
        throwsA(isA<SessionException>()),
      );

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri, account);
      expect(adapter.requests.single.followRedirects, isFalse);
      expect((await persistedCookies()).single.value, 'fake-session');
    },
  );

  for (final operation in ['confirmation', 'restoration']) {
    test('$operation finishes cookie effects before queued logout', () async {
      final pendingResponse = Completer<ResponseBody>();
      final started = Completer<void>();
      adapter.respond = (request) {
        if (!started.isCompleted) {
          started.complete();
          return pendingResponse.future;
        }
        if (request.method == 'DELETE') {
          return respond(
            status: 204,
            setCookies: ['$cookieName=; Path=/; Max-Age=0'],
          );
        }
        return respond();
      };
      final observed = expectLater(
        session.session,
        emitsInOrder([true, false]),
      );
      final Future<void> earlier = operation == 'confirmation'
          ? authentication.confirmCode(userId: 'user', code: '012345')
          : session.loadSession().then((_) {});
      await started.future;
      final logout = authentication.signOut();
      expect(adapter.requests, hasLength(1));
      pendingResponse.complete(
        respond(
          status: operation == 'confirmation' ? 201 : 200,
          setCookies: ['$cookieName=late-session; Path=/; Secure; HttpOnly'],
        ),
      );
      await earlier;
      await logout;
      await observed;

      expect(adapter.requests.last.method, 'DELETE');
      expect(
        adapter.requests.last.headers[HttpHeaders.cookieHeader],
        contains('$cookieName=late-session'),
      );
      expect(
        await boot.injector.get<PersistCookieJar>().loadForRequest(account),
        isEmpty,
      );
      expect(await persistedCookies(), isEmpty);
    });
  }
}
