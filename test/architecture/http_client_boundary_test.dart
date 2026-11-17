import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repositories depend on the session contract rather than its implementation', () {
    for (final feature in ['authentication', 'session']) {
      final repository = File(
        'lib/features/$feature/infrastructure/repositories/${feature}_repository.dart',
      ).readAsStringSync();

      expect(
        repository,
        contains('application/clients/interface_session_client.dart'),
      );
      expect(repository, contains('ISessionClient'));
      expect(repository, isNot(contains('clients/session/session_client.dart')));
    }
  });

  test('keeps Dio confined to the HTTP transport and core composition', () {
    final violations = <String>[];
    final dioImport = RegExp(r'''(?:import|export)\s+['"]package:dio/''');

    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path == 'lib/features/core/core_module.dart' ||
          file.path.startsWith(
            'lib/features/core/infrastructure/clients/http/',
          )) {
        continue;
      }

      if (dioImport.hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
    'injects a configured Dio into the HTTP contract without a client factory',
    () {
      final composition = File('lib/features/core/core_module.dart')
          .readAsStringSync();

      expect(composition, contains('addLazySingleton<IHttpClient>'));
      expect(composition, contains('addLazySingleton<Dio>'));
      expect(composition, contains('CookieManager(cookies)'));
      expect(composition, contains('HttpClient.new'));

      final client = File(
        'lib/features/core/infrastructure/clients/http/http_client.dart',
      ).readAsStringSync();
      expect(client, contains('required final Dio _dio'));
      expect(client, isNot(contains('Dio?')));
      expect(client, isNot(contains('Dio()')));
      expect(client, isNot(contains('static HttpClient create')));
    },
  );
}
