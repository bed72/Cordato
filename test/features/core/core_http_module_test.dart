import 'dart:io';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'package:cordato/features/core/core_module.dart';

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

  test('resolves one Dio and one cookie jar without visiting routes', () {
    final boot = bootstrapCore();

    final cookies = boot.injector.get<PersistCookieJar>();
    final client = boot.injector.get<Dio>();
    addTearDown(() => client.close(force: true));
    final manager = client.interceptors.whereType<CookieManager>().single;

    expect(boot.routes.routes, isEmpty);
    expect(cookies.ignoreExpires, isFalse);
    expect(cookies.persistSession, isTrue);
    expect(manager.cookieJar, same(cookies));
    expect(client.options.baseUrl, endpoint);
    expect(boot.injector.get<Dio>(), same(client));
    expect(boot.injector.get<PersistCookieJar>(), same(cookies));
    expect(client.options.headers['X-Appwrite-Project'], projectId);
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

      final client = boot.injector.get<Dio>();
      addTearDown(() => client.close(force: true));

      final adapter = HttpClientAdapterFake();
      client.httpClientAdapter = adapter;

      await client.get<dynamic>('/account');

      expect(
        adapter.requests.single.headers[HttpHeaders.cookieHeader],
        contains('a_session_$projectId=fake-session'),
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
