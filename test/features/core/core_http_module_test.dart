import 'dart:io' hide HttpClient;

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/application/clients/interface_session_client.dart';
import 'package:cordato/features/core/infrastructure/clients/session/session_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';

import '../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  late Directory directory;

  const endpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://console.cordato.cloud/v1',
  );
  const projectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '6ae23b900027854cc526',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-http-di-');
    addTearDown(() => directory.delete(recursive: true));
  });

  ModularBootstrap bootstrapCore({Directory? supportDirectory}) {
    final module = createModule(
      register: (context) => context
        ..addInstance<Directory>(supportDirectory ?? directory)
        ..module(coreModule),
    );
    final boot = bootstrapModule(module);
    addTearDown(boot.injector.dispose);

    return boot;
  }

  test(
    'resolves the shared session through its contract without visiting routes',
    () async {
      final boot = bootstrapCore();
      final session = boot.injector.get<ISessionClient>();
      final httpClient = boot.injector.get<IHttpClient>();
      addTearDown(() => httpClient.close(force: true));
      addTearDown(session.close);
      final adapter = HttpClientAdapterFake();
      boot.injector.get<Dio>().httpClientAdapter = adapter;

      expect(session, isA<SessionClient>());
      expect(boot.injector.get<ISessionClient>(), same(session));
      expect(boot.routes.routes, isEmpty);
      expect(adapter.requests, isEmpty);
      final observed = session.session.first;

      expect(await session.loadSession(), isTrue);
      expect(await observed, isTrue);
      expect(adapter.requests.single.uri, Uri.parse('$endpoint/account'));
    },
  );

  test('injects one configured Dio and jar into the HTTP client', () {
    final boot = bootstrapCore();

    final cookies = boot.injector.get<PersistCookieJar>();
    final client = boot.injector.get<IHttpClient>();
    final transport = boot.injector.get<Dio>();
    addTearDown(() => client.close(force: true));

    expect(boot.routes.routes, isEmpty);
    expect(cookies.ignoreExpires, isFalse);
    expect(cookies.persistSession, isTrue);
    expect(client, isA<HttpClient>());
    expect(boot.injector.get<IHttpClient>(), same(client));
    expect(boot.injector.get<PersistCookieJar>(), same(cookies));
    expect(boot.injector.get<Dio>(), same(transport));
    expect(transport.options.baseUrl, endpoint);
    expect(transport.options.headers['X-Appwrite-Project'], projectId);
    expect(transport.options.headers['Accept'], Headers.jsonContentType);
    expect(transport.options.contentType, Headers.jsonContentType);
    expect(transport.options.followRedirects, isFalse);
    expect(transport.options.sendTimeout, const Duration(seconds: 20));
    expect(transport.options.connectTimeout, const Duration(seconds: 15));
    expect(transport.options.receiveTimeout, const Duration(seconds: 20));
    expect(
      transport.interceptors.whereType<CookieManager>().single.cookieJar,
      same(cookies),
    );
  });

  test(
    'loads persisted cookies from the configured support directory',
    () async {
      final boot = bootstrapCore();
      final cookies = boot.injector.get<PersistCookieJar>();
      final account = Uri.parse('$endpoint/account');
      await cookies.saveFromResponse(account, [
        Cookie('a_session_$projectId', 'fake-session')
          ..path = '/'
          ..secure = true,
      ]);

      final transport = boot.injector.get<Dio>();
      final client = boot.injector.get<IHttpClient>();
      addTearDown(() => client.close(force: true));
      final adapter = HttpClientAdapterFake();
      transport.httpClientAdapter = adapter;

      await client.get(parameter: const Requests(path: '/account'));

      expect(adapter.requests.single.uri, account);
      expect(
        adapter.requests.single.headers[HttpHeaders.cookieHeader],
        contains('a_session_$projectId=fake-session'),
      );

      final restored = PersistCookieJar(
        ignoreExpires: false,
        persistSession: true,
        storage: FileStorage('${directory.path}/$projectId/cookies'),
      );
      expect(
        (await restored.loadForRequest(account)).single.value,
        'fake-session',
      );
      expect(
        await Directory('${directory.path}/$projectId/cookies').exists(),
        isTrue,
      );
    },
  );

  test(
    'keeps cookie storage separate for different support directories',
    () async {
      final firstBoot = bootstrapCore();
      final firstCookies = firstBoot.injector.get<PersistCookieJar>();
      final account = Uri.parse('$endpoint/account');
      await firstCookies.saveFromResponse(account, [
        Cookie('a_session_$projectId', 'fake-session')..path = '/',
      ]);

      final secondDirectory = Directory('${directory.path}/other');
      final secondBoot = bootstrapCore(supportDirectory: secondDirectory);
      final secondCookies = secondBoot.injector.get<PersistCookieJar>();
      final storedCookies = await secondCookies.loadForRequest(account);

      expect(storedCookies, isEmpty);
      expect(secondCookies, isNot(same(firstCookies)));
    },
  );
}
