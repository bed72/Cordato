import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final bootstrap = File('lib/main.dart').readAsStringSync();
  final composition = File('lib/app_module.dart').readAsStringSync();

  test('awaits support directory before mounting the application module', () {
    final directoryRead = bootstrap.indexOf(
      'await getApplicationSupportDirectory()',
    );
    final mount = bootstrap.indexOf('runApp(');

    expect(directoryRead, greaterThanOrEqualTo(0));
    expect(mount, greaterThan(directoryRead));
    expect(bootstrap, contains('module: appModule(directory: directory)'));
    expect(bootstrap, isNot(contains('createModule(')));
  });

  test('keeps the application module declarative without legacy bootstrap', () {
    expect(
      composition,
      contains('Module appModule({required Directory directory})'),
    );
    expect(composition, contains('..addInstance<Directory>(directory)'));
    expect(composition, contains('..module(coreModule)'));

    for (final source in [bootstrap, composition]) {
      expect(source, isNot(contains('package:cordato/factory.dart')));
      expect(source, isNot(contains('createDependencies')));
      expect(source, isNot(contains('PocketBase')));
      expect(source, isNot(contains('package:pocketbase/')));
    }
  });

  test('does not install a custom observer or depend on Talker', () {
    final dependencies = File('pubspec.yaml').readAsStringSync();

    expect(bootstrap, isNot(contains('Bloc.observer')));
    expect(bootstrap, isNot(contains('observers/observer.dart')));
    expect(dependencies, isNot(contains('talker:')));
    expect(dependencies, isNot(contains('talker_logger:')));
    expect(dependencies, isNot(contains('talker_bloc_logger:')));
  });

  test('Flutter has no dependency on the removed backend SDK or transport', () {
    final dependencies = File('pubspec.yaml').readAsStringSync();

    expect(
      dependencies,
      isNot(matches(RegExp(r'^\s*pocketbase:', multiLine: true))),
    );
    expect(
      dependencies,
      isNot(matches(RegExp(r'^\s*flutter_secure_storage:', multiLine: true))),
    );

    for (final root in ['lib', 'test']) {
      for (final file in Directory(
        root,
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) {
          continue;
        }

        final source = file.readAsStringSync();
        expect(
          source,
          isNot(
            matches(RegExp(r'''(?:import|export)\s+['"]package:pocketbase/''')),
          ),
          reason: file.path,
        );
        expect(
          source,
          isNot(
            matches(
              RegExp(
                r'''(?:import|export)\s+['"][^'"]*/(?:pocketbase|auth_store_mock)''',
              ),
            ),
          ),
          reason: file.path,
        );
      }
    }
  });
}
